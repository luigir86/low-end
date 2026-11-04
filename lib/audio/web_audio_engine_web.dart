import 'dart:js_interop';

@JS('lowEndAudioEngine')
external JSPromise<JSAny?>? get _loaded;

@JS('lowEndLoadAudioEngine')
external JSFunction? get _load;

@JS('lowEndAudioInUse')
external set _inUse(bool value);

@JS('lowEndCatchAudioContext')
external set _catchContext(bool value);

@JS('crossOriginIsolated')
external bool? get _crossOriginIsolated;

@JS('lowEndAudioContext')
external _AudioContext? get _context;

extension type _AudioContext(JSObject _) implements JSObject {
  external JSNumber? get baseLatency;
  external JSNumber? get outputLatency;
}

/// Waits until the page has loaded the audio engine, starting it now if
/// the page has not yet (a sound asked for right after the first frame).
/// Pages without the loader (none today) are not waited for.
Future<void> webAudioEngineLoaded() async {
  markWebAudioInUse();
  final loaded = _loaded;
  if (loaded == null) return;
  _load?.callAsFunction();
  await loaded.toDart;
  // The engine starts next: the page keeps its AudioContext.
  _catchContext = true;
}

/// How late the browser says the engine's sound is heard after it leaves
/// the engine (its baseLatency and outputLatency), or null before the
/// engine has started. A phone's browser can be much slower than its app.
Duration? webOutputLatency() {
  final context = _context;
  if (context == null) return null;
  final seconds =
      (context.baseLatency?.toDartDouble ?? 0) +
      (context.outputLatency?.toDartDouble ?? 0);
  return Duration(microseconds: (seconds * 1e6).round());
}

/// Tells the page that a sound or the microphone has started, so that it is
/// not reloaded under the player's hands (see web/flutter_bootstrap.js).
void markWebAudioInUse() => _inUse = true;

/// Whether the page is cross-origin isolated: opened under the service
/// worker (not the very first opening), with the audio engine on its own
/// thread (see web/flutter_bootstrap.js).
bool webPageIsolated() => _crossOriginIsolated ?? false;
