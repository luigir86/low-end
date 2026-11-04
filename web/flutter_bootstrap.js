{{flutter_js}}
{{flutter_build_config}}

// The audio engine (flutter_soloud, in WebAssembly) is loaded once the app
// is on screen, not before: it is not needed until the first sound, and
// loading it earlier slowed the first screen down. The app waits for this
// promise before its first sound (web_audio_engine_web.dart).
// The audio engine's own AudioContext, kept so the app can ask the browser
// how late what it plays is heard (outputLatency, web_audio_engine_web.dart).
// The app raises lowEndCatchAudioContext just before the engine starts; the
// microphone's context, made at another time, is not taken for it.
if (window.AudioContext) {
  window.AudioContext = class extends window.AudioContext {
    constructor(...args) {
      super(...args);
      if (window.lowEndCatchAudioContext) {
        window.lowEndCatchAudioContext = false;
        window.lowEndAudioContext = this;
      }
    }
  };
}

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

window.lowEndAudioEngine = new Promise(function (resolve) {
  let started = false;
  window.lowEndLoadAudioEngine = function () {
    if (started) return;
    started = true;
    const script = document.createElement('script');
    script.src = 'assets/packages/flutter_soloud/web/init_soloud.js';
    script.onload = resolve;
    script.onerror = resolve;
    document.head.appendChild(script);
  };
});

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
        if (!firstOpening) window.lowEndLoadAudioEngine();
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
      return navigator.serviceWorker.ready.then(function (registration) {
        setTimeout(function () {
          registration.active?.postMessage('keep-sounds');
        }, 3000);
      });
    })
    .catch(function () {});
}

// A browser may hold the audio engine silent ("suspended") if it started
// at a moment it did not count as a touch; any later touch wakes it.
['pointerup', 'touchend', 'keydown'].forEach(function (type) {
  document.addEventListener(type, function () {
    const context = window.lowEndAudioContext;
    if (context && context.state === 'suspended') context.resume();
  }, true);
});

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
