// Stop silences the piano at once, whatever it is doing: playing, waiting
// for its bar line, or handing over to a new loop. Followed on the fake
// engine, which knows which voices sound, and how loud.
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/bar_loop_player.dart';
import 'package:low_end/audio/loop_transport.dart';

import 'fake_loop_engine.dart';

const bar = Duration(seconds: 2);
const ms300 = Duration(milliseconds: 300);

/// The voices heard at [at], with their level.
String heard(FakeLoopEngine engine, Duration at) => engine.voices.values
    .where((v) => v.soundsAt(at) && v.volumeAt(at) > 0)
    .map((v) => '${v.name}@${v.volumeAt(at).toStringAsFixed(2)}')
    .join(', ');

void main() {
  test('stopping a piano that never sounded makes no tail', () async {
    // The metronome plays; Harmony waits for its next "one" and is
    // stopped before it.
    final engine = FakeLoopEngine();
    final transport = LoopTransport(engine: engine);
    final click = BarLoopPlayer('click', transport: transport);
    final piano = BarLoopPlayer('piano', transport: transport);
    var tails = 0;
    await click.play(fakeWav(bar), bar);
    engine.advance(ms300);
    final started = await piano.play(
      fakeWav(bar * 4),
      bar,
      startAt: Duration.zero,
    );
    expect(started.delay, greaterThan(Duration.zero));
    engine.advance(ms300);
    await piano.stop(
      tailFor: (position) async {
        tails++;
        return fakeWav(ms300);
      },
    );
    expect(tails, 0);
    expect(
      heard(engine, engine.now + const Duration(milliseconds: 1)),
      ['click-loop.wav@1.00'].join(),
    );
    await click.stop();
  });
}
