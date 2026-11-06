// The ring of the Player is the clock of the track (RF-PLY-03).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/features/player/player_dial.dart';
import 'package:low_end/features/player/ring_wave.dart';
import 'package:low_end/features/player/ring_window.dart';
import 'package:low_end/features/player/track_peaks.dart';
import 'package:low_end/widgets/dial.dart';

void main() {
  group('the ticks', () {
    test('every minute for a usual track', () {
      const six = Duration(minutes: 6, seconds: 3);
      expect(tickInterval(six), const Duration(minutes: 1));
      expect(tickTimes(six), [
        for (var m = 1; m <= 6; m++) Duration(minutes: m),
      ]);
    });

    test('every ten seconds under two minutes', () {
      const short = Duration(seconds: 65);
      expect(tickInterval(short), const Duration(seconds: 10));
      expect(tickTimes(short).length, 6);
      expect(
        tickInterval(const Duration(minutes: 2)),
        const Duration(minutes: 1),
      );
    });

    test('every five minutes over twenty', () {
      const long = Duration(minutes: 52);
      expect(tickInterval(long), const Duration(minutes: 5));
      expect(tickTimes(long).length, 10);
      expect(
        tickInterval(const Duration(minutes: 20)),
        const Duration(minutes: 1),
      );
    });

    test('no tick at the start, nor at the very end', () {
      expect(tickTimes(const Duration(minutes: 3)), [
        const Duration(minutes: 1),
        const Duration(minutes: 2),
      ]);
      expect(tickTimes(const Duration(seconds: 5)), isEmpty);
    });
  });

  group('angle and time', () {
    const six = Duration(minutes: 6);

    test('a whole turn is the track, clockwise from 12 o\'clock', () {
      expect(ringAngle(Duration.zero, six), 0);
      expect(
        ringAngle(const Duration(minutes: 3), six),
        closeTo(math.pi, 1e-9),
      );
      expect(
        ringAngle(const Duration(seconds: 90), six),
        closeTo(math.pi / 2, 1e-9),
      );
      expect(ringAngle(six, six), closeTo(2 * math.pi, 1e-9));
      // Beyond the end stays at the end.
      expect(
        ringAngle(const Duration(minutes: 9), six),
        closeTo(2 * math.pi, 1e-9),
      );
      expect(ringAngle(const Duration(seconds: 1), Duration.zero), 0);
    });

    test('the time at an angle is the other way round', () {
      for (final seconds in [0, 17, 90, 180, 359]) {
        final t = Duration(seconds: seconds);
        expect(timeAtAngle(ringAngle(t, six), six), t);
      }
    });

    test('a touch at 3 o\'clock is a quarter of the track', () {
      const size = Size(300, 300);
      // Right of the centre: a quarter turn.
      final angle = touchAngle(const Offset(280, 150), size);
      expect(angle, closeTo(math.pi / 2, 1e-9));
      expect(timeAtAngle(angle, six), const Duration(seconds: 90));
      // Above: the start. Left: three quarters. Below: half.
      expect(touchAngle(const Offset(150, 10), size), closeTo(0, 1e-9));
      expect(
        touchAngle(const Offset(20, 150), size),
        closeTo(3 * math.pi / 2, 1e-9),
      );
      expect(touchAngle(const Offset(150, 290), size), closeTo(math.pi, 1e-9));
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
