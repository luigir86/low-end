/// Tells Safari on the iPhone what the web app's sound is for (its
/// navigator.audioSession, Safari 16.4 and later): music, so that the
/// silent switch does not mute the clicks and the piano, or music while the
/// microphone listens. Does nothing in the Android app and in the tests.
library;

import 'web_audio_session_stub.dart'
    if (dart.library.js_interop) 'web_audio_session_web.dart';

export 'web_audio_session_stub.dart'
    if (dart.library.js_interop) 'web_audio_session_web.dart';

/// Sets the audio session: [setWebAudioSession], or a fake in the tests.
typedef WebAudioSessionSetter = void Function({required bool listening});

/// Asks for the microphone with [ask], the session already set for
/// listening.
///
/// Safari refuses the microphone while the session says music only
/// ("playback", set as the app opens): getUserMedia fails at once and the
/// player is never asked (WebKit's MediaDevices, "AudioSession category is
/// not compatible with audio capture"). So the tuner and the Player's REC
/// said "no microphone" on every iPhone where it had not been allowed yet.
/// The session goes back to music when the answer is no; with a yes the
/// listening that follows keeps it.
Future<bool> askForMicrophone(
  Future<bool> Function() ask, {
  WebAudioSessionSetter session = setWebAudioSession,
}) async {
  session(listening: true);
  var allowed = false;
  try {
    allowed = await ask();
    return allowed;
  } finally {
    if (!allowed) session(listening: false);
  }
}
