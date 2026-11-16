// Put first in the page by server.mjs. Two jobs:
//
// 1. Adds the iPhone's rules that WebKitGTK (Safari's engine on Linux)
//    leaves out, because Apple keeps them in its own platform code:
//    - navigator.audioSession (Safari 16.4+): while its type is not "auto"
//      or "play-and-record", getUserMedia fails at once and nobody is asked
//      (WebKit MediaDevices.cpp: "AudioSession category is not compatible
//      with audio capture").
//    - The microphone permission reads "prompt" until it is allowed in this
//      page, as in Safari, where it is asked again at every opening.
//    The touch rules for sound (an AudioContext or an audio element plays
//    only after a touch) are WebKit's own: the test switches them on.
// 2. Notes for the test what happened: errors, the microphone, the first
//    audible sample, the audio elements' play() answers.
(() => {
  const probe = window.__iphone = {
    errors: [], logs: [], mic: [], plays: [], contexts: [],
    sound: 0, soundSince: null,
  };
  addEventListener('error', (e) => probe.errors.push(String(e.message)));
  addEventListener('unhandledrejection', (e) =>
    probe.errors.push('unhandled rejection: ' + String(e.reason && (e.reason.stack || e.reason))));
  for (const level of ['log', 'warn', 'error']) {
    const original = console[level].bind(console);
    console[level] = (...args) => {
      try { probe.logs.push(level + ': ' + args.map(String).join(' ').slice(0, 300)); } catch (_) {}
      return original(...args);
    };
  }

  // The audio session.
  let sessionType = 'auto';
  const session = navigator.audioSession || {};
  try {
    Object.defineProperty(session, 'type', {
      configurable: true,
      get: () => sessionType,
      set: (value) => {
        if (!['auto', 'playback', 'transient', 'transient-solo', 'ambient', 'play-and-record'].includes(value)) return;
        sessionType = value;
        probe.sessions = (probe.sessions || []).concat(value);
      },
    });
    if (!navigator.audioSession) {
      Object.defineProperty(Navigator.prototype, 'audioSession', { configurable: true, get: () => session });
    }
  } catch (error) {
    probe.errors.push('shim: ' + error);
  }

  // The microphone.
  let micAllowed = false;
  // On the prototype: WebKit ignores a property set on navigator.mediaDevices
  // this early.
  const Devices = window.MediaDevices && MediaDevices.prototype;
  if (Devices && Devices.getUserMedia) {
    const getUserMedia = Devices.getUserMedia;
    Devices.getUserMedia = function (constraints) {
      if (constraints && constraints.audio &&
          sessionType !== 'auto' && sessionType !== 'play-and-record') {
        probe.mic.push('refused: session ' + sessionType);
        return Promise.reject(new DOMException(
          'AudioSession category is not compatible with audio capture.', 'InvalidStateError'));
      }
      return getUserMedia.call(this, constraints).then((stream) => {
        micAllowed = true;
        probe.mic.push('open');
        return stream;
      }, (error) => {
        probe.mic.push('failed: ' + error.name);
        throw error;
      });
    };
  }
  const permissions = window.Permissions && window.Permissions.prototype;
  if (permissions && permissions.query) {
    const query = permissions.query;
    permissions.query = function (descriptor) {
      probe.queries = (probe.queries || []).concat(descriptor && descriptor.name);
      if (descriptor && descriptor.name === 'microphone') {
        return Promise.resolve({ state: micAllowed ? 'granted' : 'prompt', onchange: null,
          addEventListener() {}, removeEventListener() {} });
      }
      return query.call(this, descriptor);
    };
  }

  // Sound: a listener on every connection to the speakers notes the
  // samples that are not silent.
  const listener = 'class L extends AudioWorkletProcessor{process(i){const c=i[0]&&i[0][0];' +
    'if(c){for(let k=0;k<c.length;k++){if(Math.abs(c[k])>1e-3){this.port.postMessage(1);break}}}return true}}' +
    'registerProcessor("iphone-listener",L)';
  const listenerUrl = URL.createObjectURL(new Blob([listener], { type: 'text/javascript' }));
  const listeners = new WeakMap();
  const connect = AudioNode.prototype.connect;
  function listenerFor(context) {
    if (!listeners.has(context)) {
      listeners.set(context, context.audioWorklet.addModule(listenerUrl).then(() => {
        const node = new AudioWorkletNode(context, 'iphone-listener');
        const mute = context.createGain();
        mute.gain.value = 0;
        connect.call(node, mute);
        connect.call(mute, context.destination);
        node.port.onmessage = () => {
          probe.sound++;
          if (probe.soundSince == null) probe.soundSince = performance.now();
        };
        return node;
      }));
    }
    return listeners.get(context);
  }
  AudioNode.prototype.connect = function (destination, ...rest) {
    const result = connect.call(this, destination, ...rest);
    if (destination instanceof AudioDestinationNode && this.context instanceof AudioContext) {
      listenerFor(this.context).then((node) => connect.call(this, node)).catch(() => {});
    }
    return result;
  };
  const Context = window.AudioContext;
  window.AudioContext = class extends Context {
    constructor(...args) {
      super(...args);
      const entry = { state: this.state, at: performance.now() };
      probe.contexts.push(entry);
      this.addEventListener('statechange', () => { entry.state = this.state; });
    }
  };

  // Audio elements (the Player): what play() answers.
  const play = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function () {
    const promise = play.call(this);
    if (promise && promise.then) {
      promise.then(() => probe.plays.push('playing'), (error) => probe.plays.push('refused: ' + error.name));
    }
    return promise;
  };
})();

// The file chooser: what the page asks for is noted, and no chooser opens
// (it would wait for a person). Safari on the iPhone reads accept="audio/*"
// as video (WebKit WKFileUploadPanel.mm): the menu then offers the photo
// library and the video camera instead of the song files.
(() => {
  const probe = window.__iphone;
  probe.choosers = [];
  const click = HTMLInputElement.prototype.click;
  HTMLInputElement.prototype.click = function () {
    if (this.type === 'file') {
      probe.choosers.push(this.accept);
      return;
    }
    return click.call(this);
  };
})();

// A player who said no to the microphone: localStorage iphoneMic = 'no'.
(() => {
  const probe = window.__iphone;
  let no = false;
  try { no = localStorage.getItem('iphoneMic') === 'no'; } catch (_) {}
  if (!no) return;
  const Devices = MediaDevices.prototype;
  const getUserMedia = Devices.getUserMedia;
  Devices.getUserMedia = function (constraints) {
    if (constraints && constraints.audio && navigator.audioSession.type !== 'playback') {
      probe.mic.push('denied');
      return Promise.reject(new DOMException('The request is not allowed.', 'NotAllowedError'));
    }
    return getUserMedia.call(this, constraints);
  };
})();
