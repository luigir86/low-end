/// See web_audio_engine.dart: nothing to wait for outside a web page.
Future<void> webAudioEngineLoaded() async {}

/// See web_audio_engine.dart: nothing to tell outside a web page.
void markWebAudioInUse() {}

/// See web_audio_engine.dart: only a browser can say.
Duration? webOutputLatency() => null;

/// See web_audio_engine.dart: not a web page.
bool webPageIsolated() => false;
