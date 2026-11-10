import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/loop_transport.dart';

import 'fake_loop_engine.dart';

void main() {
  const ms = Duration(milliseconds: 1);

  group('after a change of tempo the piano comes back on the click', () {
    // From 100 to 200 BPM in 4/4: bars of 2.4 s, then 1.2 s.
    const oldBar = Duration(milliseconds: 2400), bar = Duration(seconds: 1);

    test('at the click\'s place in the bar, not its own', () {
      // The piano, still at the old tempo, is a quarter into its second
      // bar; the click, already at the new one, is half way through.
      final at = LoopTransport.followerPosition(
        oldPosition: oldBar * 1.25,
        oldBar: oldBar,
        bar: bar,
        bars: 3,
        leaderPhase: 0.5,
      );
      expect(at, bar * 1.5);
    });

    test('in the right bar when the two drifted across a bar line', () {
      // The piano is about to finish its first bar; the click has just
      // started the next one: the piano's next chord is meant.
      expect(
        LoopTransport.followerPosition(
          oldPosition: oldBar * 0.95,
          oldBar: oldBar,
          bar: bar,
          bars: 3,
          leaderPhase: 0.05,
        ),
        bar * 1.05,
      );
      // And the other way round, wrapping to the last bar of the loop.
      expect(
        LoopTransport.followerPosition(
          oldPosition: oldBar * 0.05,
          oldBar: oldBar,
          bar: bar,
          bars: 3,
          leaderPhase: 0.95,
        ),
        bar * 2.95,
      );
    });
  });

  group('a loop comes in on the other loop\'s next bar line', () {
    const bar = Duration(seconds: 2);

    test('counted from its position while it plays', () {
      expect(
        LoopTransport.waitForBarLine(bar: bar, position: ms * 4500),
        ms * 1500,
      );
      // Too close to schedule: the bar line after.
      expect(
        LoopTransport.waitForBarLine(bar: bar, position: ms * 1980),
        ms * 2020,
      );
    });

    test('counted from its start while it is still waiting to come in', () {
      // Changing the time signature with both playing: the click waits for
      // the piano's bar line, and the new piano for the click's start, not
      // a whole bar later (a waiting voice says it is at 0).
      expect(
        LoopTransport.waitForBarLine(bar: bar, untilStart: ms * 700),
        ms * 700,
      );
      expect(
        LoopTransport.waitForBarLine(bar: bar, untilStart: ms * 30),
        ms * 2030,
      );
    });
  });

  test('a meeting holds until the piano'
      's new loop has come in', () {
    final engine = FakeLoopEngine();
    final transport = LoopTransport(engine: engine);
    expect(transport.meetingAt, isNull);
    transport.beginMeeting(ms * 4000);
    expect(transport.meetingAt, ms * 4000);
    // Scheduled later than aimed: met there, still to come.
    transport.meet(ms * 6000);
    engine.advance(ms * 5000);
    expect(transport.meetingAt, ms * 6000);
    // Come in: nothing left to meet for a later change.
    engine.advance(ms * 1000);
    expect(transport.meetingAt, isNull);
  });
}
