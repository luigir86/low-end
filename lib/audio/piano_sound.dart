import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../features/metronome/time_signature.dart';
import 'audio_format.dart';
import 'click_sound.dart';
import 'freeverb.dart';
import 'in_steps.dart';
import 'walking_bass.dart';

/// How the piano plays a chord or a progression, one bar after another.
enum PianoStyle {
  /// A single note kept sounding: struck again before it dies away, each
  /// ringing into the next, with no beat to it.
  drone,

  /// The chord struck on the "one" and left to ring for the bar; in a bar
  /// too slow for it to last, struck again softly half way (or as often as
  /// it takes), so that the bar never ends in silence.
  bar,

  /// The chord struck again on every beat, firmest on the "one".
  beat,

  /// One note of the chord on every beat, going up and down it.
  arpeggio,

  /// A plucked double bass walking under the chords, a note a beat, and the
  /// piano comping lightly above it (see [WalkingBass]).
  walking,
}

/// A bar's worth of notes, as MIDI numbers (60 is middle C), root first.
typedef PianoChord = List<int>;

/// One recording: the two channels, 16-bit, as the microphones heard it.
class PianoTake {
  PianoTake(this.left, this.right) : assert(left.length == right.length);

  /// A mono take, both channels the same: for tests.
  factory PianoTake.mono(Float32List samples) {
    final s = Int16List.fromList([
      for (final v in samples) (v * 32767).round().clamp(-32768, 32767),
    ]);
    return PianoTake(s, s);
  }

  final Int16List left, right;

  int get length => left.length;

  /// The loudness of its first second, against which the layers of a note
  /// are compared.
  late final double rms = () {
    final n = math.min(length, PianoSamples.sampleRate);
    var e = 0.0;
    for (var i = 0; i < n; i++) {
      e += left[i] * left[i] + right[i] * right[i];
    }
    return n == 0 ? 0.0 : math.sqrt(e / (2 * n)) / 32768;
  }();
}

/// Recorded piano notes, a few of them, pitched up and down to cover the
/// range Harmony plays in, in three touches, with the sound of the
/// dampers falling back on the strings.
///
/// The recordings are the Salamander Grand Piano by Alexander Holm, a
/// Yamaha C5 (public domain since 2022; see the About page), in stereo at
/// 48 kHz, as they were made (see tool/prepare_piano.dart).
class PianoSamples {
  PianoSamples(
    this.notes, {
    this.releases = const {},
    this.cents = const {},
    this.gains = const {},
    this.bass,
  });

  /// The normal touch only, mono, for tests: [notes] by MIDI number.
  factory PianoSamples.mono(Map<int, Float32List> notes) => PianoSamples({
    for (final e in notes.entries) e.key: {normal: PianoTake.mono(e.value)},
  });

  /// The takes of each recorded note, by MIDI number and then by layer
  /// ([soft], [normal], [firm]): only the notes loaded, see PianoLibrary.
  final Map<int, Map<int, PianoTake>> notes;

  /// The dampers of each key, by MIDI number.
  final Map<int, PianoTake> releases;

  /// How far each recorded note is from equal temperament (see [tuning]).
  final Map<int, double> cents;

  /// The gain that brings each recorded note to a common level (see
  /// [levels]).
  final Map<int, double> gains;

  /// The double bass of the walking bass, when loaded.
  final BassSamples? bass;

  static const sampleRate = audioSampleRate;

  /// The notes recorded, a minor third apart, from C2 to C5: Harmony plays
  /// from C2 (the root doubled) to B4, so higher ones would never sound.
  static const roots = [36, 39, 42, 45, 48, 51, 54, 57, 60, 63, 66, 69, 72];

  /// The velocity layers kept, of the sixteen recorded: a soft touch, the
  /// normal one and a firm one (see tool/prepare_piano.dart).
  static const soft = 5, normal = 8, firm = 11;
  static const layers = [soft, normal, firm];

  /// The keys whose dampers are kept: the ones Harmony plays.
  static const releaseKeys = (low: 36, high: 71);

  /// How far, in cents, each recording is from equal temperament at
  /// A = 440, measured by tool/prepare_piano.dart (the mean of its first
  /// two partials): the piano was tuned by ear, flat in the bass. The
  /// notes are put right as they are played, so Harmony is exact against
  /// the reference A.
  static const tuning = <int, double>{
    36: -11.7, 39: -9.4, 42: -6.2, 45: -2.5, 48: -6.3, 51: -2.9, 54: -4.7, //
    57: -0.5, 60: -1.6, 63: 0.2, 66: -2.4, 69: 1.6, 72: 4.7,
  };

  /// The gain that brings each recording to the same loudness, measured by
  /// tool/prepare_piano.dart on the normal touch; the files keep the level
  /// they were recorded at, which packs smaller.
  static const levels = <int, double>{
    36: 1.977, 39: 1.608, 42: 1.422, 45: 2.026, 48: 2.014, 51: 1.892, //
    54: 2.315, 57: 2.747, 60: 1.979, 63: 2.718, 66: 2.551, 69: 2.505,
    72: 2.744,
  };

  static String _name(int midi) =>
      '${_names[midi % 12]}${midi ~/ 12 - 1}'.replaceAll('#', 's');

  static const _names = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
  ];

  /// The two files (left, right) of a recorded note in a layer.
  static (String, String) assetsOf(int root, int layer) => (
    'assets/piano/${_name(root)}v${layer}L.flac',
    'assets/piano/${_name(root)}v${layer}R.flac',
  );

  /// The two files (left, right) of the dampers of a key.
  static (String, String) releaseAssetsOf(int midi) =>
      ('assets/piano/rel${midi}L.flac', 'assets/piano/rel${midi}R.flac');

  /// The recording that plays [midi]: the nearest, of all of them, whether
  /// loaded or not.
  static int rootFor(int midi) {
    var best = roots.first;
    for (final k in roots) {
      if ((k - midi).abs() < (best - midi).abs()) best = k;
    }
    return best;
  }

  /// The recordings needed for [chords]: their notes and, a recording a
  /// minor third away covering three keys, the doubled roots too.
  static Set<int> rootsFor(Iterable<PianoChord> chords) => {
    for (final c in chords)
      for (final m in [...c, c.first - 12]) rootFor(m),
  };

  /// The recording nearest to [midi] among those loaded.
  int nearest(int midi) {
    var best = notes.keys.first;
    for (final k in notes.keys) {
      if ((k - midi).abs() < (best - midi).abs()) best = k;
    }
    return best;
  }
}

/// One stroke of a key, as the loop is written: where, how firm, how long
/// it is held, and whether the dampers are heard when it is let go.
class _Stroke {
  _Stroke(
    this.midi,
    this.gain,
    this.at,
    this.hold,
    this.layer,
    this.damp, {
    this.take = 0,
  });

  final int midi;
  final double gain;
  final int at;
  final int hold;
  final int layer;
  final bool damp;

  /// Which take of the double bass plays it (from 1), or 0 for the piano.
  final int take;

  bool get bass => take > 0;

  _Stroke copy({int? at, int? hold, bool? damp}) => _Stroke(
    midi,
    gain,
    at ?? this.at,
    hold ?? this.hold,
    layer,
    damp ?? this.damp,
    take: take,
  );
}

/// Two channels of sound, from -1 to 1.
typedef Stereo = ({Float32List left, Float32List right});

/// Renders the bars of a chord progression played on the piano as one
/// looping recording, the same length as the metronome's bar so that the
/// two stay together however long they run.
abstract final class PianoSound {
  /// Level of each note, to leave room for the others.
  static const _headroom = 0.42;

  /// Notes struck together up to which each keeps its full level; above,
  /// the chord is turned down as a whole (see [chordGain]).
  static const _fullChord = 4;

  /// The loudest the loop may get: a little under full scale.
  static const _ceiling = 0.97;

  /// The lowest note the root is doubled at, an octave down for weight (C2):
  /// below it the recordings would be pitched down too far to sound like a
  /// piano.
  static const _lowestDouble = 36;

  /// How long a note takes to die away once let go, a little longer in the
  /// bass, as the dampers take longer to stop the heavier strings.
  static const _release = Duration(milliseconds: 300);
  static const _bassRelease = Duration(milliseconds: 420);

  /// The dampers against the note they stop, as on the Salamander's own
  /// instrument definition.
  static const _damperLevel = 0.0141; // -37 dB

  /// How long, in seconds, a held single note is left before it is struck
  /// again: within the 10 s of the normal touch, whose last 1.5 s fade out.
  static const _droneRenew = 8.5;

  /// How long, in seconds, a chord is left before it is struck again,
  /// softly, so that a slow bar does not end in silence.
  static const _chordRenew = 8.0;

  /// Level of a chord struck again within the bar, against its first
  /// strike.
  static const _renewGain = 0.6;

  /// The notes of a chord above the root come one after another, low to
  /// high, as a hand plays them: each this much after the one below, more
  /// or less from one strike to the next (between the two), give or take
  /// [_spreadJitter]; the root stays on the beat.
  static const _spreadLow = 0.003, _spreadHigh = 0.008;
  static const _spreadJitter = 0.001;

  /// The level of the top note of a chord and of the ones between it and
  /// the root, against the root: the top one sings, the inner ones lie
  /// back, as under a pianist's hand.
  static const _topLevel = 0.95, _innerLevel = 0.74;

  /// How far the root an octave down comes before the chord, in seconds:
  /// the left hand a hair ahead.
  static const _bassLead = 0.005;

  /// A chord held for the bar is let go this long after the next one comes
  /// in, in seconds: the two touch for a moment, as when the pedal is
  /// changed just after the new chord.
  static const _pedalOverlap = 0.06;

  /// How much the chord held for the bar changes in level from one bar to
  /// the next, up to, in dB; and the level of every other bar against the
  /// first, so that the bars go strong and weak, as a phrase does.
  static const _barJitter = 1.0, _weakBar = 0.92;

  /// How far, in seconds, a chord held for the bar or a note of an
  /// arpeggio may fall from the beat, up to (a little less, mostly).
  static const _timeJitter = 0.006;

  /// In an arpeggio, the top note comes this much late, in seconds, as if
  /// leaned on, and the "one" a little less.
  static const _topLate = 0.012, _oneLate = 0.004;

  /// The longest an arpeggio's note is held, in seconds: it rings on to the
  /// end of the bar, as with half the pedal down, but not past the
  /// recordings.
  static const _arpeggioLongest = 6.0;

  /// How long past the end of the bar an arpeggio's notes are let go, in
  /// seconds: just into the next chord.
  static const _arpeggioOverlap = 0.04;

  /// The walking bass comes this much ahead of the beat, in seconds, give
  /// or take [_bassJitter]; its swung eighths [_swingLate] after where they
  /// would fall.
  static const _walkingLead = 0.004, _bassJitter = 0.0015;
  static const _swingLate = 0.008;

  /// A note of the walking bass rings this long into the next one, in
  /// seconds, and dies away over [_bassFade] once let go: the string stopped
  /// by the next pluck.
  static const _bassLegato = 0.03, _bassFade = 0.045;

  /// The level of the double bass, and of each note of the piano comping
  /// over it, against a piano note struck alone: the bass leads.
  static const _bassLevel = 2.0, _compLevel = 0.45;

  /// And differ in level by up to this much, in dB.
  static const _levelJitter = 0.5;

  /// The level of each note of a chord of [notes] struck together: full up
  /// to [_fullChord] notes, then lower, so that a fuller chord is not louder
  /// and its sum keeps clear of the top. A plain gain, which leaves the
  /// sound as it is, unlike softening the peaks, which would add partials
  /// and beat against the notes.
  @visibleForTesting
  static double chordGain(int notes) =>
      notes <= _fullChord ? 1 : math.sqrt(_fullChord / notes);

  /// Where, in samples from its start, a single note held through a bar of
  /// [barLength] samples is struck: as seldom as the recordings allow,
  /// evenly, wherever that falls in the bar (on a beat or not), so that the
  /// note has no beat to it; once a bar if the bar is not much longer than
  /// a recording rings.
  @visibleForTesting
  static List<int> droneStrikes(int barLength) {
    final limit = _droneRenew * ClickSound.sampleRate;
    final count = barLength <= limit * 1.25 ? 1 : (barLength / limit).ceil();
    return [for (var i = 0; i < count; i++) (i * barLength / count).round()];
  }

  /// The pulses, from [from] up to [to] (not included), on which a chord
  /// struck at [from] and held until [to] is struck again so that it never
  /// rings longer than the recordings last: as few as needed, as evenly as
  /// the pulses of [beat] samples allow, starting with [from].
  @visibleForTesting
  static List<int> chordStrikes(int from, int to, int beat) {
    final limit = _chordRenew * ClickSound.sampleRate;
    final span = to - from;
    for (var count = 1; count < span; count++) {
      final at = [for (var i = 0; i < count; i++) from + i * span ~/ count];
      var longest = 0;
      for (var i = 0; i < count; i++) {
        final end = i + 1 < count ? at[i + 1] : to;
        longest = math.max(longest, end - at[i]);
      }
      if (longest * beat <= limit) return at;
    }
    return [for (var p = from; p < to; p++) p];
  }

  /// The touch for a stroke at [gain]: firm for the accented "one", soft
  /// for the light strokes, normal otherwise.
  static int _layerFor(double gain) => gain >= 0.95
      ? PianoSamples.firm
      : gain < 0.8
      ? PianoSamples.soft
      : PianoSamples.normal;

  /// Every stroke of the loop, in order: what [loop] plays.
  static List<_Stroke> _strokes({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
  }) {
    final beat = pulseFrames(bpm);
    final barLength = beat * signature.beats;
    final strokes = <_Stroke>[];
    // The hand's small unevenness, the same at every turn of the loop.
    final random = math.Random(11);

    /// Between -1 and 1, mostly near 0: the sum of two even draws.
    double wobble() => random.nextDouble() + random.nextDouble() - 1;

    int seconds(double s) => (s * ClickSound.sampleRate).round();

    /// The chord, with its root again an octave down for the weight, struck
    /// at [at] at [gain] and held for [hold] samples; let go with the
    /// dampers heard if [damp].
    void strikeChord(
      PianoChord chord,
      double gain,
      int at,
      int hold,
      int layer, {
      required bool damp,
    }) {
      final doubled = chord[0] - 12 >= _lowestDouble;
      final level = gain * chordGain(chord.length + (doubled ? 1 : 0));
      final upper = [...chord.skip(1)]..sort();
      final spread =
          _spreadLow + random.nextDouble() * (_spreadHigh - _spreadLow);
      for (var i = 0; i < chord.length; i++) {
        var g = level;
        var offset = 0;
        if (i > 0) {
          final order = upper.indexOf(chord[i]) + 1;
          g *= order == upper.length ? _topLevel : _innerLevel;
          offset = seconds(
            spread * order + (random.nextDouble() * 2 - 1) * _spreadJitter,
          );
          final db = (random.nextDouble() * 2 - 1) * _levelJitter;
          g *= math.pow(10, db / 20);
        }
        strokes.add(
          _Stroke(chord[i], g, at + offset, hold - offset, layer, damp),
        );
      }
      if (doubled) {
        final lead = seconds(_bassLead);
        strokes.add(
          _Stroke(
            chord[0] - 12,
            level * 0.6,
            at - lead,
            hold + lead,
            layer,
            damp,
          ),
        );
      }
    }

    /// The chord struck on [pulse] and held until [until] (a pulse, or the
    /// end of the bar), struck again softly in between when that is longer
    /// than the recordings ring. The first strike comes [early] samples
    /// before the pulse (after, if negative); the last one is let go
    /// [overlap] samples after [until].
    void holdChord(
      PianoChord chord,
      double gain,
      int start,
      int pulse,
      int until, {
      required bool damp,
      required int layer,
      int early = 0,
      int overlap = 0,
    }) {
      final strikes = chordStrikes(pulse, until, beat);
      for (var i = 0; i < strikes.length; i++) {
        final end = i + 1 < strikes.length ? strikes[i + 1] : until;
        final last = i + 1 == strikes.length;
        final shift = i == 0 ? early : 0;
        strikeChord(
          chord,
          i == 0 ? gain : gain * _renewGain,
          start + strikes[i] * beat - shift,
          (end - strikes[i]) * beat + shift + (last ? overlap : 0),
          i == 0 ? layer : PianoSamples.soft,
          damp: damp && last,
        );
      }
    }

    if (style == PianoStyle.walking) {
      // The double bass, a hair ahead of the beat as it pushes the time,
      // each note ringing into the next unless it is meant short; the swung
      // eighths of its fills sit a touch late.
      final lead = seconds(_walkingLead);
      for (final n in WalkingBass.line(chords, signature)) {
        final at = (n.at * beat).round() - lead;
        final late = n.at % 1 > 0 ? seconds(_swingLate) : 0;
        final legato = n.length >= 1 && n.length == n.length.roundToDouble();
        strokes.add(
          _Stroke(
            n.midi,
            n.gain * _bassLevel,
            at + late + seconds(wobble() * _bassJitter),
            (n.length * beat).round() + (legato ? seconds(_bassLegato) : 0),
            n.layer,
            false,
            take: n.take,
          ),
        );
      }
      // The piano above it, light, its chords rolled a little.
      for (final c in WalkingBass.comping(chords, signature)) {
        final start = (c.at * beat).round() + seconds(wobble() * 0.003);
        for (final (k, m) in c.notes.indexed) {
          final top = k == c.notes.length - 1;
          final g = _compLevel * c.gain * (top ? 1.08 : 0.9);
          final offset = seconds(
            0.003 * k + (random.nextDouble() * 2 - 1) * _spreadJitter,
          );
          strokes.add(
            _Stroke(
              m,
              g,
              start + offset,
              (c.length * beat).round() - offset,
              c.gain >= 0.95 ? PianoSamples.normal : PianoSamples.soft,
              false,
            ),
          );
        }
      }
      return strokes;
    }

    // Where the arpeggio of the bar before stopped (see [_arpeggioRunsOn]).
    var arpeggioCount = 0;
    for (var bar = 0; bar < chords.length; bar++) {
      final chord = chords[bar];
      final start = bar * barLength;
      // The dampers are heard where the chord changes: a pianist holding
      // the same chord on does not lift the hands.
      final changes = !listEquals(chords[(bar + 1) % chords.length], chord);
      switch (style) {
        case PianoStyle.drone:
          // Struck as seldom as the recording allows, wherever that falls
          // in the bar, and not at all between: each strike rings into the
          // next one.
          final strikes = droneStrikes(barLength);
          final every = barLength ~/ strikes.length;
          for (final at in strikes) {
            const n = PianoSamples.normal;
            strokes.add(_Stroke(chord[0], 1, start + at, every * 2, n, false));
            if (chord[0] - 12 >= _lowestDouble) {
              strokes.add(
                _Stroke(chord[0] - 12, 0.6, start + at, every * 2, n, false),
              );
            }
          }
        case PianoStyle.bar:
          // A chord held for the bar: the normal touch, which rings long,
          // the soft one in the weak bars of the phrase; a little off the
          // beat, a little louder or softer from bar to bar, let go just
          // after the next one comes in.
          final gain =
              (bar.isOdd ? _weakBar : 1.0) *
              math.pow(10, wobble() * _barJitter / 20);
          holdChord(
            chord,
            gain,
            start,
            0,
            signature.beats,
            damp: changes,
            layer: gain > 0.9 ? PianoSamples.normal : PianoSamples.soft,
            early: seconds(wobble() * _timeJitter),
            overlap: seconds(_pedalOverlap),
          );
        case PianoStyle.beat:
          for (var pulse = 0; pulse < signature.beats; pulse++) {
            final accent = signature.accent(pulse);
            // In eighths, the beat is the group: 6/8 is two beats.
            final isBeat = signature.denominator != 8 || accent < 2;
            if (!isBeat) continue;
            final gain = accent == 0 ? 1.0 : (accent == 1 ? 0.85 : 0.72);
            final next = _nextStrike(signature, pulse);
            final lastOfBar = pulse + next >= signature.beats;
            holdChord(
              chord,
              gain,
              start,
              pulse,
              pulse + next,
              damp: changes && lastOfBar,
              layer: _layerFor(gain),
            );
          }
        case PianoStyle.walking:
          break; // above
        case PianoStyle.arpeggio:
          // The notes go up and down the chord one after another; in a bar
          // too short to hold them all, on from where the bar before left
          // off, so that it is not the root alone.
          final runsOn =
              bar > 0 &&
              _arpeggioRunsOn(signature, chord.length) &&
              listEquals(chords[bar - 1], chord);
          var count = runsOn ? arpeggioCount : 0;
          final tones = [
            for (var pulse = 0; pulse < signature.beats; pulse++)
              _arpeggioTone(signature, count++, chord.length),
          ];
          final top = tones.reduce(math.max);
          final end = start + barLength + seconds(_arpeggioOverlap);
          for (var pulse = 0; pulse < signature.beats; pulse++) {
            final tone = tones[pulse];
            // The shape of the hand: louder going up, the top note sung,
            // softer and with the soft touch coming down; the one firm but
            // not hit.
            final rising = pulse == 0 || tone > tones[pulse - 1];
            final (gain, layer) = pulse == 0
                ? (0.95, PianoSamples.normal)
                : tone == top
                ? (1.0, PianoSamples.normal)
                : rising
                ? (0.84, PianoSamples.normal)
                : (0.7, PianoSamples.soft);
            final db = (random.nextDouble() * 2 - 1) * _levelJitter * 1.6;
            final late =
                (tone == top && pulse > 0 ? _topLate : 0) +
                (pulse == 0 ? _oneLate : 0) +
                wobble() * _timeJitter;
            final at = start + pulse * beat + seconds(late);
            // A single note is quieter than a chord: lift it.
            strokes.add(
              _Stroke(
                chord[tone],
                gain * 1.6 * math.pow(10, db / 20),
                at,
                math.min(end - at, seconds(_arpeggioLongest)),
                layer,
                changes && pulse == signature.beats - 1,
              ),
            );
          }
          arpeggioCount = count;
      }
    }
    return strokes;
  }

  /// True when an arpeggio of [tones] notes goes on from one bar to the
  /// next: the bar has fewer beats than the chord has notes (1/1, 2/4, a
  /// seventh chord in 3/4), so that, starting over in each bar, it would
  /// never reach the top of the chord.
  static bool _arpeggioRunsOn(TimeSignature signature, int tones) =>
      !signature.grouped && tones > 1 && signature.beats < tones;

  /// The bars a loop of [chords] (one per bar) holds: [chords] themselves,
  /// except a single chord arpeggiated in a bar too short for it (see
  /// [_arpeggioRunsOn]), which is repeated for as many bars as the
  /// arpeggio takes to come round to its root again.
  static List<PianoChord> barsOf(
    List<PianoChord> chords,
    PianoStyle style,
    TimeSignature signature,
  ) {
    // A single chord walked over four bars, so that the line goes
    // somewhere before it comes round.
    if (style == PianoStyle.walking && chords.length == 1) {
      return List.filled(4, chords.single);
    }
    if (style != PianoStyle.arpeggio ||
        chords.length != 1 ||
        !_arpeggioRunsOn(signature, chords.single.length)) {
      return chords;
    }
    final cycle = 2 * chords.single.length - 2;
    final bars = cycle ~/ cycle.gcd(signature.beats);
    return List.filled(bars, chords.single);
  }

  /// The recording [s] between its samples [k1] and [k2], [f] of the way,
  /// through the curve that also passes [k0] and [k3].
  static double _cubic(Int16List s, int k0, int k1, int k2, int k3, double f) {
    final y0 = s[k0].toDouble(), y1 = s[k1].toDouble();
    final y2 = s[k2].toDouble(), y3 = s[k3].toDouble();
    return y1 +
        0.5 *
            f *
            (y2 -
                y0 +
                f *
                    (2 * y0 -
                        5 * y1 +
                        4 * y2 -
                        y3 +
                        f * (3 * (y1 - y2) + y3 - y0)));
  }

  /// Adds [stroke] to [out] (its two channels), whose first sample is the
  /// loop's sample [origin]; around the loop if [wrap], otherwise only what
  /// falls inside [out]. [a4] tunes the piano like the rest of the app.
  static void _play(
    PianoSamples samples,
    _Stroke stroke,
    Stereo out,
    double a4, {
    required int origin,
    required bool wrap,
  }) {
    if (stroke.bass) {
      _playBass(samples.bass, stroke, out, a4, origin: origin, wrap: wrap);
      return;
    }
    final rate = ClickSound.sampleRate;
    final length = out.left.length;
    final root = samples.nearest(stroke.midi);
    final takes = samples.notes[root]!;
    final normal = takes[PianoSamples.normal] ?? takes.values.first;
    // Source samples per output sample: the pitch change, the recording's
    // own tuning put right, and the difference of the two sample rates.
    final step =
        math.pow(2, (stroke.midi - root) / 12) *
        math.pow(2, -(samples.cents[root] ?? 0) / 1200) *
        a4 /
        440 *
        PianoSamples.sampleRate /
        rate;
    final release =
        (stroke.midi < 48 ? _bassRelease : _release).inMicroseconds *
        rate ~/
        1000000;
    // The touch asked for, if it rings long enough: the soft and the firm
    // ones last 4 s, the last of it fading.
    var take = takes[stroke.layer] ?? normal;
    final usable = take.length - PianoSamples.sampleRate;
    if (take != normal && (stroke.hold + release) * step > usable) {
      take = normal;
    }
    // The layers keep half their difference in level: the touch changes
    // the colour more than the loudness.
    final touch = take == normal || take.rms == 0
        ? 1.0
        : math.sqrt(normal.rms / take.rms);
    final gain =
        stroke.gain * touch * (samples.gains[root] ?? 1) * _headroom / 32768;
    final sounding = math.min(
      (take.length / step).floor(),
      stroke.hold + release,
    );
    // Only the part that lands in [out], when it does not wrap.
    var first = 0, last = sounding;
    if (!wrap) {
      first = math.max(0, origin - stroke.at);
      last = math.min(sounding, origin + length - stroke.at);
    }
    final l = take.left, r = take.right;
    final n = take.length;
    for (var i = first; i < last; i++) {
      final position = i * step;
      final k = position.floor();
      final f = position - k;
      // Plain comparisons and no closure: in a browser math.min and a
      // closure made per sample cost more than the sum itself.
      final k0 = k < 1 ? 0 : k - 1, k1 = k < n - 1 ? k : n - 1;
      final k2 = k + 1 < n - 1 ? k + 1 : n - 1;
      final k3 = k + 2 < n - 1 ? k + 2 : n - 1;

      // Let go: a smooth fall over the release once the hold is over.
      final fade = i < stroke.hold
          ? 1.0
          : 0.5 * (1 + math.cos(math.pi * (i - stroke.hold) / release));
      final g = gain * fade;
      final at = wrap ? (stroke.at + i) % length : stroke.at + i - origin;
      out.left[at] += _cubic(l, k0, k1, k2, k3, f) * g;
      out.right[at] += _cubic(r, k0, k1, k2, k3, f) * g;
    }
    // The dampers, where the note is let go.
    final dampers = samples.releases[stroke.midi];
    if (stroke.damp && dampers != null) {
      final g =
          stroke.gain *
          (samples.gains[root] ?? 1) *
          _headroom *
          _damperLevel /
          32768;
      final from = stroke.at + stroke.hold;
      for (var i = 0; i < dampers.length; i++) {
        var at = from + i;
        if (wrap) {
          at %= length;
        } else {
          at -= origin;
          if (at < 0) continue;
          if (at >= length) break;
        }
        out.left[at] += dampers.left[i] * g;
        out.right[at] += dampers.right[i] * g;
      }
    }
  }

  /// Adds a note of the double bass to [out], as [_play] does a piano
  /// note: in the middle, the same in both channels. Nothing without the
  /// recordings.
  static void _playBass(
    BassSamples? samples,
    _Stroke stroke,
    Stereo out,
    double a4, {
    required int origin,
    required bool wrap,
  }) {
    final root = BassSamples.rootFor(stroke.midi);
    final takes = samples?.notes[root]?[stroke.layer];
    if (takes == null || takes.isEmpty) return;
    final index = math.min(stroke.take, takes.length) - 1;
    final take = takes[index];
    final cents = BassSamples.tuning[root]?[stroke.layer]?[index] ?? 0;
    final step =
        math.pow(2, (stroke.midi - root) / 12) *
        math.pow(2, -cents / 1200) *
        a4 /
        440 *
        BassSamples.sampleRate /
        ClickSound.sampleRate;
    final release = (_bassFade * ClickSound.sampleRate).round();
    final length = out.left.length;
    final sounding = math.min(
      (take.length / step).floor() - 2,
      stroke.hold + release,
    );
    var first = 0, last = sounding;
    if (!wrap) {
      first = math.max(0, origin - stroke.at);
      last = math.min(sounding, origin + length - stroke.at);
    }
    final gain = stroke.gain * _headroom / 32768;
    for (var i = first; i < last; i++) {
      final position = i * step;
      final k = position.floor();
      final f = position - k;
      final v = take[k] + (take[k + 1] - take[k]) * f;
      final fade = i < stroke.hold
          ? 1.0
          : 0.5 * (1 + math.cos(math.pi * (i - stroke.hold) / release));
      final at = wrap ? (stroke.at + i) % length : stroke.at + i - origin;
      final s = v * gain * fade;
      out.left[at] += s;
      out.right[at] += s;
    }
  }

  /// The two channels of the loop, from -1 to 1, without the room (see
  /// [loopWav]), and the gain that kept it under the top. The bar keeps
  /// the metronome's length.
  static ({Stereo sound, double scale}) render({
    required PianoSamples samples,
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    double a4 = 440,
  }) {
    final out = StepResult<({Stereo sound, double scale})>();
    runSteps(
      renderSteps(
        samples: samples,
        chords: chords,
        style: style,
        bpm: bpm,
        signature: signature,
        a4: a4,
        out: out,
      ),
    );
    return out.value;
  }

  /// [render] cut into small steps, a note at a time (see runInSlices).
  static Iterable<void> renderSteps({
    required PianoSamples samples,
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required StepResult<({Stereo sound, double scale})> out,
    double a4 = 440,
  }) sync* {
    final bars = barsOf(chords, style, signature);
    final beat = pulseFrames(bpm);
    final length = beat * signature.beats * bars.length;
    final sound = (left: Float32List(length), right: Float32List(length));
    final strokes = _strokes(
      chords: bars,
      style: style,
      bpm: bpm,
      signature: signature,
    );
    for (final s in strokes) {
      // The loop wraps round, so the end of a ringing note carries over
      // into the start of the next turn.
      _play(samples, s, sound, a4, origin: 0, wrap: true);
      yield null;
    }
    // Chords and ringing notes pile up: where they would go past the top,
    // turn the whole loop down, evenly, rather than bend the peaks.
    var peak = 0.0;
    for (var i = 0; i < length; i++) {
      peak = math.max(
        peak,
        math.max(sound.left[i].abs(), sound.right[i].abs()),
      );
    }
    final scale = peak > _ceiling ? _ceiling / peak : 1.0;
    if (scale < 1) {
      for (var i = 0; i < length; i++) {
        sound.left[i] *= scale;
        sound.right[i] *= scale;
      }
    }
    out.value = (sound: sound, scale: scale);
  }

  /// The loop as one channel, the two averaged: what tests listen to.
  @visibleForTesting
  static Float64List loop({
    required PianoSamples samples,
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    double a4 = 440,
  }) {
    final s = render(
      samples: samples,
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
    ).sound;
    return Float64List.fromList([
      for (var i = 0; i < s.left.length; i++) (s.left[i] + s.right[i]) / 2,
    ]);
  }

  /// One loop of [chords] (one per bar) at [bpm] in [signature], in a
  /// small room, as a stereo WAV file, and the gain that kept it under the
  /// top (for [tailWav]).
  static ({Uint8List wav, double scale}) loopWav({
    required PianoSamples samples,
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    double a4 = 440,
  }) {
    final out = StepResult<({Uint8List wav, double scale})>();
    runSteps(
      loopWavSteps(
        samples: samples,
        chords: chords,
        style: style,
        bpm: bpm,
        signature: signature,
        a4: a4,
        out: out,
      ),
    );
    return out.value;
  }

  /// [loopWav] cut into small steps (see runInSlices): in a browser the
  /// loop is mixed ahead of the touch a slice at a time, the screen drawn
  /// in between.
  static Iterable<void> loopWavSteps({
    required PianoSamples samples,
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required StepResult<({Uint8List wav, double scale})> out,
    double a4 = 440,
  }) sync* {
    final r = StepResult<({Stereo sound, double scale})>();
    yield* renderSteps(
      samples: samples,
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
      out: r,
    );
    final sound = StepResult<Stereo>();
    yield* Freeverb.room().loopSteps(r.value.sound, sound);
    final wav = StepResult<Uint8List>();
    yield* ClickSound.stereoWavSteps(sound.value.left, sound.value.right, wav);
    out.value = (wav: wav.value, scale: r.value.scale);
  }

  /// How long the piano sounds on after it is let go: the release, the
  /// dampers and the room.
  static const tailLength = Duration(milliseconds: 1500);

  /// What the loop played as [loopWav] (at [scale]) sounds like from
  /// [position] (in samples into the loop) when the player lets go there:
  /// the notes then ringing held up to that moment, released, with the
  /// dampers and the room, and nothing struck after. Played in place of the
  /// loop from that very sample, it stops the piano as a pianist does,
  /// instead of cutting it.
  static Uint8List tailWav({
    required PianoSamples samples,
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required int position,
    required double scale,
    double a4 = 440,
  }) {
    final out = StepResult<Uint8List>();
    runSteps(
      tailWavSteps(
        samples: samples,
        chords: chords,
        style: style,
        bpm: bpm,
        signature: signature,
        position: position,
        scale: scale,
        a4: a4,
        out: out,
      ),
    );
    return out.value;
  }

  /// [tailWav] cut into small steps (see runInSlices): in a browser the
  /// tail is mixed a slice at a time, the screen drawn in between.
  static Iterable<void> tailWavSteps({
    required PianoSamples samples,
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required int position,
    required double scale,
    required StepResult<Uint8List> out,
    double a4 = 440,
  }) sync* {
    final rate = ClickSound.sampleRate;
    final bars = barsOf(chords, style, signature);
    final beat = pulseFrames(bpm);
    final length = beat * signature.beats * bars.length;
    // Enough before it for the room to be full, as it is in the loop.
    final before = rate * 2;
    final after = tailLength.inMicroseconds * rate ~/ 1000000;
    final dry = (
      left: Float32List(before + after),
      right: Float32List(before + after),
    );
    final origin = position - before;
    final strokes = _strokes(
      chords: bars,
      style: style,
      bpm: bpm,
      signature: signature,
    );
    // This turn of the loop and the one before, whose last notes may still
    // ring.
    for (final turn in [0, -length]) {
      for (final s in strokes) {
        final at = s.at + turn;
        if (at >= position) continue;
        // Let go at [position] if still held then, with the dampers.
        final held = at + s.hold > position;
        _play(
          samples,
          s.copy(
            at: at,
            hold: held ? position - at : s.hold,
            damp: held || s.damp,
          ),
          dry,
          a4,
          origin: origin,
          wrap: false,
        );
        yield null;
      }
    }
    for (var i = 0; i < dry.left.length; i++) {
      dry.left[i] *= scale;
      dry.right[i] *= scale;
    }
    final sound = StepResult<Stereo>();
    yield* Freeverb.room().fromSilenceSteps(dry, sound);
    final wav = StepResult<Uint8List>();
    yield* ClickSound.stereoWavSteps(
      Float32List.sublistView(sound.value.left, before),
      Float32List.sublistView(sound.value.right, before),
      wav,
    );
    out.value = wav.value;
  }

  /// Beats from [pulse] to the next strike of the chord in the bar, or to
  /// the end of the bar.
  static int _nextStrike(TimeSignature signature, int pulse) {
    var n = 1;
    while (pulse + n < signature.beats) {
      final next = pulse + n;
      if (signature.denominator != 8 || signature.accent(next) < 2) break;
      n++;
    }
    return n;
  }

  /// Which note of the chord (0 the root) the arpeggio plays on [pulse]:
  /// up and down the chord over the whole bar, or, where the bar is felt in
  /// groups (6/8), up from the root again in every group.
  static int _arpeggioTone(TimeSignature signature, int pulse, int tones) {
    if (signature.grouped) {
      var start = 0;
      for (final g in signature.groups) {
        if (pulse < start + g) return (pulse - start) % tones;
        start += g;
      }
    }
    if (tones < 2) return 0;
    final cycle = 2 * tones - 2;
    final i = pulse % cycle;
    return i < tones ? i : cycle - i;
  }
}
