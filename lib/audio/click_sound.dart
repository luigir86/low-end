import 'dart:math' as math;
import 'dart:typed_data';

import '../features/metronome/subdivision.dart';
import '../features/metronome/time_signature.dart';
import 'in_steps.dart';

/// The metronome click, made in code: a short, dry woodblock-like tick, the
/// kind DAWs use, pitched in the middle so it cuts through without tiring
/// the ear. The first beat of the bar is a little higher, to hear the "one".
/// The clicks between the beats are the same tick, softer.
abstract final class ClickSound {
  /// The engine's rate (see engineSampleRate), so nothing is resampled.
  static const sampleRate = 48000;

  /// Pitch of the plain click and of the accented first beat, in Hz.
  static const plainHz = 800.0;
  static const accentHz = 1000.0;

  /// Pitch of the first pulse of each group, in 6/8 and the like.
  static const groupHz = 900.0;

  static const _length = Duration(milliseconds: 60);

  /// Level of the clicks between the beats, against a plain click.
  static const _skipLevel = 0.45;

  /// The clicks a bar is made of, made once: they never change.
  static final _plain = click(accent: false);
  static final _accent = click(accent: true);
  static final _group = click(accent: false, hz: groupHz);
  static final _skip = skip();

  /// One click, samples from -1 to 1.
  static Float64List click({required bool accent, double? hz}) {
    final f = hz ?? (accent ? accentHz : plainHz);
    final n = _length.inMicroseconds * sampleRate ~/ 1000000;
    final random = math.Random(accent ? 1 : 2);
    return Float64List.fromList([
      for (var i = 0; i < n; i++) _sample(i / sampleRate, f, random),
    ]);
  }

  static double _sample(double t, double f, math.Random random) {
    // Half a millisecond of attack, then a quick decay: a tick, not a beep.
    final envelope = (1 - math.exp(-t / 0.0005)) * math.exp(-t / 0.018);
    final body =
        math.sin(2 * math.pi * f * t) +
        // A faster-fading inharmonic partial gives the wooden colour.
        0.4 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-t / 0.008);
    // A touch of noise for the first two milliseconds: the strike.
    final strike = t < 0.002 ? (random.nextDouble() * 2 - 1) * 0.3 : 0.0;
    return 0.8 * envelope * (body / 1.4) + strike * (1 - t / 0.002);
  }

  /// The clicks of a [Subdivision] between the beats: a plain
  /// click, softer.
  static Float64List skip() {
    final tick = click(accent: false);
    for (var i = 0; i < tick.length; i++) {
      tick[i] *= _skipLevel;
    }
    return tick;
  }

  /// One whole bar at [bpm], a click at the start of each beat, as a WAV
  /// file: the audio engine loops it, so the beats stay exactly in time
  /// however busy the phone is. [subdivision] adds the softer clicks inside
  /// each beat, and only applies to bars counted in quarters; in eighths
  /// (6/8, 7/8) the bar is played plain. With [backbeat], in 2/4 and 4/4,
  /// the beats 1 and 3 are silent, with what is inside them: the clicks
  /// fall on 2 and 4 only.
  static Uint8List bar({
    required int bpm,
    TimeSignature signature = TimeSignature.fourFour,
    Subdivision subdivision = Subdivision.quarters,
    bool backbeat = false,
  }) {
    final beats = signature.beats;
    final beatLength = (sampleRate * 60 / bpm).round();
    final samples = Float64List(beatLength * beats);
    final inEighths = signature.denominator == 8;
    final inner = inEighths ? const <double>[] : subdivision.inner;
    final offBeats = backbeat && signature.hasBackbeat;
    void put(int at, Float64List note) {
      // A late note at a fast tempo stops at the end of the bar. Added to
      // what is there, so that a click never cuts the one before it short.
      final n = math.min(note.length, samples.length - at);
      for (var i = 0; i < n; i++) {
        samples[at + i] += note[i];
      }
    }

    for (var b = 0; b < beats; b++) {
      if (offBeats && b.isEven) continue;
      final tick = switch (signature.accent(b)) {
        0 => _accent,
        1 => _group,
        _ => _plain,
      };
      put(b * beatLength, tick);
      for (final fraction in inner) {
        put(b * beatLength + (beatLength * fraction).round(), _skip);
      }
    }
    return wav(samples);
  }

  /// Wraps mono samples from -1 to 1 into a 16-bit PCM WAV file.
  static Uint8List wav(Float64List samples) {
    final data = samples.length * 2;
    final bytes = ByteData(44 + data);
    void ascii(int at, String text) {
      for (var i = 0; i < text.length; i++) {
        bytes.setUint8(at + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + data, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // Size of this chunk.
    bytes.setUint16(20, 1, Endian.little); // PCM.
    bytes.setUint16(22, 1, Endian.little); // Mono.
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // Bytes per second.
    bytes.setUint16(32, 2, Endian.little); // Bytes per sample.
    bytes.setUint16(34, 16, Endian.little); // Bits per sample.
    ascii(36, 'data');
    bytes.setUint32(40, data, Endian.little);
    // Every phone is little-endian, as WAV is: the samples go straight into
    // the file, without a call per byte (a slow bar has 350 000 of them).
    final pcm = Endian.host == Endian.little
        ? bytes.buffer.asInt16List(44, samples.length)
        : null;
    for (var i = 0; i < samples.length; i++) {
      var v = samples[i];
      if (v > 1) {
        v = 1;
      } else if (v < -1) {
        v = -1;
      }
      final s = (v * 32767).round();
      if (pcm != null) {
        pcm[i] = s;
      } else {
        bytes.setInt16(44 + i * 2, s, Endian.little);
      }
    }
    return bytes.buffer.asUint8List();
  }

  /// Wraps two channels from -1 to 1 into a 16-bit stereo PCM WAV file,
  /// with a touch of triangular dither, so the quiet ends of the notes and
  /// the room fade into noise rather than into steps.
  static Uint8List stereoWav(Float32List left, Float32List right) {
    final out = StepResult<Uint8List>();
    runSteps(stereoWavSteps(left, right, out));
    return out.value;
  }

  /// [stereoWav] cut into small steps (see runInSlices).
  static Iterable<void> stereoWavSteps(
    Float32List left,
    Float32List right,
    StepResult<Uint8List> out,
  ) sync* {
    final frames = left.length;
    final data = frames * 4;
    final bytes = ByteData(44 + data);
    void ascii(int at, String text) {
      for (var i = 0; i < text.length; i++) {
        bytes.setUint8(at + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + data, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM.
    bytes.setUint16(22, 2, Endian.little); // Stereo.
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 4, Endian.little);
    bytes.setUint16(32, 4, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, data, Endian.little);
    final pcm = Endian.host == Endian.little
        ? bytes.buffer.asInt16List(44, frames * 2)
        : null;
    final random = math.Random(5);
    for (var from = 0; from < frames * 2; from += 32768) {
      _toPcm(
        left,
        right,
        bytes,
        pcm,
        random,
        from,
        math.min(frames * 2, from + 32768),
      );
      yield null;
    }
    out.value = bytes.buffer.asUint8List();
  }

  /// Samples [from] to [to] (not included) of [stereoWav], the channels
  /// taken in turn.
  static void _toPcm(
    Float32List left,
    Float32List right,
    ByteData bytes,
    Int16List? pcm,
    math.Random random,
    int from,
    int to,
  ) {
    for (var i = from; i < to; i++) {
      final v = (i.isEven ? left : right)[i >> 1];
      final dither = random.nextDouble() - random.nextDouble();
      // Not clamp(), which in a browser costs more than the rest.
      var s = (v * 32767 + dither).round();
      if (s > 32767) {
        s = 32767;
      } else if (s < -32768) {
        s = -32768;
      }
      if (pcm != null) {
        pcm[i] = s;
      } else {
        bytes.setInt16(44 + i * 2, s, Endian.little);
      }
    }
  }
}
