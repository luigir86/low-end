// The ring of the Player is the clock of the track (RF-PLY-03).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/features/player/player_controller.dart';
import 'package:low_end/features/player/player_dial.dart';
import 'package:low_end/features/player/ring_wave.dart';
import 'package:low_end/features/player/ring_window.dart';
import 'package:low_end/features/player/track_peaks.dart';
import 'package:low_end/widgets/dial.dart';

void main() {
  group('the ticks', () {
    RingWindow whole(Duration d) => RingWindow.whole(d);

    test('every minute for a usual track', () {
      const six = Duration(minutes: 6, seconds: 3);
      expect(tickInterval(six), const Duration(minutes: 1));
      expect(tickTimes(whole(six)), [
        for (var m = 1; m <= 6; m++) Duration(minutes: m),
      ]);
    });

    test('every ten seconds under two minutes', () {
      const short = Duration(seconds: 65);
      expect(tickInterval(short), const Duration(seconds: 10));
      expect(tickTimes(whole(short)).length, 6);
      expect(
        tickInterval(const Duration(minutes: 2)),
        const Duration(minutes: 1),
      );
    });

    test('every five minutes over twenty', () {
      const long = Duration(minutes: 52);
      expect(tickInterval(long), const Duration(minutes: 5));
      expect(tickTimes(whole(long)).length, 10);
      expect(
        tickInterval(const Duration(minutes: 20)),
        const Duration(minutes: 1),
      );
    });

    test('closer together in a short window', () {
      expect(
        tickInterval(const Duration(seconds: 4)),
        const Duration(milliseconds: 500),
      );
      expect(
        tickInterval(const Duration(seconds: 5)),
        const Duration(seconds: 1),
      );
      expect(
        tickInterval(const Duration(seconds: 19)),
        const Duration(seconds: 1),
      );
      expect(
        tickInterval(const Duration(seconds: 20)),
        const Duration(seconds: 5),
      );
      expect(
        tickInterval(const Duration(seconds: 59)),
        const Duration(seconds: 5),
      );
      expect(
        tickInterval(const Duration(seconds: 60)),
        const Duration(seconds: 10),
      );
    });

    test('no tick at the start, nor at the very end', () {
      expect(tickTimes(whole(const Duration(minutes: 3))), [
        const Duration(minutes: 1),
        const Duration(minutes: 2),
      ]);
      expect(tickTimes(whole(const Duration(seconds: 5))), [
        for (var s = 1; s < 5; s++) Duration(seconds: s),
      ]);
      expect(tickTimes(whole(Duration.zero)), isEmpty);
    });

    test('in a window they fall on the true multiples of the track', () {
      // 1:07 to 1:15 is 8 s: a tick every second, at 1:08, 1:09…
      const window = RingWindow(Duration(seconds: 67), Duration(seconds: 75));
      expect(tickTimes(window), [
        for (var s = 68; s < 75; s++) Duration(seconds: s),
      ]);
      // A window that starts on a tick leaves that one to the seam.
      const aligned = RingWindow(Duration(seconds: 60), Duration(seconds: 70));
      expect(tickTimes(aligned).first, const Duration(seconds: 61));
    });
  });

  group('the window of the ring', () {
    const track = Duration(minutes: 6);

    test('the whole track maps to a turn, from 12 o\'clock', () {
      final window = RingWindow.whole(track);
      expect(window.length, track);
      expect(window.angleOf(Duration.zero), 0);
      expect(
        window.angleOf(const Duration(minutes: 3)),
        closeTo(math.pi, 1e-9),
      );
      expect(window.angleOf(track), closeTo(2 * math.pi, 1e-9));
      // Outside it stops at the edges.
      expect(
        window.angleOf(const Duration(minutes: 9)),
        closeTo(2 * math.pi, 1e-9),
      );
      expect(window.angleOf(const Duration(seconds: -4)), 0);
    });

    test('time and angle are the two ways of one map', () {
      final window = RingWindow.whole(track);
      for (final seconds in [0, 1, 90, 211, 359]) {
        final t = Duration(seconds: seconds);
        expect(window.timeAt(window.angleOf(t)), t);
      }
    });

    test('a window that starts later counts from its start', () {
      const window = RingWindow(Duration(seconds: 10), Duration(seconds: 20));
      expect(
        window.angleOf(const Duration(seconds: 15)),
        closeTo(math.pi, 1e-9),
      );
      expect(window.timeAt(math.pi / 2), const Duration(milliseconds: 12500));
      expect(
        window,
        const RingWindow(Duration(seconds: 10), Duration(seconds: 20)),
      );
    });

    test('an empty window is at the top', () {
      expect(
        RingWindow.whole(Duration.zero).angleOf(const Duration(seconds: 1)),
        0,
      );
    });

    test('a touch at 3 o\'clock is a quarter of the window', () {
      const size = Size(300, 300);
      final whole = RingWindow.whole(track);
      // Right of the centre: a quarter turn.
      final angle = touchAngle(const Offset(280, 150), size);
      expect(angle, closeTo(math.pi / 2, 1e-9));
      expect(whole.timeAt(angle), const Duration(seconds: 90));
      // Above: the start. Left: three quarters. Below: half.
      expect(touchAngle(const Offset(150, 10), size), closeTo(0, 1e-9));
      expect(
        touchAngle(const Offset(20, 150), size),
        closeTo(3 * math.pi / 2, 1e-9),
      );
      expect(touchAngle(const Offset(150, 290), size), closeTo(math.pi, 1e-9));
    });

    group('the passage', () {
      test('has a quarter of its length as margin on each side', () {
        // 20 s: a margin of 5 s.
        final window = RingWindow.passage(
          const Duration(seconds: 60),
          const Duration(seconds: 80),
          track,
        );
        expect(
          window,
          const RingWindow(Duration(seconds: 55), Duration(seconds: 85)),
        );
      });

      test('the margin is at least half a second and at most ten', () {
        final short = RingWindow.passage(
          const Duration(seconds: 60),
          const Duration(seconds: 61),
          track,
        );
        expect(short.from, const Duration(milliseconds: 59500));
        expect(short.to, const Duration(milliseconds: 61500));
        final long = RingWindow.passage(
          const Duration(seconds: 30),
          const Duration(seconds: 150),
          track,
        );
        expect(long.from, const Duration(seconds: 20));
        expect(long.to, const Duration(seconds: 160));
      });

      test('never goes beyond the track', () {
        final early = RingWindow.passage(
          const Duration(seconds: 2),
          const Duration(seconds: 12),
          track,
        );
        expect(early.from, Duration.zero);
        final late = RingWindow.passage(
          const Duration(seconds: 350),
          const Duration(seconds: 359),
          track,
        );
        expect(late.to, track);
      });

      test('comes out the same with the ends the wrong way round', () {
        expect(
          RingWindow.passage(
            const Duration(seconds: 80),
            const Duration(seconds: 60),
            track,
          ),
          RingWindow.passage(
            const Duration(seconds: 60),
            const Duration(seconds: 80),
            track,
          ),
        );
      });
    });

    test('lerp goes from one window to the other', () {
      final whole = RingWindow.whole(track);
      final passage = RingWindow.passage(
        const Duration(seconds: 60),
        const Duration(seconds: 80),
        track,
      );
      expect(whole.lerp(passage, 0), whole);
      expect(whole.lerp(passage, 1), passage);
      final half = whole.lerp(passage, 0.5);
      expect(half.from, const Duration(seconds: 27, milliseconds: 500));
      expect(half.to, const Duration(seconds: 222, milliseconds: 500));
    });
  });

  group('the flags on the ring', () {
    const size = Size(300, 300);
    const track = Duration(minutes: 6);
    final window = RingWindow.whole(track);
    const a = Duration(minutes: 1), b = Duration(minutes: 2);

    test('A sits inside the ring and B outside, so both are in reach', () {
      final dial = DialGeometry(size);
      // The pennant is moved along the ring, towards the passage.
      final half = pennantSize(dial.ringWidth).width / 2;
      double radius(LoopEdge edge, Duration t) =>
          (gripCenter(edge, window, t, size) - dial.center).distance;
      expect(
        radius(LoopEdge.start, a),
        closeTo(
          math.sqrt(
            math.pow(dial.ringInner + dial.ringWidth * 0.25, 2) + half * half,
          ),
          1e-6,
        ),
      );
      expect(
        radius(LoopEdge.end, b),
        closeTo(
          math.sqrt(
            math.pow(dial.ringInner + dial.ringWidth * 0.75, 2) + half * half,
          ),
          1e-6,
        ),
      );
    });

    test('both pennants lean towards the passage', () {
      final dial = DialGeometry(size);
      final startAt = touchAngle(
        gripCenter(LoopEdge.start, window, a, size),
        size,
      );
      final endAt = touchAngle(gripCenter(LoopEdge.end, window, b, size), size);
      expect(startAt, greaterThan(window.angleOf(a)));
      expect(endAt, lessThan(window.angleOf(b)));
      expect(dial.ringWidth, greaterThan(0));
    });

    test('a touch on a pennant takes that flag, one far away takes none', () {
      final onA = gripCenter(LoopEdge.start, window, a, size);
      expect(gripAt(onA, size, window, start: a, end: b), LoopEdge.start);
      final onB = gripCenter(LoopEdge.end, window, b, size);
      expect(gripAt(onB, size, window, start: a, end: b), LoopEdge.end);
      expect(
        gripAt(const Offset(150, 20), size, window, start: a, end: b),
        // 12 o'clock: out of reach of both.
        isNull,
      );
      // The middle of the dial is nobody's.
      expect(
        gripAt(const Offset(150, 150), size, window, start: a, end: b),
        isNull,
      );
    });

    test('where a flag is not on the ring it cannot be taken there', () {
      final onA = gripCenter(LoopEdge.start, window, a, size);
      expect(gripAt(onA, size, window), isNull);
      expect(gripAt(onA, size, window, end: b), isNull);
    });

    test('of two flags at the same time, the nearer wins', () {
      final inner = gripCenter(LoopEdge.start, window, a, size);
      final outer = gripCenter(LoopEdge.end, window, a, size);
      expect(gripAt(inner, size, window, start: a, end: a), LoopEdge.start);
      expect(gripAt(outer, size, window, start: a, end: a), LoopEdge.end);
    });
  });

  group('the flags in the corners', () {
    test('sit on the lower diagonals, inside the square of the dial', () {
      for (final side in [200.0, 280.0, 380.0]) {
        final size = Size(side, side);
        final dial = DialGeometry(size);
        final a = holderCenter(LoopEdge.start, size);
        final b = holderCenter(LoopEdge.end, size);
        for (final c in [a, b]) {
          expect(c.dy, greaterThan(dial.center.dy));
          // The 48 dp target is inside the dial's square.
          expect(c.dx - gripReach, greaterThanOrEqualTo(-1e-9));
          expect(c.dx + gripReach, lessThanOrEqualTo(side + 1e-9));
          expect(c.dy + gripReach, lessThanOrEqualTo(side + 1e-9));
        }
        expect(a.dx, lessThan(dial.center.dx));
        expect(b.dx, greaterThan(dial.center.dx));
        expect(a.dy, b.dy);
        // From 280 dp up the target clears the ring by 4 dp.
        if (side >= 280) {
          expect(
            (a - dial.center).distance - gripReach,
            greaterThanOrEqualTo(dial.ringOuter + 4),
            reason: '$side dp',
          );
        }
      }
    });
  });

  group('the wave', () {
    final dial = DialGeometry(const Size(300, 300));

    test('has as many slices as there are peaks, up to 720', () {
      expect(RingWave.slicesFor(Duration.zero), 0);
      expect(RingWave.slicesFor(const Duration(milliseconds: 35)), 3);
      expect(RingWave.slicesFor(const Duration(minutes: 6)), 720);
    });

    test('stays inside the ring, swells with the height and is flat in '
        'silence', () {
      final loud = RingWave.shape(
        dial,
        Float32List.fromList(List.filled(8, 1)),
      );
      final quiet = RingWave.shape(
        dial,
        Float32List.fromList(List.filled(8, 0)),
      );
      expect(loud, isNotNull);
      expect(quiet, isNotNull);
      final l = loud!.getBounds(), q = quiet!.getBounds();
      // The slices of 8 are centred at 22.5°, 67.5°…: the widest point is at
      // 67.5° or 112.5°, whose sine is [k].
      final k = math.sin(math.pi * 0.375);
      // The loudest reaches 0.9 of the thickness from the inner edge.
      expect(
        l.right - dial.center.dx,
        closeTo(k * (dial.ringInner + dial.ringWidth * 0.9), 1),
      );
      expect(l.right - dial.center.dx, lessThan(dial.ringOuter));
      expect(l.width, greaterThan(q.width));
      // Silence is a thin line round the middle of the ring.
      final middle = dial.ringInner + dial.ringWidth / 2;
      expect(
        q.right - dial.center.dx,
        closeTo(k * (middle + dial.ringWidth * 0.01), 1),
      );
    });

    test('stops at the first slice not read', () {
      final heights = Float32List.fromList([
        1,
        1,
        1,
        double.nan,
        double.nan,
        double.nan,
      ]);
      final path = RingWave.shape(dial, heights)!;
      // Three of six slices: half a turn, the bounds are the right half.
      final b = path.getBounds();
      expect(b.left, greaterThanOrEqualTo(dial.center.dx));
      expect(RingWave.shape(dial, Float32List.fromList([double.nan])), isNull);
      expect(RingWave.shape(dial, Float32List(0)), isNull);
    });

    test('paints, whole or partly read, with or without a passage', () {
      final peaks = TrackPeaks();
      for (final passage in [
        null,
        (const Duration(seconds: 10), const Duration(seconds: 20)),
      ]) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = RingWave(
          peaks: peaks,
          window: RingWindow.whole(const Duration(minutes: 1)),
          color: const Color(0xFF888888),
          passage: passage,
          passageColor: const Color(0xFFCD7F32),
        );
        // Nothing read: nothing drawn, and no error.
        painter.paint(canvas, const Size(300, 300));
        peaks.add(
          Uint16List.fromList([
            for (var i = 0; i < 1500; i++) (i * 37) % 32000,
          ]),
        );
        painter.paint(canvas, const Size(300, 300));
        peaks.add(
          Uint16List.fromList([
            for (var i = 0; i < 4500; i++) (i * 91) % 32000,
          ]),
        );
        peaks.finish();
        painter.paint(canvas, const Size(300, 300));
        recorder.endRecording().dispose();
      }
    });
  });
}
