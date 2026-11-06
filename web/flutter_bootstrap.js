{{flutter_js}}
{{flutter_build_config}}

// The audio engine's own AudioContext, kept so that the page can wake it
// and put it to sleep (see lowEndWakeAudio below), and the app can ask the
// browser how late what it plays is heard (outputLatency,
// web_audio_engine_web.dart). The app raises lowEndCatchAudioContext just
// before the engine starts, and calls lowEndAudioEngineStarted once it has;
// the microphone's context, made at another time, is not taken for it.
// Starting, the engine opens and closes contexts of its own, and suspends
// them (the single-threaded build does on a first opening): only the one
// still open once it has started is its own. Taking the first one made, a
// suspended one was taken for the browser cutting the sound, and the
// harmony paused as soon as it started.
let audioContextsMade = [];
if (window.AudioContext) {
  window.AudioContext = class extends window.AudioContext {
    constructor(...args) {
      super(...args);
      if (window.lowEndCatchAudioContext) audioContextsMade.push(this);
    }
  };
}
window.lowEndAudioEngineStarted = function () {
  window.lowEndCatchAudioContext = false;
  const open = audioContextsMade.filter(function (c) { return c.state !== 'closed'; });
  audioContextsMade = [];
  const context = open[open.length - 1];
  if (!context || context === window.lowEndAudioContext) return;
  window.lowEndAudioContext = context;
  watchAudio(context);
};

// The audio engine's memory, shared with its own thread, is asked for with
// room to grow to 2 GB. Safari on the iPhone has refused shared memories
// that large ("out of memory": https://bugs.webkit.org/show_bug.cgi?id=255103),
// which would leave the app silent from its second opening on. It is then
// asked for again with less room: the engine never needs that much.
(function () {
  const Memory = WebAssembly.Memory;
  function SmallerIfRefused(descriptor) {
    try {
      return new Memory(descriptor);
    } catch (error) {
      if (!descriptor || !descriptor.shared) throw error;
      for (const maximum of [16384, 8192, 4096]) {
        if (maximum >= descriptor.maximum || maximum < descriptor.initial) {
          continue;
        }
        try {
          const memory = new Memory(Object.assign({}, descriptor, { maximum }));
          console.warn('Shared memory refused: kept to ' + maximum / 16 + ' MB.');
          return memory;
        } catch (_) {}
      }
      throw error;
    }
  }
  SmallerIfRefused.prototype = Memory.prototype;
  WebAssembly.Memory = SmallerIfRefused;
})();

// Decodes a FLAC recording (a Uint8Array) to the 16-bit samples of its
// first channel, with the browser's own decoder: off the page's thread and
// some twenty times faster than the audio engine's. An offline context
// needs no touch of the screen and plays nothing. The app falls back to the
// engine if it fails (lib/audio/browser_flac_web.dart).
window.lowEndDecodeFlac = function (bytes) {
  const Offline = window.OfflineAudioContext || window.webkitOfflineAudioContext;
  if (!Offline) return Promise.reject(new Error('no OfflineAudioContext'));
  window.lowEndDecoder = window.lowEndDecoder || new Offline(1, 1, 48000);
  const data = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
  return window.lowEndDecoder.decodeAudioData(data).then(function (audio) {
    const f = audio.getChannelData(0);
    const out = new Int16Array(f.length);
    for (let i = 0; i < f.length; i++) {
      const v = Math.round(f[i] * 32768);
      out[i] = v > 32767 ? 32767 : v < -32768 ? -32768 : v;
    }
    return out;
  });
};

// The peaks of an audio file (an ArrayBuffer), one every 10 ms, for the wave
// of the Player (Uint16Array, 0..32767), with the browser's own decoder in an
// offline context at a low sample rate: the browser resamples while
// decoding, and 15 minutes of stereo take some 58 MB instead of 320. The loop
// gives way every half a million samples, so that the screen does not stop
// (RNF-FLU-01). Fails if the browser cannot decode the file; the app then
// draws no wave (lib/audio/system_track_files_web.dart).
window.lowEndPeaks = async function (data) {
  const Offline = window.OfflineAudioContext || window.webkitOfflineAudioContext;
  if (!Offline) throw new Error('no OfflineAudioContext');
  let context;
  try { context = new Offline(1, 1, 8000); } catch (e) { context = new Offline(1, 1, 22050); }
  const audio = await context.decodeAudioData(data);
  const frame = Math.round(audio.sampleRate / 100);
  const out = new Uint16Array(Math.ceil(audio.length / frame));
  let work = 0;
  for (let c = 0; c < audio.numberOfChannels; c++) {
    const f = audio.getChannelData(c);
    for (let i = 0; i < out.length; i++) {
      let peak = out[i];
      const end = Math.min(f.length, (i + 1) * frame);
      for (let j = i * frame; j < end; j++) {
        const v = Math.min(32767, Math.round(Math.abs(f[j]) * 32767));
        if (v > peak) peak = v;
      }
      out[i] = peak;
      work += frame;
      if (work > 500000) { work = 0; await new Promise((r) => setTimeout(r, 0)); }
    }
  }
  return out;
};

// The audio engine (flutter_soloud, in WebAssembly) is loaded once the app
// is on screen, not before: it is not needed for the first frame, and
// loading it earlier slowed the first screen down. The app waits for the
// promise this gives, which ends once the engine is ready to start
// (web_audio_engine_web.dart), however long that takes: on a slow network
// the very first opening downloads it then (some 2 MB), and the engine's
// own wait of 15 seconds would give up and leave the app silent. If the
// download fails, the promise fails, and the next sound asked for loads it
// again.
let audioEngine = null;
window.lowEndLoadAudioEngine = function () {
  if (audioEngine) return audioEngine;
  const script = document.createElement('script');
  audioEngine = new Promise(function (resolve, reject) {
    // A fresh promise from the engine's loader, not one left by an
    // attempt that failed.
    self.flutter_soloud_ready = undefined;
    script.src = 'assets/packages/flutter_soloud/web/init_soloud.js';
    // The loader sets its promise as it runs; looked for a few times in
    // case it runs a moment after it has loaded.
    script.onload = function () {
      let tries = 0;
      (function ready() {
        const promise = self.flutter_soloud_ready;
        if (promise) return promise.then(resolve, reject);
        if (++tries > 40) return reject(new Error('The audio engine did not load.'));
        setTimeout(ready, 50);
      })();
    };
    script.onerror = function () {
      reject(new Error('The audio engine could not be downloaded.'));
    };
    document.head.appendChild(script);
  }).catch(function (error) {
    audioEngine = null;
    script.remove();
    throw error;
  });
  return audioEngine;
};

// Everything comes from this site, nothing from Google's servers: the
// drawing engine (CanvasKit) included, and Flutter's own service worker,
// deprecated, is left out for ours (sw.js, made by tool/web_offline.dart).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById('loading')?.remove();
    // After the first frame.
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        // On the very first opening the page will soon be opened again
        // (see controllerchange below): the engine then waits for the
        // first sound, if one comes before.
        const firstOpening = 'serviceWorker' in navigator &&
          !navigator.serviceWorker.controller;
        if (!firstOpening) window.lowEndLoadAudioEngine().catch(function () {});
        keepOffline();
      });
    });
  },
});

// Keeps the app's files on the phone, so that it opens fast and works with
// no network. Only in the published app: sw.js is not there in debug.
// Started after the first frame, so that on the first opening its download
// does not slow the app's own. The worker keeps the app first (3 MB, most
// already in the browser's cache) and takes over at once; the recordings
// (13 MB) come after, a few at a time, asked for a few seconds after each
// opening until all are kept (see tool/web_offline.dart).
function keepOffline() {
  if (!('serviceWorker' in navigator)) return;
  fetch('sw.js', { method: 'HEAD' })
    .then(function (response) {
      if (!response.ok) return;
      navigator.serviceWorker.register('sw.js');
      keepFiles();
      return navigator.serviceWorker.ready.then(function (registration) {
        setTimeout(function () {
          registration.active?.postMessage('keep-sounds');
        }, 3000);
      });
    })
    .catch(function () {});
}

// An app on the Home Screen asks the browser to keep its files even when
// the phone runs short of space, so that it still opens with no network.
// A page in a tab does not ask: some browsers would put a question to the
// player for it.
function keepFiles() {
  const standalone = navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches;
  if (!standalone || !navigator.storage || !navigator.storage.persist) return;
  navigator.storage.persisted()
    .then(function (kept) { if (!kept) return navigator.storage.persist(); })
    .catch(function () {});
}

// A page may make sound only in answer to a touch. The engine is got ready
// before one, held silent by the browser ("suspended"), and Safari on the
// iPhone also cuts its sound for a call, Siri, an alarm or the locked
// screen ("interrupted"). Any touch wakes it from either, as it happens:
// then the browser counts it as asked for. The app asks too before each
// sound (lowEndWakeAudio), and waits until the engine is awake.
function wakeAudio() {
  const context = window.lowEndAudioContext;
  if (!context || context.state === 'running' || context.state === 'closed') {
    return Promise.resolve(context ? context.state : 'none');
  }
  return context.resume().then(
    function () { return context.state; },
    function () { return context.state; });
}
window.lowEndWakeAudio = wakeAudio;
['pointerup', 'touchend', 'keydown'].forEach(function (type) {
  document.addEventListener(type, wakeAudio, true);
});

// With nothing to play the engine still mixes silence, all the time: some
// seconds after the last sound it is put to sleep, and the next touch wakes
// it. The app says whether something plays (lowEndAudioIdle, see
// web_audio_engine_web.dart).
let audioIdle = true, audioAsleep = false, audioSleep = 0;
function sleepAudioLater() {
  clearTimeout(audioSleep);
  audioSleep = setTimeout(function () {
    const context = window.lowEndAudioContext;
    if (!audioIdle || !context || context.state !== 'running') return;
    audioAsleep = true;
    context.suspend().catch(function () {});
  }, 20000);
}
window.lowEndAudioIdle = function (idle) {
  audioIdle = idle;
  clearTimeout(audioSleep);
  if (idle) sleepAudioLater();
};

// The app hears when the browser stops the engine's sound by itself (an
// interruption, not our sleep), so as not to look as if it played on
// unheard (lowEndAudioCut, set by web_audio_engine_web.dart).
function watchAudio(context) {
  context.addEventListener('statechange', function () {
    if (context.state === 'running') {
      // Woken with nothing to play (a touch, or the end of a call), it
      // goes back to sleep in a while.
      audioAsleep = false;
      if (audioIdle) sleepAudioLater();
      return;
    }
    if (context.state === 'closed' || audioAsleep) return;
    if (window.lowEndAudioCut) window.lowEndAudioCut();
  });
  if (audioIdle) sleepAudioLater();
}

if ('serviceWorker' in navigator) {
  // The first opening runs without the service worker, so without the
  // headers it adds: the audio engine mixes on the page's thread, where it
  // can skip beats. As soon as the worker takes over, the page is opened
  // again with them, unless a sound or the microphone has already started
  // (lowEndAudioInUse, set by the app); once per session, so that a browser
  // that ignores the headers is not reloaded again and again.
  navigator.serviceWorker.addEventListener('controllerchange', function () {
    if (window.crossOriginIsolated || window.lowEndAudioInUse) return;
    try {
      if (sessionStorage.getItem('lowEndReloaded')) return;
      sessionStorage.setItem('lowEndReloaded', '1');
    } catch (_) {
      return;
    }
    location.reload();
  });
}
