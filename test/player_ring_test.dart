// The ring of the Player is the clock of the track (RF-PLY-03).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/features/player/player_dial.dart';

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
}
