import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/click_sound.dart';
import 'package:low_end/audio/drone_sound.dart';
import 'package:low_end/audio/freeverb.dart';

// The sums made faster for the browser give the same sound as the plain
// ones they replaced, written here sample by sample as they were.
void main() {
  test('the held tone is the same wave as one sine per sample', () {
    for (final f in [
      [41.2, 61.7],
      [220.0, 275.0, 330.0],
    ]) {
      final gains = List.filled(f.length, 1.0);
      final fast = DroneSound.loop(f, gains);
      final plain = _plainTone(f, gains);
      expect(fast.length, plain.length);
      var worst = 0.0;
      for (var i = 0; i < fast.length; i++) {
        worst = math.max(worst, (fast[i] - plain[i]).abs());
      }
      expect(worst, lessThan(1e-9));
    }
  });

  test('the room is the same, sample for sample', () {
    final random = math.Random(1);
    Float64List noise() => Float64List.fromList([
      for (var i = 0; i < 70000; i++) random.nextDouble() - 0.5,
    ]);
    final dry = (left: noise(), right: noise());
    final fast = Freeverb.room().loop(dry);
    final plain = _plainRoom(dry);
    expect(fast.left, plain.left);
    expect(fast.right, plain.right);
  });
}

Float64List _plainTone(List<double> frequencies, List<double> gains) {
  const rate = DroneSound.sampleRate;
  final root = frequencies.first;
  final low = root < DroneSound.lowRootHz;
  final slope = low ? 0.6 : 1.4;
  final maxHarmonics = low ? 40 : 24;
  final rootCycles = 180 * math.max(1, (2 * root / 180).round());
  final length = (rootCycles * rate / root).round();
  final samples = Float64List(length);
  final random = math.Random(7);
  for (var v = 0; v < frequencies.length; v++) {
    final cycles = (frequencies[v] / root * rootCycles).round();
    final f = cycles * rate / length;
    for (var h = 1; h * f < 5000 && h <= maxHarmonics; h++) {
      final amp =
          gains[v] *
          math.pow(h, -slope) *
          (h == 2 || h == 3 ? 1.3 : 1.0) /
          frequencies.length;
      final breaths = 1 + random.nextInt(2);
      final breathPhase = random.nextDouble() * 2 * math.pi;
      final phase = random.nextDouble() * 2 * math.pi;
      final step = 2 * math.pi * h * cycles / length;
      final breathStep = 2 * math.pi * breaths / length;
      for (var i = 0; i < length; i++) {
        final breath = 1 + 0.25 * math.sin(breathStep * i + breathPhase);
        samples[i] += amp * breath * math.sin(step * i + phase);
      }
    }
  }
  var peak = 0.0;
  for (final s in samples) {
    peak = math.max(peak, s.abs());
  }
  for (var i = 0; i < length; i++) {
    samples[i] *= 0.85 / peak;
  }
  return samples;
}

({Float64List left, Float64List right}) _plainRoom(
  ({Float64List left, Float64List right}) dry,
) {
  const rate = ClickSound.sampleRate;
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
  const allPasses = [556, 441, 341, 225];
  const feedback = 0.4 * 0.28 + 0.7, damp = 0.5 * 0.4, wet = 0.14;
  final n = dry.left.length;
  final lead = math.min(n, rate * 2);
  final input = Float64List(lead + n);
  for (var i = 0; i < lead; i++) {
    final j = n - lead + i;
    input[i] = (dry.left[j] + dry.right[j]) / 2;
  }
  for (var i = 0; i < n; i++) {
    input[lead + i] = (dry.left[i] + dry.right[i]) / 2;
  }
  const scale = rate / 44100;
  const delay = 15000 * rate ~/ 1000000;
  final left = Float64List.fromList(dry.left);
  final right = Float64List.fromList(dry.right);
  for (final (channel, spread) in [(left, 0), (right, 23)]) {
    final comb = [
      for (final c in combs) Float64List(((c + spread) * scale).round()),
    ];
    final combAt = List.filled(comb.length, 0),
        store = List.filled(comb.length, 0.0);
    final pass = [
      for (final a in allPasses) Float64List(((a + spread) * scale).round()),
    ];
    final passAt = List.filled(pass.length, 0);
    for (var i = 0; i < input.length; i++) {
      final x = i >= delay ? input[i - delay] * 0.015 : 0.0;
      var y = 0.0;
      for (var c = 0; c < comb.length; c++) {
        final output = comb[c][combAt[c]];
        store[c] = output * (1 - damp) + store[c] * damp;
        comb[c][combAt[c]] = x + store[c] * feedback;
        if (++combAt[c] == comb[c].length) combAt[c] = 0;
        y += output;
      }
      for (var a = 0; a < pass.length; a++) {
        final buffered = pass[a][passAt[a]];
        pass[a][passAt[a]] = y + buffered * 0.5;
        if (++passAt[a] == pass[a].length) passAt[a] = 0;
        y = buffered - y;
      }
      if (i >= lead) channel[i - lead] += y * wet * 3;
    }
  }
  return (left: left, right: right);
}
