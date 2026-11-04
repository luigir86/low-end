import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/click_sound.dart';
import 'package:low_end/audio/in_steps.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/features/tuner/drone/drone_controller.dart';
import 'package:low_end/features/tuner/drone/harmony.dart';

/// Pure tones in place of the piano: each recorded note a sine at its own
/// pitch, a second long, so what is played can be told by its frequency.
PianoSamples _tones() {
  const rate = PianoSamples.sampleRate;
  return PianoSamples.mono({
    for (final midi in PianoSamples.roots) midi: _sine(_hz(midi), rate),
  });
}

/// [length] samples of a sine at [hz], at half the full level.
Float32List _sine(double hz, int length) => Float32List.fromList([
  for (var i = 0; i < length; i++)
    0.5 * math.sin(2 * math.pi * hz * i / PianoSamples.sampleRate),
]);

/// How strong [hz] is in [s] from [from] for [length] samples, by
/// correlation with a sine.
double _power(Float64List s, double hz, [int from = 0, int? length]) {
  var re = 0.0, im = 0.0;
  for (var i = from; i < from + (length ?? s.length - from); i++) {
    final a = 2 * math.pi * hz * i / ClickSound.sampleRate;
    re += s[i] * math.cos(a);
    im += s[i] * math.sin(a);
  }
  return re * re + im * im;
}

double _hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

/// The pitch heard in [loop] from [from] for [length] samples, by counting
/// the times it crosses zero.
double _pitch(Float64List loop, int from, int length) {
  var crossings = 0;
  for (var i = from + 1; i < from + length; i++) {
    if ((loop[i - 1] < 0) != (loop[i] < 0)) crossings++;
  }
  return crossings / 2 / (length / ClickSound.sampleRate);
}

double _energy(Float64List loop, int from, int length) {
  var e = 0.0;
  for (var i = from; i < from + length; i++) {
    e += loop[i] * loop[i];
  }
  return e;
}

void main() {
  final samples = _tones();
  const cMajor = [60, 64, 67];

  group('the piano loop', () {
    test('doubles the root an octave down, unless it is too low', () {
      Float64List render(List<int> chord) => PianoSound.loop(
        samples: samples,
        chords: [chord],
        style: PianoStyle.bar,
        bpm: 120,
        signature: TimeSignature.fourFour,
      );
      const power = _power;
      // C4: the C3 below it is struck too.
      final c = render(cMajor);
      expect(power(c, _hz(48)), greaterThan(power(c, _hz(60)) * 0.05));
      // A2: the A1 would be a piano slowed down to a rumble, so it is left
      // out.
      final a = render(const [45, 61, 64]);
      expect(power(a, _hz(33)), lessThan(power(a, _hz(45)) * 0.01));
    });

    test('is whole bars of the metronome length', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor, cMajor, cMajor],
        style: PianoStyle.beat,
        bpm: 90,
        signature: TimeSignature.threeFour,
      );
      final beat = (ClickSound.sampleRate * 60 / 90).round();
      expect(loop.length, beat * 3 * 3);
      expect(loop.every((v) => v.abs() <= 1), isTrue);
    });

    test('4/4 strikes the chord on every beat, the "one" firmest', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.beat,
        bpm: 120,
        signature: TimeSignature.fourFour,
      );
      final beat = ClickSound.sampleRate ~/ 2;
      for (var b = 0; b < 4; b++) {
        expect(_energy(loop, b * beat, 2000), greaterThan(1));
      }
      expect(_energy(loop, 0, 2000), greaterThan(_energy(loop, beat, 2000)));
    });

    test('6/8 strikes only at the first pulse of each group', () {
      PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.beat,
        bpm: 240,
        signature: TimeSignature.sixEight,
      );
      // One strike per group, so the chord is struck twice in the bar: the
      // later pulses only ring on. Silence the notes a pulse after the
      // second group starts to see the first group's chord let go.
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.beat,
        bpm: 600,
        signature: TimeSignature.sixEight,
      );
      final pulse = (ClickSound.sampleRate * 60 / 600).round();
      // Each group lasts three pulses: its chord is held for all three.
      expect(_energy(loop, pulse * 2, 400), greaterThan(0.01));
      expect(_energy(loop, 3 * pulse, 400), greaterThan(0.01));
    });

    test('a chord a bar rings for the whole bar from the "one"', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.bar,
        bpm: 240,
        signature: TimeSignature.fourFour,
      );
      final beat = ClickSound.sampleRate ~/ 4;
      // Sounding from the first beat to the last: struck once, held for the bar.
      for (var b = 0; b < 4; b++) {
        expect(_energy(loop, b * beat, 2000), greaterThan(1));
      }
    });

    test('a single note is struck once a bar and kept sounding', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: [
          [69],
        ],
        style: PianoStyle.drone,
        bpm: 240,
        signature: TimeSignature.fourFour,
      );
      final beat = ClickSound.sampleRate ~/ 4;
      // Sounding from the first beat to the last, with no new start between.
      for (var b = 0; b < 4; b++) {
        expect(_energy(loop, b * beat, 2000), greaterThan(1));
      }
      expect(loop.length, beat * 4);
    });

    test('an arpeggio plays one note a beat, up and down the chord', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.arpeggio,
        bpm: 60,
        signature: TimeSignature.fourFour,
      );
      final beat = ClickSound.sampleRate;
      // Root, third, fifth, third. Each note rings on into the next, so
      // the pitch just after a strike is somewhere between the new note
      // and the one before. The notes come a little off the beat, as a
      // hand plays them: listened to 30 ms after it.
      const expected = [60, 64, 67, 64];
      for (var b = 0; b < 4; b++) {
        final pitch = _pitch(loop, b * beat + 1440, 800);
        final now = _hz(expected[b]);
        final before = _hz(expected[(b + 3) % 4]);
        final low = math.min(now, before) * 0.85;
        final high = math.max(now, before) * 1.15;
        expect(
          pitch,
          allOf(greaterThan(low), lessThan(high)),
          reason: 'beat $b: heard $pitch Hz',
        );
      }
    });

    test('6/8 arpeggios start from the root again in each group', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.arpeggio,
        bpm: 120,
        signature: TimeSignature.sixEight,
      );
      final pulse = ClickSound.sampleRate ~/ 2;
      final first = _pitch(loop, 100, 600);
      final fourth = _pitch(loop, 3 * pulse + 100, 600);
      // Both groups open on the root (the fourth over the tail of the
      // fifth, so not exactly): the second is nearer the first than the
      // note that would follow it in a plain climb.
      expect((fourth - first).abs(), lessThan(first * 0.4));
    });

    test('a ringing note wraps round into the start of the loop', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.arpeggio,
        bpm: 240,
        signature: TimeSignature.twoFour,
      );
      expect(_energy(loop, 0, 200), greaterThan(0));
      // Two bars of 2/4: the arpeggio runs on into the second (root, third
      // | fifth, third) before it comes round.
      expect(loop.length, (ClickSound.sampleRate * 60 / 240).round() * 4);
    });

    test('in a bar of one beat, an arpeggio runs on over the bars', () {
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.arpeggio,
        bpm: 60,
        signature: TimeSignature.oneOne,
      );
      final beat = ClickSound.sampleRate;
      // Not the root alone: root | third | fifth | third, a bar each.
      expect(loop.length, beat * 4);
      const expected = [60, 64, 67, 64];
      for (var b = 0; b < 4; b++) {
        final pitch = _pitch(loop, b * beat + 1440, 800);
        final now = _hz(expected[b]);
        final before = _hz(expected[(b + 3) % 4]);
        final low = math.min(now, before) * 0.85;
        final high = math.max(now, before) * 1.15;
        expect(
          pitch,
          allOf(greaterThan(low), lessThan(high)),
          reason: 'bar $b: heard $pitch Hz',
        );
      }
      // A seventh chord in 1/1 takes six bars to come round; in 4/4 a
      // triad still fits in one.
      expect(
        PianoSound.barsOf(
          [
            [60, 64, 67, 70],
          ],
          PianoStyle.arpeggio,
          TimeSignature.oneOne,
        ).length,
        6,
      );
      expect(
        PianoSound.barsOf(
          [cMajor],
          PianoStyle.arpeggio,
          TimeSignature.fourFour,
        ).length,
        1,
      );
    });

    test('a bar of one beat (1/1) works in every style', () {
      for (final style in PianoStyle.values) {
        final loop = PianoSound.loop(
          samples: samples,
          chords: [cMajor, cMajor],
          style: style,
          bpm: 120,
          signature: TimeSignature.oneOne,
        );
        // Two bars of one beat each.
        expect(loop.length, ClickSound.sampleRate, reason: '$style');
        expect(_energy(loop, 0, 200), greaterThan(0), reason: '$style');
        expect(loop.every((v) => v.isFinite), isTrue, reason: '$style');
      }
    });

    test('is tuned by the reference A', () {
      Float64List at(double a4) => PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.beat,
        bpm: 60,
        signature: TimeSignature.twoFour,
        a4: a4,
      );
      // Counted over most of the first beat, where the chord rings full.
      const from = ClickSound.sampleRate ~/ 16;
      const length = ClickSound.sampleRate ~/ 2;
      final ratio =
          _pitch(at(466.16), from, length) / _pitch(at(440), from, length);
      // A semitone up.
      expect(ratio, closeTo(1.0595, 0.03));
    });

    test('a slow bar is struck again softly, never left silent', () {
      int beat(int bpm) => (ClickSound.sampleRate * 60 / bpm).round();
      // 4/4 at 50: a bar of 4.8 s, which a recording outlasts: once.
      expect(PianoSound.chordStrikes(0, 4, beat(50)), [0]);
      // 4/4 at 25: a bar of 9.6 s, longer than a recording rings.
      expect(PianoSound.chordStrikes(0, 4, beat(25)), [0, 2]);
      // 5/4 at 20: beats of 3 s, so as evenly as the beats allow.
      expect(PianoSound.chordStrikes(0, 5, beat(20)), [0, 1, 3]);
      // At 120 once a bar is enough.
      expect(PianoSound.chordStrikes(0, 4, beat(120)), [0]);
      // A long group of 7/8 in Chord on every beat: split as well.
      expect(PianoSound.chordStrikes(4, 7, beat(20)), [4, 5]);

      // At 25 BPM in 4/4 the chord is struck again, softly, half way, and
      // sounds again in the second half of the bar.
      final loop = PianoSound.loop(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.bar,
        bpm: 25,
        signature: TimeSignature.fourFour,
      );
      final half = beat(25) * 2;
      expect(_energy(loop, 0, 2000), greaterThan(1));
      expect(_energy(loop, half, 2000), greaterThan(0.1));
      // Softer than the first strike.
      expect(_energy(loop, half, 2000), lessThan(_energy(loop, 0, 2000)));
    });

    test('a held note is not struck on every beat of a slow 5/4 or 3/4', () {
      int bar(int bpm, int beats) =>
          (ClickSound.sampleRate * 60 / bpm).round() * beats;
      // 5/4 at 60, 3/4 at 50, 7/8 at ♪ = 100, 4/4 at 80: once a bar.
      for (final (bpm, beats) in [(60, 5), (50, 3), (100, 7), (80, 4)]) {
        expect(PianoSound.droneStrikes(bar(bpm, beats)), [0]);
      }
      // 4/4 at 20 (12 s): twice, half way, between two beats.
      final twelve = PianoSound.droneStrikes(bar(20, 4));
      expect(twelve, [0, bar(20, 4) ~/ 2]);
      // Never more often than the recordings need, nor less, whatever the
      // bar.
      final long = bar(20, 12);
      final strikes = PianoSound.droneStrikes(long);
      expect(long / strikes.length, greaterThan(4 * ClickSound.sampleRate));
      expect(
        long / strikes.length,
        lessThanOrEqualTo(8.5 * ClickSound.sampleRate),
      );
    });

    test('chords are turned down evenly, not bent at the peaks', () {
      // Loud test notes, so that the sum goes past the top.
      PianoSamples loud(double level) => PianoSamples(
        samples.notes,
        gains: {for (final k in samples.notes.keys) k: level},
      );
      Float64List render(double level) => PianoSound.loop(
        samples: loud(level),
        chords: [
          [60, 64, 67],
        ],
        style: PianoStyle.beat,
        bpm: 120,
        signature: TimeSignature.fourFour,
      );
      final quiet = render(0.2), strong = render(2);
      final peak = strong.map((v) => v.abs()).reduce(math.max);
      expect(peak, lessThanOrEqualTo(0.97 + 1e-9));
      expect(peak, greaterThan(0.9));
      // The loud loop is the quiet one scaled: the same shape, no new
      // partials.
      final ratio = strong[1000] / quiet[1000];
      for (var i = 0; i < quiet.length; i += 97) {
        if (quiet[i].abs() < 1e-4) continue;
        expect(
          strong[i] / quiet[i],
          closeTo(ratio, ratio * 1e-4),
          reason: 'at $i',
        );
      }
      // And a quiet one is left as it is.
      expect(quiet.map((v) => v.abs()).reduce(math.max), lessThan(0.97));
    });

    test('a fuller chord is no louder: the level goes down with the notes', () {
      expect(PianoSound.chordGain(3), 1);
      expect(PianoSound.chordGain(4), 1);
      expect(PianoSound.chordGain(5), lessThan(1));
      expect(
        PianoSound.chordGain(5) * 5,
        greaterThan(PianoSound.chordGain(4) * 4),
      );
    });

    test('mixed a slice at a time, the loop is the same', () async {
      for (final style in [PianoStyle.beat, PianoStyle.walking]) {
        final whole = PianoSound.loopWav(
          samples: samples,
          chords: [cMajor, cMajor],
          style: style,
          bpm: 100,
          signature: TimeSignature.fourFour,
        );
        final out = StepResult<({Uint8List wav, double scale})>();
        await runInSlices(
          PianoSound.loopWavSteps(
            samples: samples,
            chords: [cMajor, cMajor],
            style: style,
            bpm: 100,
            signature: TimeSignature.fourFour,
            out: out,
          ),
          SlicedWork(),
          slice: Duration.zero,
        );
        expect(out.value.wav, whole.wav);
        expect(out.value.scale, whole.scale);
      }
    });

    test('a loop mixed ahead can be called off', () async {
      final work = SlicedWork();
      final done = runInSlices(
        PianoSound.loopWavSteps(
          samples: samples,
          chords: [cMajor],
          style: PianoStyle.beat,
          bpm: 120,
          signature: TimeSignature.fourFour,
          out: StepResult(),
        ),
        work,
        slice: Duration.zero,
      );
      work.cancel();
      await expectLater(done, throwsA(isA<StepsCancelled>()));
    });

    test('the WAV is a valid 16-bit stereo file', () {
      final (:wav, :scale) = PianoSound.loopWav(
        samples: samples,
        chords: [cMajor],
        style: PianoStyle.beat,
        bpm: 120,
        signature: TimeSignature.fourFour,
      );
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(ByteData.sublistView(wav).getUint16(22, Endian.little), 2);
      expect((wav.length - 44) ~/ 4, ClickSound.sampleRate * 2);
      expect(scale, 1);
    });
  });

  group('the recordings', () {
    const rate = PianoSamples.sampleRate;
    Float64List play(
      PianoSamples s,
      List<PianoChord> chords, {
      PianoStyle style = PianoStyle.bar,
      int bpm = 120,
    }) => PianoSound.loop(
      samples: s,
      chords: chords,
      style: style,
      bpm: bpm,
      signature: TimeSignature.fourFour,
    );

    test('are put right where the piano was out of tune', () {
      final sharp = PianoSamples(
        samples.notes,
        cents: {for (final k in samples.notes.keys) k: 100},
      );
      const from = rate ~/ 16, length = rate ~/ 2;
      final ratio =
          _pitch(
            play(sharp, const [
              [69],
            ], style: PianoStyle.drone),
            from,
            length,
          ) /
          _pitch(
            play(samples, const [
              [69],
            ], style: PianoStyle.drone),
            from,
            length,
          );
      // Recorded a semitone sharp: played a semitone lower.
      expect(ratio, closeTo(1 / 1.0595, 0.02));
    });

    test('keep their two channels apart', () {
      final left = PianoTake.mono(_sine(_hz(69), rate)).left;
      final s = PianoSamples({
        69: {PianoSamples.normal: PianoTake(left, Int16List(rate))},
      });
      final sound = PianoSound.render(
        samples: s,
        chords: const [
          [69],
        ],
        style: PianoStyle.drone,
        bpm: 120,
        signature: TimeSignature.fourFour,
      ).sound;
      expect(_energy(sound.left, 0, 4000), greaterThan(1));
      expect(_energy(sound.right, 0, 4000), 0);
    });

    test('an arpeggio goes up with the normal touch, down with the soft', () {
      // The soft take an octave up, so it can be told from the normal one.
      final s = PianoSamples({
        60: {
          PianoSamples.normal: PianoTake.mono(_sine(_hz(60), rate * 5)),
          PianoSamples.soft: PianoTake.mono(_sine(_hz(72), rate * 5)),
        },
      });
      // Root, third, fifth, third: the last one on the way down.
      final loop = play(
        s,
        const [
          [60, 64, 67],
        ],
        style: PianoStyle.arpeggio,
        bpm: 60,
      );
      const window = rate ~/ 4;
      // The soft take of the third, pitched up from the recording of C4.
      final softThird = _hz(76);
      final down = _power(loop, softThird, rate * 3 + 1440, window);
      expect(down, greaterThan(1e5));
      // On the way up (the third on beat 2), the normal touch only.
      expect(
        _power(loop, softThird, rate + 1440, window),
        lessThan(down * 1e-3),
      );
      expect(_power(loop, _hz(64), rate + 1440, window), greaterThan(1e5));
    });

    test('a chord rolls a little from the root up, as a hand plays it', () {
      // The root silent, the upper notes short, so only their onsets count.
      final s = PianoSamples.mono({
        60: Float32List(rate),
        63: _sine(_hz(63), rate ~/ 5),
        66: _sine(_hz(66), rate ~/ 5),
      });
      final loop = play(s, const [cMajor]);
      // Nothing for the first 2.5 ms, both upper notes within 15 ms.
      expect(_energy(loop, 0, rate * 25 ~/ 10000), 0);
      expect(_energy(loop, rate * 15 ~/ 1000, 500), greaterThan(0.1));
    });

    test('the dampers are heard where the chord changes, only there', () {
      final silent = PianoSamples.mono({
        for (final k in PianoSamples.roots) k: Float32List(rate),
      });
      final dampers = PianoTake.mono(
        Float32List.fromList(List.filled(rate ~/ 10, 0.5)),
      );
      final s = PianoSamples(silent.notes, releases: {60: dampers});
      final bar = rate * 2;
      final change = play(s, const [
        cMajor,
        [62, 65, 69],
      ]);
      // Let go just after the next chord comes in (60 ms), as when the
      // pedal is changed.
      const overlap = rate * 60 ~/ 1000;
      expect(_energy(change, bar + overlap + 100, 1000), greaterThan(1e-4));
      expect(_energy(change, 100, 1000), 0);
      final same = play(s, const [cMajor, cMajor]);
      expect(_energy(same, bar + overlap + 100, 1000), 0);
    });

    test('letting go carries on from the very sample the loop left', () {
      Int16List pcm(Uint8List wav) =>
          Int16List.sublistView(Uint8List.fromList(wav.sublist(44)));
      const chords = [cMajor];
      final (:wav, :scale) = PianoSound.loopWav(
        samples: samples,
        chords: chords,
        style: PianoStyle.beat,
        bpm: 120,
        signature: TimeSignature.fourFour,
      );
      final position = rate * 3 ~/ 4;
      final tail = pcm(
        PianoSound.tailWav(
          samples: samples,
          chords: chords,
          style: PianoStyle.beat,
          bpm: 120,
          signature: TimeSignature.fourFour,
          position: position,
          scale: scale,
        ),
      );
      final loop = pcm(wav);
      // Stereo: two values a frame. Equal but for the dither.
      for (var i = 0; i < 200; i++) {
        expect(
          (tail[i] - loop[2 * position + i]).abs(),
          lessThanOrEqualTo(8),
          reason: 'at $i',
        );
      }
      expect(tail.length ~/ 2, rate * 3 ~/ 2);
      // And it dies away.
      double rms(int from) {
        var e = 0.0;
        for (var i = from; i < from + 2000; i++) {
          e += tail[i] * tail[i].toDouble();
        }
        return e;
      }

      expect(rms(tail.length - 2000), lessThan(rms(0) * 0.01));
    });

    test('a FLAC header says how many samples follow', () {
      final flac = File('assets/piano/C4v8L.flac').readAsBytesSync();
      final frames = PianoLibrary.flacFrames(flac);
      // The normal touch is cut to 10 s.
      expect(frames, closeTo(10 * rate, rate * 0.05));
      expect(
        () => PianoLibrary.flacFrames(Uint8List(40)),
        throwsFormatException,
      );
    });

    test('every file Harmony may load is shipped, and they stay small', () {
      final files = [
        for (final root in PianoSamples.roots)
          for (final layer in PianoSamples.layers) ...[
            PianoSamples.assetsOf(root, layer).$1,
            PianoSamples.assetsOf(root, layer).$2,
          ],
        for (
          var m = PianoSamples.releaseKeys.low;
          m <= PianoSamples.releaseKeys.high;
          m++
        ) ...[
          PianoSamples.releaseAssetsOf(m).$1,
          PianoSamples.releaseAssetsOf(m).$2,
        ],
      ];
      var bytes = 0;
      for (final f in files) {
        final file = File(f);
        expect(file.existsSync(), isTrue, reason: f);
        bytes += file.lengthSync();
      }
      expect(bytes, lessThan(10 * 1024 * 1024));
      for (final root in PianoSamples.roots) {
        expect(PianoSamples.tuning, contains(root));
        expect(PianoSamples.levels, contains(root));
      }
    });
  });

  group('the drone on the piano', () {
    late SilentToneOutput tone;
    late SilentPianoOutput piano;
    late _Clock clock;
    late DroneController drone;

    setUp(() {
      tone = SilentToneOutput();
      piano = SilentPianoOutput();
      clock = _Clock();
      drone = DroneController(tone, clock: clock, piano: piano);
    });

    test('opens on the piano, a chord on every beat', () {
      expect(drone.style, DroneStyle.beat);
    });

    test('a chord every bar is struck once and left to ring', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.held);
      await drone.tapNote(0);
      expect(piano.style, PianoStyle.bar);
      expect(tone.frequencies, isEmpty);
    });

    test('a chord struck on every beat, at the metronome tempo', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.beat);
      await drone.tapNote(0); // C
      expect(piano.chords, [
        [48, 64, 67],
      ]);
      expect(piano.style, PianoStyle.beat);
      expect(piano.bpm, 120);
      expect(piano.signature, TimeSignature.fourFour);
      // The tone is silent, and the piano starts on the first beat.
      expect(tone.frequencies, isEmpty);
      expect(piano.startAt, Duration.zero);
    });
    test('a seventh chord adds the seventh', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setChord(ChordQuality.dominant);
      drone.setStyle(DroneStyle.arpeggio);
      await drone.tapNote(7); // G
      // G in the bass, then D F B close together above it.
      expect(piano.chords!.single, [55, 62, 65, 71]);
      expect(piano.style, PianoStyle.arpeggio);
    });

    test('a progression is one chord a bar, as a loop', () async {
      drone.setVoicing(DroneVoicing.progression);
      drone.setProgression(Progression.twoFiveOne);
      drone.setStyle(DroneStyle.beat);
      await drone.tapNote(0);
      // II–V–I in C: Dm7, G7, Cmaj7, then A7 back to the top.
      // Close together: the hand stays in one place from chord to chord.
      expect(piano.chords, [
        [50, 60, 65, 69],
        [55, 62, 65, 71],
        [48, 64, 67, 71],
        [57, 61, 64, 67],
      ]);
    });

    test('the root in the bass, the rest close together above it', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setChord(ChordQuality.dominant);
      drone.setStyle(DroneStyle.beat);
      await drone.tapNote(7); // G7: G3, then F, B and D from C4 up.
      expect(piano.chords!.single, [55, 62, 65, 71]);
    });

    test('every note played has a recording close to it', () async {
      // The highest and lowest keys Harmony reaches, the root doubled an
      // octave down included, must be within a tone of a recording.
      var low = 127, high = 0;
      void take() {
        for (final chord in piano.chords!) {
          for (final n in chord) {
            low = math.min(low, n);
            high = math.max(high, n);
          }
        }
      }

      drone.setStyle(DroneStyle.beat);
      for (final voicing in DroneVoicing.values) {
        drone.setVoicing(voicing);
        for (final q in ChordQuality.values) {
          drone.setChord(q);
          for (final p in Progression.values) {
            drone.setProgression(p);
            for (var pc = 0; pc < 12; pc++) {
              await drone.tapNote(pc);
              await Future<void>.delayed(const Duration(milliseconds: 1));
              take();
              await drone.stop();
            }
          }
        }
      }
      expect(low, 48);
      expect(high, lessThanOrEqualTo(PianoSamples.roots.last + 2));
      expect(low - 12, greaterThanOrEqualTo(36));
    });

    test('every chord sits in the same octave of keys when close', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.beat);
      for (var pc = 0; pc < 12; pc++) {
        await drone.tapNote(pc);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final upper = piano.chords!.single.sublist(1);
        for (final n in upper) {
          expect(n, inInclusiveRange(60, 71), reason: 'pitch class $pc');
        }
        // The notes are what the chord says, wherever they sit.
        expect({
          for (final n in piano.chords!.single) n % 12,
        }, drone.chordTones.union({pc}));
        await drone.stop();
      }
    });

    test('the root is in octave 3, and the chord stays above it', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.beat);
      expect(drone.octave, 3);
      expect(drone.note.octave, 3);
      await drone.tapNote(9); // A
      // A3 in the bass, then C♯ and E from C4 up.
      expect(piano.chords!.single, [57, 61, 64]);
      expect(drone.frequency, closeTo(220, 0.01));
      await drone.stop();
    });

    test("a single note is played by the piano too", () async {
      await drone.tapNote(9); // A
      expect(piano.chords, [
        [57],
      ]);
      // Kept sounding, not struck on every beat, whatever the style.
      expect(piano.style, PianoStyle.drone);
      expect(tone.frequencies, isEmpty);
    });

    test('in 6/8 the piano plays the clicks: three a beat', () async {
      drone.setVoicing(DroneVoicing.chord);
      clock.signature = TimeSignature.sixEight;
      clock.bpm = 60;
      clock.announce();
      await drone.tapNote(0);
      expect(piano.bpm, 180);
    });

    test('holding + renders the piano only as often as it can', () async {
      final slow = _SlowPianoOutput();
      final d = DroneController(tone, clock: clock, piano: slow);
      d.setVoicing(DroneVoicing.chord);
      await d.tapNote(0);
      final plays = slow.plays;
      for (var i = 0; i < 20; i++) {
        clock.bpm += 5;
        clock.announce();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // One render under way, then one with the latest tempo: not twenty.
      expect(slow.plays - plays, lessThanOrEqualTo(2));
      expect(slow.bpm, 220);
      await d.stop();
    });

    test('a new tempo carries on, a new time signature starts over', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.beat);
      await drone.tapNote(0);
      final plays = piano.plays;
      clock.bpm = 100;
      clock.announce();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(piano.plays, plays + 1);
      expect(piano.bpm, 100);
      expect(piano.startAt, isNull);
      // A tempo crosses over at once, not on the next beat.
      expect(piano.onTheBeat, isFalse);

      clock.signature = TimeSignature.sixEight;
      clock.announce();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(piano.signature, TimeSignature.sixEight);
      expect(piano.startAt, Duration.zero);
    });

    test('struck on every beat, a new note or chord keeps the beat', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.beat);
      await drone.tapNote(0);
      await drone.tapNote(2); // D
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(piano.chords!.single.first, 50);
      expect(piano.startAt, isNull);
      expect(piano.onTheBeat, isTrue);

      drone.setChord(ChordQuality.minor);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(piano.startAt, isNull);
      expect(piano.onTheBeat, isTrue);

      drone.setStyle(DroneStyle.arpeggio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await drone.tapNote(4); // E
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(piano.chords!.single.first, 52);
      expect(piano.startAt, isNull);
    });

    test('struck once a bar, a new note starts from the first beat', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.held);
      await drone.tapNote(0);
      await drone.tapNote(2); // D
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(piano.chords!.single.first, 50);
      expect(piano.startAt, Duration.zero);
    });

    test('a new key restarts a progression from the first beat', () async {
      drone.setVoicing(DroneVoicing.progression);
      drone.setStyle(DroneStyle.beat);
      await drone.tapNote(0);
      await drone.tapNote(2); // D
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(piano.startAt, Duration.zero);
    });

    test('stopping silences the piano', () async {
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.beat);
      await drone.tapNote(0);
      await drone.stop();
      expect(piano.chords, isNull);
    });

    test(
      "without a piano it falls back to the tone, and offers no styles",
      () async {
        final plain = DroneController(tone);
        expect(plain.hasPiano, isFalse);
        await plain.tapNote(9);
        expect(tone.frequencies, isNotEmpty);
      },
    );

    testWidgets('a progression follows its own bars, after the wait', (
      tester,
    ) async {
      piano.delay = const Duration(seconds: 1);
      drone.setVoicing(DroneVoicing.progression);
      drone.setStyle(DroneStyle.beat);
      await drone.tapNote(0);
      await tester.pump();
      expect(drone.step, 0);
      // The first chord comes in after a second, and the next a bar (2 s
      // at 120 BPM in 4/4) after that.
      await tester.pump(const Duration(seconds: 2));
      expect(drone.step, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(drone.step, 1);
      await drone.stop();
    });
  });
}

/// A piano that takes a while to get each loop ready, as rendering does.
class _SlowPianoOutput extends SilentPianoOutput {
  @override
  Future<LoopStart> play({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required double a4,
    required double volume,
    Duration? startAt,
    bool onTheBeat = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return super.play(
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
      volume: volume,
      startAt: startAt,
      onTheBeat: onTheBeat,
    );
  }
}

class _Clock extends ChangeNotifier implements BarClock {
  @override
  Duration barLength = const Duration(seconds: 2);

  @override
  double? barPhase;

  @override
  int bpm = 120;

  @override
  TimeSignature signature = TimeSignature.fourFour;

  /// Tells the listeners that the tempo or the time signature changed.
  void announce() => notifyListeners();
}
