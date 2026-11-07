// The Player's speed and loop (RF-PLY-08 to RF-PLY-12): the rules of the
// points A and B, without a phone.

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/player/player_controller.dart';

const _song = TrackRef(uri: 'content://song', name: 'Blue Bossa.mp3');
const _other = TrackRef(uri: 'content://other', name: 'Other.m4a');

Duration _s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// A silent output that remembers each loop it is told.
class _Output extends SilentTrackOutput {
  final loops = <(Duration, Duration)?>[];

  @override
  Future<void> setLoop(Duration? start, Duration? end) {
    loops.add(start != null && end != null ? (start, end) : null);
    return super.setLoop(start, end);
  }
}

void main() {
  late _Output output;
  late PlayerController player;

  setUp(() async {
    output = _Output();
    player = PlayerController(output, FakeTrackFiles(next: _song));
    await player.pick();
  });

  tearDown(() => player.dispose());

  /// Listens to the track [at] seconds in.
  Future<void> listenAt(num at, {bool playing = false}) async {
    await player.seek(_s(at));
    if (playing) await player.start();
  }

  group('speed (RF-PLY-08)', () {
    test('starts at 100 and goes to the output as a fraction', () {
      expect(player.speed, 100);
      player.setSpeed(70);
      expect(player.speed, 70);
      expect(output.speed, 0.7);
    });

    test('stays between 50 and 125', () {
      player.setSpeed(10);
      expect(player.speed, 50);
      expect(output.speed, 0.5);
      player.setSpeed(300);
      expect(player.speed, 125);
      expect(output.speed, 1.25);
    });

    test('another track starts again at 100', () async {
      player.setSpeed(60);
      await player.open(_other);
      expect(player.speed, 100);
      expect(output.speed, 1.0);
    });
  });

  group('marking the ends (RF-PLY-09)', () {
    test('A is where the track is heard, less the reaction', () async {
      await listenAt(10);
      await player.mark(LoopEdge.start);
      expect(player.loopStart, _s(9.85));
      expect(player.loopEnd, isNull);
      expect(player.looping, isFalse);
    });

    test('the reaction is in real time: at half speed it is half as '
        'much track', () async {
      player.setSpeed(50);
      await listenAt(10);
      await player.mark(LoopEdge.start);
      expect(player.loopStart, _s(9.925));
    });

    test('A is not before the start of the track', () async {
      await listenAt(0.05);
      await player.mark(LoopEdge.start);
      expect(player.loopStart, Duration.zero);
    });

    test('B alone stays alone: no loop until A is placed too', () async {
      await listenAt(30, playing: true);
      await player.mark(LoopEdge.end);
      expect(player.loopStart, isNull);
      expect(player.loopEnd, _s(29.85));
      expect(player.looping, isFalse);
      expect(output.loop, isNull);
      expect(player.position, _s(30));
    });

    test('with both placed the loop turns on, and a track that plays goes '
        'back to A', () async {
      await player.place(LoopEdge.end, _s(40));
      await listenAt(30, playing: true);
      await player.mark(LoopEdge.start);
      expect(player.loopStart, _s(29.85));
      expect(player.loopEnd, _s(40));
      expect(player.looping, isTrue);
      expect(output.loop, (_s(29.85), _s(40)));
      expect(player.position, _s(29.85));
    });

    test('B less than a second after A sends A back to its corner', () async {
      await listenAt(10);
      await player.mark(LoopEdge.start);
      await listenAt(10.5);
      await player.mark(LoopEdge.end);
      expect(player.loopStart, isNull);
      expect(player.loopEnd, _s(10.35));
      expect(player.looping, isFalse);
    });

    test('B stays within the track', () async {
      await player.place(LoopEdge.end, _s(400));
      expect(player.loopEnd, output.length);
    });

    test('A keeps a second for the loop', () async {
      await player.place(LoopEdge.start, _s(400));
      expect(player.loopStart, output.length - const Duration(seconds: 1));
    });

    test('A that leaves less than a second to B clears B and turns the '
        'loop off', () async {
      await player.setLoop(_s(10), _s(20));
      await listenAt(19.5);
      await player.mark(LoopEdge.start);
      expect(player.loopStart, _s(19.35));
      expect(player.loopEnd, isNull);
      expect(player.looping, isFalse);
      expect(output.loop, isNull);
    });

    test('A marked again with the loop on moves it without a jump', () async {
      await player.setLoop(_s(10), _s(20));
      await listenAt(15);
      await player.mark(LoopEdge.start);
      expect(output.loop, (_s(14.85), _s(20)));
      expect(player.position, _s(15));
    });
  });

  group('the flags (RF-PLY-08)', () {
    test('A is the active one at first, and with each new track', () async {
      expect(player.activeEdge, LoopEdge.start);
      await player.place(LoopEdge.end, _s(30));
      expect(player.activeEdge, LoopEdge.end);
      await player.open(const TrackRef(uri: 'content://b', name: 'B.wav'));
      expect(player.activeEdge, LoopEdge.start);
    });

    test('the one placed, moved or touched becomes the active one', () async {
      await player.place(LoopEdge.start, _s(10));
      expect(player.activeEdge, LoopEdge.start);
      await player.place(LoopEdge.end, _s(20));
      expect(player.activeEdge, LoopEdge.end);
      player.focus(LoopEdge.start);
      expect(player.activeEdge, LoopEdge.start);
      player.moveEdge(LoopEdge.end, _s(25));
      expect(player.activeEdge, LoopEdge.end);
      await player.setLoop(_s(5), _s(8));
      expect(player.activeEdge, LoopEdge.end);
    });

    test('placing A past B sends B back, and the loop turns off', () async {
      await player.place(LoopEdge.start, _s(10));
      await player.place(LoopEdge.end, _s(20));
      expect(player.looping, isTrue);
      await player.place(LoopEdge.start, _s(19.5));
      expect(player.loopStart, _s(19.5));
      expect(player.loopEnd, isNull);
      expect(player.looping, isFalse);
      expect(output.loop, isNull);
    });

    test('placing B before A sends A back', () async {
      await player.place(LoopEdge.start, _s(10));
      await player.place(LoopEdge.end, _s(10.5));
      expect(player.loopStart, isNull);
      expect(player.loopEnd, _s(10.5));
      expect(player.looping, isFalse);
    });

    test('two taps at the same paused position keep A and create the shortest loop', () async {
      await player.seek(_s(10));
      await player.captureOrToggle();
      await player.captureOrToggle();
      expect(player.loopStart, _s(10));
      expect(player.loopEnd, _s(10) + PlayerController.minLoop);
      expect(player.looping, isTrue);
    });

    test('the arrows move the active flag, B alone too', () async {
      await player.place(LoopEdge.end, _s(30));
      player.nudge(LoopEdge.end, const Duration(milliseconds: 10));
      expect(player.loopEnd, _s(30.01));
    });
  });

  group('setting the loop (RF-PLY-12)', () {
    test('puts the ends in order and turns it on', () async {
      await player.setLoop(_s(30), _s(20));
      expect(player.loopStart, _s(20));
      expect(player.loopEnd, _s(30));
      expect(player.looping, isTrue);
      expect(output.loop, (_s(20), _s(30)));
    });

    test('a loop too short is made a second long', () async {
      await player.setLoop(_s(10), _s(10.2));
      expect(player.loopEnd, _s(11));
    });

    test('a loop that goes past the end moves back', () async {
      await player.setLoop(_s(359.5), _s(400));
      expect(player.loopEnd, output.length);
      expect(player.loopStart, output.length - const Duration(seconds: 1));
    });

    test('a track that plays goes back to A; one that does not stays where '
        'it is, if inside', () async {
      await listenAt(15);
      await player.setLoop(_s(10), _s(20));
      expect(player.position, _s(15));
      await listenAt(15, playing: true);
      await player.setLoop(_s(12), _s(18));
      expect(player.position, _s(12));
    });

    test('turned off, A and B stay marked; on again goes to A if the track '
        'is elsewhere', () async {
      await player.setLoop(_s(10), _s(20));
      await player.setLooping(false);
      expect(player.looping, isFalse);
      expect(player.loopStart, _s(10));
      expect(output.loop, isNull);
      await listenAt(100);
      await player.setLooping(true);
      expect(player.looping, isTrue);
      expect(player.position, _s(10));
      expect(output.loop, (_s(10), _s(20)));
    });

    test('cannot be turned on without both ends', () async {
      await player.setLooping(true);
      expect(player.looping, isFalse);
      await listenAt(10);
      await player.mark(LoopEdge.start);
      await player.setLooping(true);
      expect(player.looping, isFalse);
      expect(output.loops, isEmpty);
    });

    test('a seek outside the loop turns it off and keeps A and B; inside '
        'it does not', () async {
      await player.setLoop(_s(10), _s(20));
      await player.seek(_s(15));
      expect(player.looping, isTrue);
      await player.seek(_s(30));
      expect(player.looping, isFalse);
      expect(player.loopStart, _s(10));
      expect(player.loopEnd, _s(20));
      expect(output.loop, isNull);
      expect(player.position, _s(30));
    });

    test('B itself is outside the loop', () async {
      await player.setLoop(_s(10), _s(20));
      await player.seek(_s(20));
      expect(player.looping, isFalse);
    });

    test('another track clears the loop', () async {
      await player.setLoop(_s(10), _s(20));
      await player.open(_other);
      expect(player.hasLoop, isFalse);
      expect(player.looping, isFalse);
      expect(output.loop, isNull);
    });

    test('the silent output goes round the loop, and does not end', () async {
      final ended = <TrackEvent>[];
      output.events.listen(ended.add);
      await player.setLoop(_s(10), _s(20));
      await player.start();
      output.advance(_s(15));
      expect(player.position, _s(15));
      output.advance(_s(7));
      expect(player.position, _s(12));
      expect(ended, isEmpty);
    });
  });

  group('the ends moved by touches (RF-PLY-10)', () {
    test('a touch moves the number at once, by a hundredth', () async {
      await player.setLoop(_s(10), _s(20));
      expect(PlayerController.fineStep, const Duration(milliseconds: 10));
      expect(PlayerController.coarseStep, const Duration(milliseconds: 100));
      player.nudge(LoopEdge.start, PlayerController.fineStep);
      expect(player.loopStart, _s(10.01));
      player.nudge(LoopEdge.end, -PlayerController.fineStep);
      expect(player.loopEnd, _s(19.99));
    });

    test('moveEdge puts an end at a time, within the same limits', () async {
      await player.setLoop(_s(10), _s(20));
      player.moveEdge(LoopEdge.start, _s(12.34));
      expect(player.loopStart, _s(12.34));
      player.moveEdge(LoopEdge.end, _s(15));
      expect(player.loopEnd, _s(15));
      // A stops one second before B, B one second after A.
      player.moveEdge(LoopEdge.start, _s(40));
      expect(player.loopStart, _s(14));
      player.moveEdge(LoopEdge.end, _s(1));
      expect(player.loopEnd, _s(15));
      player.moveEdge(LoopEdge.start, _s(-3));
      expect(player.loopStart, Duration.zero);
    });

    test('moveEdge with an end not marked does nothing', () async {
      player.moveEdge(LoopEdge.start, _s(5));
      expect(player.loopStart, isNull);
      expect(player.loopEnd, isNull);
    });

    test('each end stops at its limit and does not push the other', () async {
      await player.setLoop(_s(10), _s(12));
      player.nudge(LoopEdge.start, _s(5));
      expect(player.loopStart, _s(11));
      expect(player.loopEnd, _s(12));
      player.nudge(LoopEdge.end, _s(-5));
      expect(player.loopEnd, _s(12));
      player.nudge(LoopEdge.start, _s(-100));
      expect(player.loopStart, Duration.zero);
      player.nudge(LoopEdge.end, _s(1000));
      expect(player.loopEnd, output.length);
      player.nudge(LoopEdge.end, _s(-1000));
      expect(player.loopEnd, _s(1));
    });

    test('an end that is not marked does not move', () async {
      player.nudge(LoopEdge.end, _s(1));
      expect(player.loopEnd, isNull);
      await listenAt(10);
      await player.mark(LoopEdge.start);
      player.nudge(LoopEdge.end, _s(1));
      expect(player.loopEnd, isNull);
    });

    test('with the loop off the output is not told', () async {
      await player.setLoop(_s(10), _s(20));
      await player.setLooping(false);
      output.loops.clear();
      player.nudge(LoopEdge.start, _s(1));
      expect(player.loopStart, _s(11));
      expect(output.loops, isEmpty);
    });

    testWidgets('the sound follows when the touching has stopped: three quick '
        'touches are one change', (tester) async {
      await player.setLoop(_s(10), _s(20));
      await player.start();
      output.loops.clear();
      for (var i = 0; i < 3; i++) {
        player.nudge(LoopEdge.start, PlayerController.fineStep);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(output.loops, isEmpty);
      await tester.pump(PlayerController.settleAfter);
      expect(output.loops, [(_s(10.03), _s(20))]);
      // A moved: it plays again from A.
      expect(player.position, _s(10.03));
    });

    testWidgets('B moved: it plays again two seconds before B', (tester) async {
      await player.setLoop(_s(10), _s(20));
      await player.start();
      player.nudge(LoopEdge.end, -PlayerController.fineStep);
      await tester.pump(PlayerController.settleAfter);
      expect(output.loops.last, (_s(10), _s(19.99)));
      expect(player.position, _s(17.99));
    });

    testWidgets('B moved near A: it plays again from A', (tester) async {
      await player.setLoop(_s(10), _s(11.5));
      await player.start();
      player.nudge(LoopEdge.end, PlayerController.fineStep);
      await tester.pump(PlayerController.settleAfter);
      expect(player.position, _s(10));
    });

    testWidgets('paused, the track stays where it is if inside the loop', (
      tester,
    ) async {
      await player.setLoop(_s(10), _s(20));
      await listenAt(15);
      player.nudge(LoopEdge.start, _s(1));
      await tester.pump(PlayerController.settleAfter);
      expect(player.position, _s(15));
      expect(output.loop, (_s(11), _s(20)));
    });
  });
}
