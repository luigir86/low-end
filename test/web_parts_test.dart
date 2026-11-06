import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/audio_route.dart';
import 'package:low_end/audio/off_thread.dart';
import 'package:low_end/audio/soloud_engine.dart';
import 'package:low_end/audio/web_audio_engine.dart';
import 'package:low_end/audio/web_audio_session.dart';
import 'package:low_end/audio/web_peaks_limits.dart';

// The pieces the web app uses in place of Android's (docs/web.md).
void main() {
  test('the web route is the speaker, and never unplugged', () async {
    final route = SpeakerAudioRoute();
    expect(route.outputLatency, outputLatencyFor(AudioOutputKind.speaker));
    expect(await route.unplugged.isEmpty, isTrue);
    route.dispose();
  });

  test('offThread gives back what the work makes', () async {
    expect(await offThread(() => List.generate(4, (i) => i * i)), [0, 1, 4, 9]);
  });

  test('the audio session is left alone outside a web page', () {
    setWebAudioSession(listening: true);
    setWebAudioSession(listening: false);
  });

  test('outside a web page the audio engine is not waited for', () async {
    await webAudioEngineLoaded();
    markWebAudioInUse();
    // Only a browser says how late its sound is heard.
    expect(webOutputLatency(), isNull);
  });

  group('the wave of a track in a web page (RF-PLY-15)', () {
    test('is read up to 40 MB and 15 minutes, no further', () {
      const ok = Duration(minutes: 15);
      expect(webPeaksAllowed(size: webPeaksMaxBytes, duration: ok), isTrue);
      expect(
        webPeaksAllowed(size: webPeaksMaxBytes + 1, duration: ok),
        isFalse,
      );
      expect(
        webPeaksAllowed(size: 1000, duration: ok + const Duration(seconds: 1)),
        isFalse,
      );
    });

    test('a file of unknown size is judged by its length', () {
      expect(
        webPeaksAllowed(size: null, duration: const Duration(minutes: 6)),
        isTrue,
      );
    });
  });
}
