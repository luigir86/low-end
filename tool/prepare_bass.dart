// Prepares the double bass recordings the app ships for the walking bass
// (see lib/audio/bass_sound.dart) from Meatbass by Karoryfer Lecolds, a
// 1958 Otto Rubner double bass played by Drogomir Smolken (CC0), as
// published at https://github.com/sfzinstruments/karoryfer.meatbass
// (Samples/pizz, 44.1 kHz 24-bit mono WAV).
//
// 1. Convert the files needed to 48 kHz, keeping 24 bits, e.g. with ffmpeg:
//      ffmpeg -i pizz/c2_vl3_rr1.wav -af aresample=resampler=soxr:precision=28
//        -ar 48000 -c:a pcm_s24le wav/c2_vl3_rr1.wav
//    (the notes of [_roots], in the layers and takes of [_takes]).
// 2. dart run tool/prepare_bass.dart wav out
// 3. Encode every WAV in out to FLAC at the highest compression, e.g.
//      ffmpeg -i out/C2v3t1.wav -compression_level 12 assets/bass/C2v3t1.flac
//
// It prints how far each take is from equal temperament, for
// BassSamples.tuning. The files are written at a common level, each take
// of a layer as loud as the others, the layers keeping their difference.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _rate = 48000;

/// The notes kept, a minor third apart, from D#1 to D#3 (the files' own
/// names, which are the pitches they sound): the range the walking line
/// plays in, E1 to D3.
const _roots = {
  'eb1': 27, 'gb1': 30, 'a1': 33, 'c2': 36, 'eb2': 39, 'gb2': 42, 'a2': 45, //
  'c3': 48, 'eb3': 51,
};

/// The layers kept (of four) and how many takes of each (of four): the
/// ghost notes need fewer, being short and soft.
const _takes = {2: 2, 3: 4, 4: 4};

/// How long a take is kept, in seconds, and how much of its end fades out:
/// a quarter note at the slowest tempo, the plucked string dying away.
const _seconds = 2.0, _fade = 0.5;

/// The loudness of the middle layer, the one the line is mostly played
/// with, over its first 0.4 s.
const _level = 0.12;

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: dart run tool/prepare_bass.dart <in> <out>');
    exit(64);
  }
  final out = Directory(args[1])..createSync(recursive: true);
  stdout.writeln('BassSamples.tuning (cents from equal temperament):');
  for (final MapEntry(key: name, value: midi) in _roots.entries) {
    final layers = <int, List<Float64List>>{
      for (final MapEntry(key: v, value: n) in _takes.entries)
        v: [
          for (var t = 1; t <= n; t++)
            _cut(_readWav(File('${args[0]}/${name}_vl${v}_rr$t.wav'))),
        ],
    };
    // One gain for the note, set by the middle layer; within a layer the
    // takes are brought most of the way to the same level.
    final middle = layers[3]!.map(_rms).toList();
    final mean = middle.reduce((a, b) => a + b) / middle.length;
    final gain = _level / mean;
    final cents = <int, List<double>>{};
    for (final MapEntry(key: v, value: takes) in layers.entries) {
      final levels = takes.map(_rms).toList();
      final layerMean = levels.reduce((a, b) => a + b) / levels.length;
      cents[v] = [];
      for (final (i, x) in takes.indexed) {
        final even = math.pow(layerMean / levels[i], 0.7).toDouble();
        _write(
          File('${out.path}/${_file(midi)}v${v}t${i + 1}.wav'),
          x,
          gain * even,
        );
        cents[v]!.add(_cents(x, midi));
      }
    }
    stdout.writeln(
      '    $midi: {${[for (final MapEntry(key: v, value: c) in cents.entries) '$v: [${c.map((x) => x.toStringAsFixed(1)).join(', ')}]'].join(', ')}},',
    );
  }
}

String _file(int midi) {
  const names = ['C', 'Cs', 'D', 'Ds', 'E', 'F', 'Fs', 'G', 'Gs', 'A', 'As'];
  return '${midi % 12 == 11 ? 'B' : names[midi % 12]}${midi ~/ 12 - 1}';
}

/// A 48 kHz mono 16- or 24-bit WAV file, from -1 to 1.
Float64List _readWav(File file) {
  final bytes = file.readAsBytesSync();
  final view = ByteData.sublistView(bytes);
  var at = 12;
  var bits = 24;
  int? dataAt, dataLength;
  while (at + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(at, at + 4));
    final size = view.getUint32(at + 4, Endian.little);
    if (id == 'fmt ') {
      final channels = view.getUint16(at + 10, Endian.little);
      final rate = view.getUint32(at + 12, Endian.little);
      bits = view.getUint16(at + 22, Endian.little);
      if (rate != _rate) throw StateError('${file.path}: $rate Hz');
      if (channels != 1) throw StateError('${file.path}: $channels channels');
    } else if (id == 'data') {
      dataAt = at + 8;
      dataLength = size;
      break;
    }
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  if (dataAt == null) throw StateError('${file.path}: no data');
  final width = bits ~/ 8;
  final frames = dataLength! ~/ width;
  final out = Float64List(frames);
  for (var i = 0; i < frames; i++) {
    final p = dataAt + i * width;
    out[i] = width == 3
        ? (bytes[p] | bytes[p + 1] << 8 | bytes[p + 2] << 16).toSigned(24) /
              8388608
        : view.getInt16(p, Endian.little) / 32768;
  }
  return out;
}

/// From 3 ms before the pluck (the first sample 40 dB under the peak),
/// [_seconds] long at most, the last [_fade] seconds faded out.
Float64List _cut(Float64List x) {
  var peak = 0.0;
  for (final v in x) {
    peak = math.max(peak, v.abs());
  }
  var start = 0;
  final floor = peak * math.pow(10, -40 / 20);
  while (start < x.length && x[start].abs() < floor) {
    start++;
  }
  start = math.max(0, start - (_rate * 0.003).round());
  final length = math.min(x.length - start, (_rate * _seconds).round());
  final f = math.min(length, (_rate * _fade).round());
  return Float64List.fromList([
    for (var i = 0; i < length; i++)
      x[start + i] *
          (i < length - f
              ? 1
              : 0.5 * (1 + math.cos(math.pi * (i - length + f) / f))),
  ]);
}

/// The loudness of the first 0.4 s, the body of the note.
double _rms(Float64List x) {
  final n = math.min(x.length, (_rate * 0.4).round());
  var e = 0.0;
  for (var i = 0; i < n; i++) {
    e += x[i] * x[i];
  }
  return math.sqrt(e / n);
}

/// How far, in cents, the take of [midi] is from equal temperament at
/// A = 440: the median of its second to fourth partials (the fundamental
/// of the lowest notes is weak), each found by the strongest frequency
/// within 60 cents of where it should be, over 1.2 s from the pluck.
double _cents(Float64List x, int midi) {
  final f0 = 440 * math.pow(2, (midi - 69) / 12).toDouble();
  final from = (_rate * 0.1).round();
  final n = math.min(x.length - from, (_rate * 1.2).round());
  final window = Float64List(n);
  for (var i = 0; i < n; i++) {
    window[i] = x[from + i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / n));
  }
  double partial(double f) {
    double power(double cents) {
      final w = 2 * math.pi * f * math.pow(2, cents / 1200) / _rate;
      var re = 0.0, im = 0.0;
      for (var i = 0; i < n; i++) {
        re += window[i] * math.cos(w * i);
        im += window[i] * math.sin(w * i);
      }
      return re * re + im * im;
    }

    var best = 0.0, bestPower = -1.0;
    for (var c = -60.0; c <= 60; c += 2) {
      final p = power(c);
      if (p > bestPower) (best, bestPower) = (c, p);
    }
    final centre = best;
    for (var c = centre - 2; c <= centre + 2; c += 0.1) {
      final p = power(c);
      if (p > bestPower) (best, bestPower) = (c, p);
    }
    return best;
  }

  final c = [for (var k = 2; k <= 4; k++) partial(f0 * k)]..sort();
  return c[1];
}

/// Writes [x] at [gain] as a mono 16-bit WAV file. No dither: the noise of
/// the room is far above the last bit.
void _write(File file, Float64List x, double gain) {
  final data = x.length * 2;
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
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, _rate, Endian.little);
  bytes.setUint32(28, _rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, data, Endian.little);
  var clipped = 0;
  for (var i = 0; i < x.length; i++) {
    final v = (x[i] * gain * 32767).round();
    if (v.abs() > 32767) clipped++;
    bytes.setInt16(44 + i * 2, v.clamp(-32768, 32767), Endian.little);
  }
  if (clipped > 0) stderr.writeln('${file.path}: $clipped samples clipped');
  file.writeAsBytesSync(bytes.buffer.asUint8List());
}
