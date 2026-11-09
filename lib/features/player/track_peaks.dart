import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// The loudness of a track over time, as the strongest sample of each 10 ms:
/// what the ring of the Player draws as its wave (RF-PLY-15). It fills up as
/// the file is read, so a screen draws what has arrived and asks again when
/// [version] grows.
class TrackPeaks extends ChangeNotifier {
  /// With [fullScale] the heights are measured against the loudest sample
  /// there can be, not the loudest arrived so far: a take being recorded,
  /// whose wave must not change size as it grows, and stays small when the
  /// microphone hears little.
  TrackPeaks({this.fullScale = false});

  final bool fullScale;

  /// Every value covers this much of the track.
  static const frame = Duration(milliseconds: 10);

  /// How far below the strongest peak the wave goes before it is drawn flat.
  static const rangeDb = 48.0;

  /// The largest value of a peak: 16-bit samples.
  static const maxValue = 32767;

  var _data = Uint16List(1024);
  var _length = 0;
  var _strongest = 0;
  var _version = 0;
  var _complete = false;
  var _failed = false;

  /// Frames arrived so far.
  int get length => _length;

  /// True once the whole track has been read.
  bool get complete => _complete;

  /// True when the track could not be read (or is too long to try in a web
  /// page): there is no wave, and nothing is said.
  bool get failed => _failed;

  /// Grows at every [add], so that a painter keeps what it drew while it
  /// has not changed.
  int get version => _version;

  /// Adds the peaks read after those already here (0..[maxValue], the
  /// strongest sample of those 10 ms, of any channel).
  void add(Uint16List chunk) {
    if (_complete || _failed || chunk.isEmpty) return;
    final needed = _length + chunk.length;
    if (needed > _data.length) {
      var size = _data.length;
      while (size < needed) {
        size *= 2;
      }
      _data = Uint16List(size)..setRange(0, _length, _data);
    }
    _data.setRange(_length, needed, chunk);
    for (final peak in chunk) {
      if (peak > _strongest) _strongest = peak;
    }
    _length = needed;
    _version++;
    notifyListeners();
  }

  /// The whole track has been read.
  void finish() {
    if (_complete || _failed) return;
    _complete = true;
    _version++;
    notifyListeners();
  }

  /// The track cannot be read: what arrived stays, nothing more comes.
  void fail() {
    if (_complete || _failed) return;
    _failed = true;
    _version++;
    notifyListeners();
  }

  /// The heights, 0 to 1, of [count] equal slices of the track between
  /// [from] and [to]: for each, the strongest peak in it, in decibels
  /// against the strongest peak arrived so far, over [rangeDb] (0 dB is 1,
  /// [rangeDb] below or less is 0). NaN for a slice not read yet.
  Float32List heights(Duration from, Duration to, int count) {
    final out = Float32List(count);
    if (count == 0) return out;
    final unit = frame.inMicroseconds;
    final first = from.inMicroseconds / unit;
    final span = (to - from).inMicroseconds / unit;
    for (var i = 0; i < count; i++) {
      final a = (first + span * i / count).floor();
      final b = math.max(a + 1, (first + span * (i + 1) / count).floor());
      if (a >= _length) {
        out[i] = double.nan;
        continue;
      }
      var peak = 0;
      for (var k = math.max(a, 0); k < math.min(b, _length); k++) {
        if (_data[k] > peak) peak = _data[k];
      }
      out[i] = _height(peak);
    }
    return out;
  }

  double _height(int peak) {
    final top = fullScale ? maxValue : _strongest;
    if (peak <= 0 || top <= 0) return 0;
    final db = 20 * math.log(peak / top) / math.ln10;
    return (1 + db / rangeDb).clamp(0.0, 1.0);
  }
}
