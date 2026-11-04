import 'dart:math' as math;
import 'dart:typed_data';

import 'click_sound.dart';

/// The drone's voice, made in code: a warm, organ- or bowed-string-like
/// tone with a full set of harmonics that slowly breathe, instead of a bare
/// sine. The pitch itself never wavers (no vibrato, no detuned layers), so
/// it stays a true reference for intonation.
abstract final class DroneSound {
  static const sampleRate = ClickSound.sampleRate;

  /// Highest harmonic kept, in Hz: warmth without hiss.
  static const _brightness = 5000.0;

  /// Below this root, in Hz, the tone is made richer in harmonics, to be
  /// heard on a phone speaker (see [loop]); it is also where the drone warns
  /// that the speaker will hardly play it.
  static const lowRootHz = 120.0;

  /// Builds a seamless loop of about two seconds holding [frequencies]
  /// together (the first one is the root), each at its relative [gains], as
  /// samples from -1 to 1. Every voice and every slow movement completes a
  /// whole number of cycles in the loop, so it repeats without a click.
  static Float64List loop(List<double> frequencies, List<double> gains) {
    assert(frequencies.isNotEmpty && frequencies.length == gains.length);
    final root = frequencies.first;
    final low = root < lowRootHz;
    final slope = low ? 0.6 : 1.4;
    final maxHarmonics = low ? 40 : 24;
    // A number of root cycles that every chord ratio used (5/4, 6/5, 3/2,
    // 16/9) turns into whole cycles too: a multiple of 180.
    final rootCycles = 180 * math.max(1, (2 * root / 180).round());
    final length = (rootCycles * sampleRate / root).round();
    final samples = Float64List(length);
    final random = math.Random(7);
    for (var v = 0; v < frequencies.length; v++) {
      final cycles = (frequencies[v] / root * rootCycles).round();
      // The real frequency of this voice in the loop: off by far less than
      // a cent, the price of a seamless loop.
      final f = cycles * sampleRate / length;
      for (var h = 1; h * f < _brightness && h <= maxHarmonics; h++) {
        // Softly falling harmonics, the second and third a little forward:
        // the warm middle of a cello or a reed stop. For a low root the
        // upper harmonics stay strong, since a phone speaker plays them and
        // not the fundamental, and the ear rebuilds the pitch from them.
        final amp =
            gains[v] *
            math.pow(h, -slope) *
            (h == 2 || h == 3 ? 1.3 : 1.0) /
            frequencies.length;
        // Each harmonic swells and fades slowly on its own (one or two
        // times per loop), which makes the tone breathe.
        final breaths = 1 + random.nextInt(2);
        final breathPhase = random.nextDouble() * 2 * math.pi;
        final phase = random.nextDouble() * 2 * math.pi;
        final step = 2 * math.pi * h * cycles / length;
        final breathStep = 2 * math.pi * breaths / length;
        // The two sines turned on a step at a time (a rotation), instead of
        // a sine per sample: the same wave, many times faster in a browser,
        // where each sine is a call out to JavaScript.
        final c = math.cos(step), s = math.sin(step);
        final bc = math.cos(breathStep), bs = math.sin(breathStep);
        var x = math.cos(phase), y = math.sin(phase);
        var bx = math.cos(breathPhase), by = math.sin(breathPhase);
        for (var i = 0; i < length; i++) {
          samples[i] += amp * (1 + 0.25 * by) * y;
          final nx = x * c - y * s;
          y = y * c + x * s;
          x = nx;
          final nbx = bx * bc - by * bs;
          by = by * bc + bx * bs;
          bx = nbx;
        }
      }
    }
    // Loud enough, never clipping: the phone's volume does the rest.
    var peak = 0.0;
    for (final s in samples) {
      peak = math.max(peak, s.abs());
    }
    if (peak > 0) {
      for (var i = 0; i < length; i++) {
        samples[i] *= 0.85 / peak;
      }
    }
    return samples;
  }

  /// [loop] as a WAV file, ready for the audio engine.
  static Uint8List loopWav(List<double> frequencies, List<double> gains) =>
      ClickSound.wav(loop(frequencies, gains));
}
