// The loudness of the track that the ring draws as a wave (RF-PLY-15).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/features/player/track_peaks.dart';

Uint16List _peaks(List<int> values) => Uint16List.fromList(values);

void main() {
  group('arriving in pieces', () {
    test('pieces add up, in order, and the version grows', () {
      final peaks = TrackPeaks();
      var told = 0;
      peaks.addListener(() => told++);
      expect(peaks.length, 0);
      final first = peaks.version;
      peaks.add(_peaks([1, 2, 3]));
      peaks.add(_peaks([4, 5]));
      expect(peaks.length, 5);
      expect(peaks.version, greaterThan(first));
      expect(told, 2);
      expect(peaks.complete, isFalse);
      peaks.finish();
      expect(peaks.complete, isTrue);
      expect(told, 3);
    });

    test('a long track grows the store without losing a value', () {
      final peaks = TrackPeaks();
      // 20 minutes: 120,000 values, in pieces of 25.
      for (var i = 0; i < 4800; i++) {
        peaks.add(_peaks([for (var k = 0; k < 25; k++) (i * 25 + k) % 30000]));
      }
      expect(peaks.length, 120000);
      final h = peaks.heights(Duration.zero, const Duration(minutes: 20), 1);
      expect(h.single, 1.0);
    });

    test('an empty piece changes nothing; nothing comes after the end', () {
      final peaks = TrackPeaks();
      var told = 0;
      peaks.addListener(() => told++);
      peaks.add(Uint16List(0));
      expect(told, 0);
      peaks.add(_peaks([9]));
      peaks.finish();
      peaks.add(_peaks([9, 9]));
      peaks.fail();
      expect(peaks.length, 1);
      expect(peaks.complete, isTrue);
      expect(peaks.failed, isFalse);
    });

    test('a track that cannot be read keeps what came and says no more', () {
      final peaks = TrackPeaks();
      peaks.add(_peaks([100, 200]));
      peaks.fail();
      expect(peaks.failed, isTrue);
      expect(peaks.complete, isFalse);
      peaks.add(_peaks([1]));
      peaks.finish();
      expect(peaks.length, 2);
    });
  });

  group('heights', () {
    test('each slice takes the strongest peak in it', () {
      final peaks = TrackPeaks()
        ..add(_peaks([0, 1000, 500, 32000, 0, 0, 100, 0]));
      // Four slices of 20 ms: 1000, 32000, 0, 100.
      final h = peaks.heights(
        Duration.zero,
        const Duration(milliseconds: 80),
        4,
      );
      expect(h.length, 4);
      // The strongest is 0 dB, so 1.
      expect(h[1], 1.0);
      expect(h[0], lessThan(h[1]));
      expect(h[2], 0.0);
      // 100 is 20·log10(100/32000) = −50 dB: below the 48 dB range.
      expect(h[3], 0.0);
    });

    test('the scale is decibels over 48 dB', () {
      // −24 dB is half the height: 32000 × 0.0631 ≈ 2019.
      final peaks = TrackPeaks()..add(_peaks([32000, 2019]));
      final h = peaks.heights(
        Duration.zero,
        const Duration(milliseconds: 20),
        2,
      );
      expect(h[0], 1.0);
      expect(h[1], closeTo(0.5, 0.01));
    });

    test('a slice that is not read yet is NaN, a part read counts', () {
      final peaks = TrackPeaks()..add(_peaks([100, 200, 300, 400, 500, 600]));
      final h = peaks.heights(
        Duration.zero,
        const Duration(milliseconds: 60),
        3,
      );
      expect(h.every((v) => !v.isNaN), isTrue);
      final more = peaks.heights(
        Duration.zero,
        const Duration(milliseconds: 100),
        5,
      );
      expect(more[0].isNaN, isFalse);
      expect(more[2].isNaN, isFalse);
      expect(more[3].isNaN, isTrue);
      expect(more[4].isNaN, isTrue);
    });

    test('a window of the track shows only its part', () {
      final peaks = TrackPeaks()
        ..add(_peaks([32000, 0, 0, 0, 16000, 16000, 0, 0]));
      final h = peaks.heights(
        const Duration(milliseconds: 40),
        const Duration(milliseconds: 60),
        2,
      );
      expect(h[0], closeTo(0.875, 0.01)); // −6 dB
      expect(h[1], closeTo(0.875, 0.01));
    });

    test('silence is flat, and no peaks at all too', () {
      final quiet = TrackPeaks()..add(_peaks([0, 0, 0, 0]));
      expect(
        quiet.heights(Duration.zero, const Duration(milliseconds: 40), 2),
        [0.0, 0.0],
      );
      final none = TrackPeaks();
      expect(
        none
            .heights(Duration.zero, const Duration(seconds: 1), 3)
            .every((v) => v.isNaN),
        isTrue,
      );
      expect(
        none.heights(Duration.zero, const Duration(seconds: 1), 0),
        isEmpty,
      );
    });

    test('more slices than peaks gives each slice the peak under it', () {
      final peaks = TrackPeaks()..add(_peaks([32000, 3200]));
      final h = peaks.heights(
        Duration.zero,
        const Duration(milliseconds: 20),
        8,
      );
      expect(h.take(4).every((v) => v == 1.0), isTrue);
      expect(h.skip(4).every((v) => v < 1.0 && v > 0.5), isTrue);
    });
  });
}
