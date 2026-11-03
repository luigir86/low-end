import 'dart:math' as math;
import 'dart:typed_data';

import '../features/metronome/time_signature.dart';
import 'piano_sound.dart';

/// Recorded double bass notes, plucked, a few of them pitched up and down to
/// cover the range the walking line plays in, in three touches (a ghost, the
/// normal one and a firm one), each in a few takes, so that the same note
/// twice is never quite the same.
///
/// The recordings are Meatbass by Karoryfer Lecolds, a 1958 Otto Rubner
/// double bass played by Drogomir Smolken (CC0; see the About page), mono,
/// 48 kHz, prepared by tool/prepare_bass.dart.
class BassSamples {
  BassSamples(this.notes);

  /// The takes of each recorded note, by MIDI number, then by layer.
  final Map<int, Map<int, List<Int16List>>> notes;

  static const sampleRate = 48000;

  /// The notes recorded, a minor third apart, from D#1 to D#3.
  static const roots = [27, 30, 33, 36, 39, 42, 45, 48, 51];

  /// The touches kept, of the four recorded, and how many takes of each.
  static const ghost = 2, normal = 3, firm = 4;
  static const takes = {ghost: 2, normal: 4, firm: 4};

  /// How far, in cents, each take is from equal temperament at A = 440,
  /// measured by tool/prepare_bass.dart (the median of its second to
  /// fourth partials): by root, layer and take. The notes are put right as
  /// they are played.
  static const tuning = <int, Map<int, List<double>>>{
    27: {
      2: [-14.0, -12.4],
      3: [-9.1, -17.2, -11.8, -12.3],
      4: [-9.5, -18.7, -19.1, -10.5],
    },
    30: {
      2: [-4.4, -4.6],
      3: [0.4, 1.0, 2.9, 3.7],
      4: [7.8, 5.4, 7.5, 5.4],
    },
    33: {
      2: [0.2, -2.4],
      3: [2.1, 2.7, 1.9, 2.5],
      4: [2.5, 4.9, 6.0, 5.8],
    },
    36: {
      2: [-4.4, -7.5],
      3: [-4.9, -7.2, -8.1, -9.5],
      4: [-8.0, -10.5, -10.1, -10.4],
    },
    39: {
      2: [1.6, 0.6],
      3: [6.6, 7.3, 6.6, 8.3],
      4: [9.4, 10.6, 13.4, 12.7],
    },
    42: {
      2: [8.7, 7.4],
      3: [8.2, 4.4, 5.4, 5.4],
      4: [1.2, -0.2, -1.7, -1.0],
    },
    45: {
      2: [-7.1, -6.2],
      3: [-6.4, -7.6, -5.6, -5.5],
      4: [-11.0, -11.4, -10.5, -11.7],
    },
    48: {
      2: [-3.6, -3.6],
      3: [-1.0, 0.9, 0.5, 1.5],
      4: [0.2, -0.6, -1.2, -0.7],
    },
    51: {
      2: [-13.7, -14.2],
      3: [-13.3, -12.9, -12.2, -11.9],
      4: [-14.9, -14.8, -15.8, -17.5],
    },
  };

  static const _names = [
    'C', 'Cs', 'D', 'Ds', 'E', 'F', 'Fs', 'G', 'Gs', 'A', 'As', 'B', //
  ];

  /// The file of a take.
  static String assetOf(int root, int layer, int take) =>
      'assets/bass/${_names[root % 12]}${root ~/ 12 - 1}v${layer}t$take.flac';

  /// Every file there is: what the walking bass loads.
  static Iterable<(int, int, int)> get all sync* {
    for (final root in roots) {
      for (final MapEntry(key: layer, value: n) in takes.entries) {
        for (var t = 1; t <= n; t++) {
          yield (root, layer, t);
        }
      }
    }
  }

  /// The recording that plays [midi]: the nearest.
  static int rootFor(int midi) {
    var best = roots.first;
    for (final k in roots) {
      if ((k - midi).abs() < (best - midi).abs()) best = k;
    }
    return best;
  }
}

/// One note of the walking line: where it falls and how long it lasts, in
/// pulses of the bar (the metronome's clicks) from the start of the loop,
/// how hard it is plucked and which take of the recording plays it.
typedef BassNote = ({
  int midi,
  double at,
  double length,
  int layer,
  int take,
  double gain,
});

/// A chord of the piano's comping: its notes, where it falls and how long
/// it is held, in pulses from the start of the loop, and how loud.
typedef CompChord = ({List<int> notes, double at, double length, double gain});

/// The walking bass: a line of plucked notes, one a beat, under the
/// progression, as a jazz bassist plays it (in the manner of Paul Chambers:
/// even, full notes, the root on the "one", chord tones and half steps,
/// leading into the next chord), and the piano comping lightly above it.
///
/// The same chords in the same time signature always make the same line, so
/// that the loop sounds the same at every tempo and every time it starts.
abstract final class WalkingBass {
  /// The range of the line: E1 to D3, the low, round middle of the bass.
  static const low = 28, high = 50;

  /// The beats of the line in a bar, in pulses from its start: every pulse
  /// where the beat is a quarter note (or the whole bar in 1/1), every
  /// group where it is felt in eighths (two in 6/8, three in 7/8).
  static List<int> beatsOf(TimeSignature signature) {
    if (signature.denominator != 8) {
      return [for (var p = 0; p < signature.beats; p++) p];
    }
    final starts = <int>[];
    var at = 0;
    for (final g in signature.groups) {
      starts.add(at);
      at += g;
    }
    return starts;
  }

  /// The scale a bassist walks through on a chord with these [tones] (from
  /// the root, in semitones), and its third (the fourth of a sus4), fifth,
  /// sixth and seventh, from the root.
  static ({List<int> scale, int third, int fifth, int sixth, int seventh})
  scaleOf(Set<int> tones) {
    final third = tones.contains(3) ? 3 : (tones.contains(5) ? 5 : 4);
    final fifth = tones.contains(6) ? 6 : 7;
    final sixth = fifth == 6 ? 8 : 9;
    final seventh = tones.contains(10)
        ? 10
        : tones.contains(11)
        ? 11
        : tones.contains(9)
        ? 9
        : (third == 3 ? 10 : 11);
    return (
      scale: ({0, 2, third, 5, fifth, sixth, seventh}.toList()..sort()),
      third: third,
      fifth: fifth,
      sixth: sixth,
      seventh: seventh,
    );
  }

  /// The tones of [chord] (a piano chord, root first) from its root.
  static Set<int> _tones(PianoChord chord) => {
    0,
    for (final m in chord.skip(1)) (m - chord.first) % 12,
  };

  /// The line under [chords], one bar each, in [signature].
  static List<BassNote> line(List<PianoChord> chords, TimeSignature signature) {
    final random = math.Random(7);
    final beats = beatsOf(signature);
    final bar = signature.beats;
    final quarters = signature.denominator == 4;
    final notes = <BassNote>[];
    final lastTake = <(int, int), int>{};

    int take(int midi, int layer) {
      final key = (BassSamples.rootFor(midi), layer);
      final n = BassSamples.takes[layer]!;
      final before = lastTake[key];
      var t = random.nextInt(n) + 1;
      if (n > 1 && t == before) t = t % n + 1;
      lastTake[key] = t;
      return t;
    }

    void add(int midi, double at, double length, int layer, double gain) =>
        notes.add((
          midi: midi,
          at: at,
          length: length,
          layer: layer,
          take: take(midi, layer),
          gain: gain,
        ));

    var previous = 41; // F2: the middle of the range
    String? lastPattern;
    for (var b = 0; b < chords.length; b++) {
      final chord = chords[b];
      final next = chords[(b + 1) % chords.length];
      final root = chord.first % 12;
      final target = next.first % 12;
      final tones = _tones(chord);
      final (:scale, :third, :fifth, :sixth, :seventh) = scaleOf(tones);
      const step = 2;
      // What the beats between the "one" and the last beat do, from the
      // root: up or down the chord or the scale, in semitones.
      final patterns = <String, List<int>>{
        'arpeggio up': [third, fifth, seventh],
        'scale up': [step, third, 5],
        'scale down': [seventh - 12, sixth - 12, fifth - 12],
        'arpeggio down': [fifth - 12, third - 12, 0 - 12],
        'fifth, third': [fifth, third, step],
        'seventh down': [seventh - 12, fifth - 12, third - 12],
        if (third == 4) 'blues': [step, 3, 4],
        'half steps down': [-1, -2, -3],
      };
      final k = beats.length;
      final middle = math.max(0, k - 2);
      List<int>? best;
      String? bestPattern;
      var bestCost = double.infinity;
      for (final first in _octaves(root)) {
        for (final MapEntry(key: name, value: steps) in patterns.entries) {
          final mid = [for (var i = 0; i < middle; i++) first + steps[i % 3]];
          if (mid.any((m) => m < low || m > high)) continue;
          if (k == 1) {
            final c = (first - previous).abs() + random.nextDouble() * 2.5;
            if (c < bestCost) (bestCost, best, bestPattern) = (c, [first], '');
            continue;
          }
          for (final to in _octaves(target)) {
            final from = mid.isEmpty ? first : mid.last;
            for (final (approach, penalty) in [
              (to - 1, 0.0),
              (to + 1, 0.3),
              (to - 2, 1.0),
              (to + 2, 1.0),
              (to + 7, 1.0),
              (to - 5, 1.0),
            ]) {
              if (approach < low || approach > high) continue;
              if (approach == from || approach == to) continue;
              // A note of the scale, unless a half step from where it goes.
              if ((approach - to).abs() != 1 &&
                  !scale.contains((approach - chord.first) % 12)) {
                continue;
              }
              var c =
                  penalty +
                  0.6 * math.max(0, (approach - from).abs() - 2) +
                  0.15 * (first - previous).abs() +
                  0.3 * math.max(0, (to - approach).abs() - 2);
              final all = [first, ...mid];
              final centre = all.reduce((a, b) => a + b) / all.length;
              c += 0.12 * (centre - 38).abs();
              if (name == lastPattern) c += 3;
              c += random.nextDouble() * 2.5;
              if (c < bestCost) {
                (bestCost, best, bestPattern) = (c, [...all, approach], name);
              }
            }
          }
        }
      }
      final picked = best ?? [_octaves(root).first];
      lastPattern = bestPattern;
      final start = (b * bar).toDouble();
      double length(int i) =>
          ((i + 1 < k ? beats[i + 1] : bar) - beats[i]).toDouble();
      // A fill only now and then: mostly at the end of a four-bar phrase,
      // where the beat is a quarter note.
      final fill = quarters && k >= 2
          ? (b % 4 == 3
                ? (random.nextBool() ? 'enclosure' : 'skip')
                : (random.nextDouble() < 0.12 ? 'skip' : null))
          : null;
      for (var i = 0; i < picked.length; i++) {
        final at = start + beats[i];
        final firstBeat = i == 0;
        final layer = firstBeat || random.nextDouble() < 0.3
            ? BassSamples.firm
            : BassSamples.normal;
        final gain = firstBeat ? 1.02 : (i == 1 ? 1.0 : 0.98);
        final lastBeat = i == picked.length - 1 && picked.length > 1;
        if (lastBeat && fill == 'enclosure') {
          // Into the next chord from above and below, in triplets.
          final to = _octaves(target).reduce(
            (a, b) => (a - picked[i]).abs() <= (b - picked[i]).abs() ? a : b,
          );
          final above = scale.contains((to + 1 - chord.first) % 12)
              ? to + 2
              : to + 1;
          final below = to - 1;
          final triplet = length(i) / 3;
          add(_within(above), at, triplet, BassSamples.normal, 1.0);
          add(_within(below), at + triplet, triplet, BassSamples.ghost, 0.9);
          add(
            _within(above),
            at + 2 * triplet,
            triplet,
            BassSamples.ghost,
            0.92,
          );
        } else if (lastBeat && fill == 'skip') {
          // The note, and a ghost of it on the swung eighth after.
          add(picked[i], at, length(i) * 0.62, BassSamples.normal, 1.0);
          add(
            picked[i],
            at + length(i) * 2 / 3,
            length(i) / 3,
            BassSamples.ghost,
            0.78,
          );
        } else {
          add(picked[i], at, length(i), layer, gain);
        }
      }
      previous = picked.last;
    }
    return notes;
  }

  /// The piano's chords over the line: short and light, on the rhythms a
  /// jazz pianist keeps simple under a soloist (the "Charleston", a long
  /// chord on the one, the one and the three), a new one every bar, the
  /// Charleston again at the start of every four-bar phrase. The notes
  /// above the root only: the bass has it.
  static List<CompChord> comping(
    List<PianoChord> chords,
    TimeSignature signature,
  ) {
    final random = math.Random(23);
    final beats = beatsOf(signature);
    final k = beats.length;
    final bar = signature.beats;
    // In beats of the line, where each chord falls and how long it lasts.
    final rhythms = <String, List<(double, double)>>{
      if (k >= 2) 'charleston': [(0, 0.7), (1 + 2 / 3, 0.6)],
      'long': [(0, math.min(2.2, k * 0.9))],
      if (k >= 3) 'one and three': [(0, 1.2), (2, math.min(1.2, k - 2.0))],
    };
    double pulse(double beat) {
      final i = beat.floor().clamp(0, k - 1);
      final length = (i + 1 < k ? beats[i + 1] : bar) - beats[i];
      return beats[i] + (beat - i) * length;
    }

    final out = <CompChord>[];
    String? last;
    for (var b = 0; b < chords.length; b++) {
      final chord = chords[b];
      final String name;
      if (b % 4 == 0) {
        name = rhythms.containsKey('charleston') ? 'charleston' : 'long';
      } else {
        final names = [
          for (final n in rhythms.keys)
            if (n != last) n,
        ];
        name = names.isEmpty
            ? rhythms.keys.first
            : names[random.nextInt(names.length)];
      }
      last = name;
      final upper = [...chord.skip(1)];
      if (upper.length < 3) {
        upper.add(60 + (chord.first - 60) % 12);
      }
      upper.sort();
      final level = math.pow(10, (random.nextDouble() * 2 - 1) * 0.6 / 20);
      for (final (beat, length) in rhythms[name]!) {
        final at = b * bar + pulse(beat);
        final end = b * bar + pulse(math.min(beat + length, k.toDouble()));
        out.add((
          notes: upper,
          at: at,
          length: math.max(end - at, 0.25),
          gain: level * (beat % 1 == 0 ? 1.0 : 0.92),
        ));
      }
    }
    return out;
  }

  /// [pc] (a pitch class) in every octave of the range.
  static List<int> _octaves(int pc) => [
    for (var m = low; m <= high; m++)
      if (m % 12 == pc) m,
  ];

  static int _within(int m) => m < low ? m + 12 : (m > high ? m - 12 : m);
}
