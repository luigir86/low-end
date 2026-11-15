// The continuous tone (Harmony without the piano) on the fake engine: a
// stop while a tone is still being built leaves nothing sounding.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/tone_output.dart';

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
}
