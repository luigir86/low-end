/// See web_audio_engine.dart: nothing to wait for outside a web page.
Future<void> webAudioEngineLoaded() async {}

/// See web_audio_engine.dart: no AudioContext to pick outside a web page.
void markWebAudioEngineStarted() {}

/// See web_audio_engine.dart: nothing to tell outside a web page.
void markWebAudioInUse() {}

/// See web_audio_engine.dart: only a browser can say.
Duration? webOutputLatency() => null;

/// See web_audio_engine.dart: not a web page.
bool webPageIsolated() => false;

/// See web_audio_engine.dart: outside a web page the sound is never held.
Future<void> webAudioAwake(Duration warmUp) async {}

/// See web_audio_engine.dart: nothing to tell outside a web page.
void setWebAudioIdle(bool idle) {}

/// See web_audio_engine.dart: no browser to cut the sound.
void onWebAudioCut(void Function() cut) {}
