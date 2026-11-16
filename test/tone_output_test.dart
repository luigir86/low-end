// The continuous tone (Harmony without the piano) on the fake engine: a
// stop while a tone is still being built leaves nothing sounding.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';

import 'fake_loop_engine.dart';

void main() {
  late FakeLoopEngine engine;
  late Completer<void> built;
  late SoLoudToneOutput tone;

  setUp(() {
    engine = FakeLoopEngine();
    built = Completer<void>();
    tone = SoLoudToneOutput(
      engine: engine,
      engineReady: () async {},
      build: (frequencies, gains) async {
        await built.future;
        return fakeWav(const Duration(seconds: 1));
      },
    );
  });

  Iterable<FakeVoice> sounding() => engine.playing('drone.wav');

  test('a tone plays, and a stop lets it go', () async {
    built.complete();
    await tone.play([220], [1], 0.8);
    expect(sounding(), hasLength(1));
    await tone.stop();
    engine.advance(const Duration(milliseconds: 100));
    expect(sounding(), isEmpty);
  });

  test('a stop while the tone is built: nothing sounds after', () async {
    final playing = tone.play([220], [1], 0.8);
    await Future<void>.delayed(Duration.zero);
    await tone.stop();
    built.complete();
    Object? thrown;
    try {
      await playing;
    } catch (error) {
      thrown = error;
    }
    expect(sounding(), isEmpty, reason: 'a tone started after the stop');
    expect(thrown, isA<LoopNotWanted>());
  });

  group('Harmony without the piano', () {
    test('stopped while the tone is built: silent, and no error', () async {
      final drone = DroneController(tone);
      final started = drone.start();
      await Future<void>.delayed(Duration.zero);
      final stopped = drone.stop();
      built.complete();
      await Future.wait([started, stopped]);
      expect(sounding(), isEmpty);
      expect(drone.isPlaying, isFalse);
      expect(drone.audioFailed, isFalse);
    });

    test('started, stopped and started again while the tone is built: '
        'one tone plays', () async {
      final drone = DroneController(tone);
      final first = drone.start();
      await Future<void>.delayed(Duration.zero);
      final stopped = drone.stop();
      final second = drone.start();
      built.complete();
      await Future.wait([first, stopped, second]);
      expect(sounding(), hasLength(1));
      expect(drone.isPlaying, isTrue);
      expect(drone.audioFailed, isFalse);
      await drone.stop();
      drone.dispose();
    });
  });
}
