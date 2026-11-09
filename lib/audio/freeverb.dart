import 'dart:math' as math;
import 'dart:typed_data';

import 'click_sound.dart';
import 'in_steps.dart';
import 'piano_sound.dart' show Stereo;

/// A small room around the piano: Freeverb, by Jezar at Dreampoint (public
/// domain), the reverb of many a free synth. The Salamander was recorded
/// with the microphones close to the strings, dry; a little of a room
/// makes it sound like a piano in a room, not inside one.
class Freeverb {
  Freeverb({
    required double room,
    required double damp,
    required this.wet,
    required this.preDelay,
  }) : _feedback = room * 0.28 + 0.7,
       _damp = damp * 0.4;

  /// The room of Harmony: small, a little soft at the top, the reflections
  /// starting 15 ms after the note, so its attack stays clear.
  factory Freeverb.room() => Freeverb(
    room: 0.4,
    damp: 0.5,
    wet: 0.14,
    preDelay: const Duration(milliseconds: 15),
  );

  final double wet;
  final Duration preDelay;
  final double _feedback, _damp;

  // The original tuning, in samples at 44.1 kHz, and the spread between
  // the left and the right channel.
  static const _combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
  static const _allPasses = [556, 441, 341, 225];
  static const _spread = 23;
  static const _inputGain = 0.015;

  /// [dry] with the room added, as a loop: the room's sound at the end of
  /// it carries on into its start, as when it plays round and round.
  Stereo loop(Stereo dry) {
    final out = StepResult<Stereo>();
    runSteps(loopSteps(dry, out));
    return out.value;
  }

  /// [loop] cut into small steps (see runInSlices).
  Iterable<void> loopSteps(Stereo dry, StepResult<Stereo> out) sync* {
    final n = dry.left.length;
    // Run over the end of the loop first, so the room is already full of
    // it when the loop starts.
    final lead = math.min(n, ClickSound.sampleRate * 2);
    final input = Float32List(lead + n);
    for (var i = 0; i < lead; i++) {
      final j = n - lead + i;
      input[i] = (dry.left[j] + dry.right[j]) / 2;
    }
    for (var i = 0; i < n; i++) {
      input[lead + i] = (dry.left[i] + dry.right[i]) / 2;
    }
    yield null;
    yield* _mix(dry, input, lead, out);
  }

  /// [dry] with the room added, from silence.
  Stereo run(Stereo dry) {
    final out = StepResult<Stereo>();
    runSteps(fromSilenceSteps(dry, out));
    return out.value;
  }

  /// [run] cut into small steps (see runInSlices).
  Iterable<void> fromSilenceSteps(Stereo dry, StepResult<Stereo> out) sync* {
    final n = dry.left.length;
    final input = Float32List(n);
    for (var i = 0; i < n; i++) {
      input[i] = (dry.left[i] + dry.right[i]) / 2;
    }
    yield null;
    yield* _mix(dry, input, 0, out);
  }

  /// Samples a step of [_mix] filters at a time.
  static const _chunk = 16384;

  /// The dry sound plus the room made from [input], whose first [lead]
  /// samples only fill the room, into [out].
  ///
  /// Each filter runs over the whole sound in turn, a chunk at a time, in a
  /// tight loop of its own: the same sums in the same order as sample by
  /// sample through all of them, and several times faster in a browser.
  Iterable<void> _mix(
    Stereo dry,
    Float32List input,
    int lead,
    StepResult<Stereo> out,
  ) sync* {
    final n = dry.left.length;
    const scale = ClickSound.sampleRate / 44100;
    final delay = preDelay.inMicroseconds * ClickSound.sampleRate ~/ 1000000;
    final left = Float32List.fromList(dry.left);
    final right = Float32List.fromList(dry.right);
    final m = input.length;
    // The input, delayed and scaled, the same for both channels.
    final x = Float32List(m);
    for (var i = delay; i < m; i++) {
      x[i] = input[i - delay] * _inputGain;
    }
    final y = Float32List(m);
    for (final (channel, spread) in [(left, 0), (right, _spread)]) {
      y.fillRange(0, m, 0.0);
      for (final c in _combs) {
        final comb = _Comb(((c + spread) * scale).round(), _feedback, _damp);
        for (var from = 0; from < m; from += _chunk) {
          comb.run(x, y, from, math.min(m, from + _chunk));
          yield null;
        }
      }
      for (final a in _allPasses) {
        final allPass = _AllPass(((a + spread) * scale).round());
        for (var from = 0; from < m; from += _chunk) {
          allPass.run(y, from, math.min(m, from + _chunk));
          yield null;
        }
      }
      for (var i = lead; i < m; i++) {
        channel[i - lead] += y[i] * wet * 3;
      }
      yield null;
    }
    assert(left.length == n);
    out.value = (left: left, right: right);
  }
}

/// A feedback comb filter with a damped loop: the room's echoes, each one a
/// little duller than the last.
class _Comb {
  _Comb(int size, this._feedback, this._damp) : _buffer = Float64List(size);

  final Float64List _buffer;
  final double _feedback, _damp;
  var _index = 0;
  var _store = 0.0;

  /// Adds what it gives for [x] from [from] to [to] (not included) to [y].
  void run(Float32List x, Float32List y, int from, int to) {
    final buffer = _buffer, size = buffer.length;
    final feedback = _feedback, damp = _damp;
    var index = _index, store = _store;
    for (var i = from; i < to; i++) {
      final output = buffer[index];
      store = output * (1 - damp) + store * damp;
      buffer[index] = x[i] + store * feedback;
      if (++index == size) index = 0;
      y[i] += output;
    }
    _index = index;
    _store = store;
  }
}

/// An all-pass filter: it smears the echoes into a smooth tail.
class _AllPass {
  _AllPass(int size) : _buffer = Float64List(size);

  final Float64List _buffer;
  var _index = 0;

  /// Runs [y] through it in place, from [from] to [to] (not included).
  void run(Float32List y, int from, int to) {
    final buffer = _buffer, size = buffer.length;
    var index = _index;
    for (var i = from; i < to; i++) {
      final buffered = buffer[index];
      buffer[index] = y[i] + buffered * 0.5;
      if (++index == size) index = 0;
      y[i] = buffered - y[i];
    }
    _index = index;
  }
}
