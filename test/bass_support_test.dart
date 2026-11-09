import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/drone_sound.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/pitch.dart';
import 'package:low_end/audio/pitch_detector.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/tuner/tuner_reading.dart';
import 'package:low_end/features/tuner/tuner_tuning.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rate = 16000;

Float64List _string(double hz, int length, List<double> amps) =>
    Float64List.fromList([
      for (var i = 0; i < length; i++)
        0.3 *
            [
              for (var h = 0; h < amps.length; h++)
                amps[h] * math.sin(2 * math.pi * hz * (h + 1) * i / _rate),
            ].reduce((a, b) => a + b),
    ]);

double _cents(double found, double hz) =>
    1200 * math.log(found / hz) / math.ln2;

void main() {
  group('low strings in the detector', () {
    final detector = PitchDetector(sampleRate: _rate);
    final n = detector.windowSize;

    test('E1 and B0 are found, also when the string is a bit off', () {
      for (final target in [41.2, 30.87]) {
        for (final off in [-45.0, -20.0, 0.0, 20.0, 45.0]) {
          final hz = target * math.pow(2, off / 1200);
          final found = detector.detect(_string(hz, n, [1, 0.6, 0.4, 0.3]));
          expect(found, isNotNull, reason: '$target Hz at $off cents');
          expect(
            _cents(found!, hz).abs(),
            lessThan(2),
            reason: '$target at $off found as $found',
          );
        }
      }
    });

    test('B0 with a fundamental weaker than the overtones', () {
      // Common on a low B: most of the energy is in the second and third.
      final found = detector.detect(_string(30.87, n, [0.25, 1, 0.8, 0.5]));
      expect(found, isNotNull);
      expect(_cents(found!, 30.87).abs(), lessThan(2));
    });

    test('the window holds at least three periods of the lowest note', () {
      expect(n / _rate, greaterThan(3 / 30.87));
    });

    test("low strings with room noise are placed within a few cents", () {
      // Noise made a low string read sharp: the dip of the curve was taken
      // at its first ripple instead of its bottom.
      for (final hz in [30.87, 41.2]) {
        for (var seed = 1; seed <= 6; seed++) {
          final random = math.Random(seed);
          final clean = _string(hz, n, [1, 0.6, 0.4]);
          final noisy = Float64List.fromList([
            for (var i = 0; i < n; i++)
              clean[i] * 0.4 + (random.nextDouble() - 0.5) * 0.05,
          ]);
          final found = detector.detect(noisy);
          expect(found, isNotNull, reason: "$hz Hz, seed $seed");
          expect(
            _cents(found!, hz).abs(),
            lessThan(8),
            reason: "$hz Hz, seed $seed",
          );
        }
      }
    });
  });

  group('the tuner on strings', () {
    test('the strings of the instruments', () {
      String names(TunerTuning t) =>
          t.strings.map((s) => s.label(NoteNames.letters)).join(' ');
      expect(names(TunerTuning.violin), 'G3 D4 A4 E5');
      expect(names(TunerTuning.bass), 'E1 A1 D2 G2');
      expect(TunerTuning.chromatic.isChromatic, isTrue);
    });

    test('E1 is 41.2 Hz and B0 30.87 Hz', () {
      expect(const Note(4, 1).frequency(), closeTo(41.2, 0.01));
      expect(const Note(11, 0).frequency(), closeTo(30.87, 0.01));
    });

    test('the target is the nearest string and cents are from it', () {
      final r = TunerReading.of(
        const Note(4, 1).frequency() * math.pow(2, -45 / 1200),
        tuning: TunerTuning.bass,
      );
      expect(r.target, const Note(4, 1));
      expect(r.onStrings, isTrue);
      expect(r.cents, closeTo(-45, 0.01));
      expect(r.inTune, isFalse);
    });

    test(
      'a low string far below the others is still named, not a semitone',
      () {
        // 40 cents under E1 is E1 in strings; chromatic would also say E1, but
        // 60 cents under is D#1 chromatically and still E1 with strings.
        final hz = const Note(4, 1).frequency() * math.pow(2, -60 / 1200);
        final chromatic = TunerReading.of(hz);
        expect(chromatic.target, const Note(3, 1));
        final strings = TunerReading.of(hz, tuning: TunerTuning.bass);
        expect(strings.target, const Note(4, 1));
        expect(strings.played, const Note(3, 1));
        expect(strings.cents, closeTo(-60, 0.01));
      },
    );

    test('the bass finds a fifth string, unannounced', () {
      final r = TunerReading.of(30.87, tuning: TunerTuning.bass);
      expect(r.target, const Note(11, 0));
      expect(r.inTune, isTrue);
      expect(TunerTuning.bass.strings, hasLength(4));
    });

    test('the violin follows the reference A', () {
      final r = TunerReading.of(443, a4: 443, tuning: TunerTuning.violin);
      expect(r.target, const Note(9, 4));
      expect(r.cents, closeTo(0, 0.001));
    });

    test('strings are numbered from the thinnest, in Roman numerals', () {
      String number(TunerTuning t, double hz) {
        final r = TunerReading.of(hz, tuning: t);
        return romanNumeral(r.stringNumber!);
      }

      expect(number(TunerTuning.violin, 659.26), 'I');
      expect(number(TunerTuning.violin, 196), 'IV');
      expect(number(TunerTuning.bass, 41.2), 'IV');
      expect(number(TunerTuning.bass, 98), 'I');
      expect(number(TunerTuning.bass, 30.87), 'V');
      // A six-string bass's high C is found, with no number to show.
      expect(TunerReading.of(130.81, tuning: TunerTuning.bass).target.midi, 48);
      expect(
        TunerReading.of(130.81, tuning: TunerTuning.bass).stringNumber,
        isNull,
      );
      expect(number(TunerTuning.guitar, 82.41), 'VI');
      expect(number(TunerTuning.guitar, 329.63), 'I');
      expect(number(TunerTuning.cello, 65.41), 'IV');
      expect(number(TunerTuning.viola, 440), 'I');
      // The ukulele's high G is its fourth string.
      expect(number(TunerTuning.ukulele, 392), 'IV');
      expect(number(TunerTuning.ukulele, 261.63), 'III');
      expect(TunerReading.of(440).stringNumber, isNull);
    });

    test('chromatic readings are as before', () {
      final r = TunerReading.of(440);
      expect(r.onStrings, isFalse);
      expect(r.target, r.played);
    });
  });

  group('octave numbering', () {
    test('scientific and Italian, whatever the names', () {
      const e1 = Note(4, 1);
      expect(
        e1.label(NoteNames.letters, numbering: OctaveNumbering.scientific),
        'E1',
      );
      expect(
        e1.label(NoteNames.solfege, numbering: OctaveNumbering.scientific),
        'Mi1',
      );
      expect(
        e1.label(NoteNames.solfege, numbering: OctaveNumbering.italian),
        'Mi0',
      );
      expect(
        e1.label(NoteNames.letters, numbering: OctaveNumbering.italian),
        'E0',
      );
    });

    test('defaults to scientific and is saved', () async {
      SharedPreferences.setMockInitialValues({});
      var settings = await AppSettings.load();
      expect(settings.octaveNumbering, OctaveNumbering.scientific);
      settings.setOctaveNumbering(OctaveNumbering.italian);
      await Future<void>.delayed(Duration.zero);
      settings = await AppSettings.load();
      expect(settings.octaveNumbering, OctaveNumbering.italian);
    });

    test(
      'an install with solfège names and nothing saved turns scientific',
      () async {
        SharedPreferences.setMockInitialValues({'note_names': 'solfege'});
        final settings = await AppSettings.load();
        expect(settings.naming, NoteNaming.solfege);
        expect(settings.octaveNumbering, OctaveNumbering.scientific);
      },
    );

    test('a damaged value falls back to the default', () async {
      SharedPreferences.setMockInitialValues({
        'octave_numbering': 'martian',
        'tuner_tuning': 7,
      });
      final settings = await AppSettings.load();
      expect(settings.octaveNumbering, OctaveNumbering.scientific);
      expect(settings.tuning, TunerTuning.chromatic);
    });

    test('the tuning is saved', () async {
      SharedPreferences.setMockInitialValues({});
      var settings = await AppSettings.load();
      expect(settings.tuning, TunerTuning.chromatic);
      expect(settings.tunerInstrument, TunerTuning.guitar);
      settings.setTunerInstrument(TunerTuning.violin);
      await Future<void>.delayed(Duration.zero);
      settings = await AppSettings.load();
      expect(settings.tuning, TunerTuning.violin);
      // Back to chromatic: the instrument stays chosen.
      settings.setTunerChromatic(true);
      await Future<void>.delayed(Duration.zero);
      settings = await AppSettings.load();
      expect(settings.tuning, TunerTuning.chromatic);
      expect(settings.tunerInstrument, TunerTuning.violin);
    });
  });

  group('the drone: its octave and its sound', () {
    late SilentToneOutput tone;
    late SilentPianoOutput piano;
    late DroneController drone;

    setUp(() {
      tone = SilentToneOutput();
      piano = SilentPianoOutput();
      drone = DroneController(tone, piano: piano);
    });

    test('one octave, A3 = 220 Hz, every root above what a speaker loses', () {
      expect(DroneController.rootOctave, 3);
      expect(drone.octave, 3);
      expect(drone.frequency, closeTo(220, 0.01));
      // C3, the lowest root, at the lowest reference A still clears the
      // 120 Hz under which a phone speaker hardly plays it.
      drone.setReferencePitch(415);
      drone.setPitchClass(0);
      expect(drone.frequency, greaterThan(DroneSound.lowRootHz));
    });

    test('the piano plays by default and a held tone replaces it', () async {
      await drone.tapNote(9);
      expect(drone.usesPiano, isTrue);
      expect(piano.chords, isNotNull);
      expect(tone.frequencies, isEmpty);

      drone.setContinuous(true);
      await Future<void>.delayed(Duration.zero);
      expect(drone.usesPiano, isFalse);
      expect(tone.frequencies.single, closeTo(220, 0.01));
      expect(piano.chords, isNull);

      drone.setContinuous(false);
      await Future<void>.delayed(Duration.zero);
      expect(drone.usesPiano, isTrue);
      expect(piano.chords, isNotNull);
      expect(tone.frequencies, isEmpty);
    });
  });

  group('the drone tone for a low root', () {
    test('keeps its pitch and is heard by the detector on its overtones', () {
      final samples = DroneSound.loop([41.2], [1]);
      final peak = samples.fold<double>(0, (m, s) => math.max(m, s.abs()));
      expect(peak, closeTo(0.85, 0.001));
      // Seamless: the loop is a whole number of cycles of the root.
      final cycles = samples.length * 41.2 / DroneSound.sampleRate;
      expect((cycles - cycles.round()).abs(), lessThan(0.01));
    });

    test('a low root has more energy in its upper harmonics', () {
      double upperShare(double hz) {
        final s = DroneSound.loop([hz], [1]);
        // Energy of the second to fourth harmonics against the fundamental,
        // by correlation with sines at those frequencies.
        double power(double f) {
          var re = 0.0, im = 0.0;
          for (var i = 0; i < s.length; i++) {
            final a = 2 * math.pi * f * i / DroneSound.sampleRate;
            re += s[i] * math.cos(a);
            im += s[i] * math.sin(a);
          }
          return re * re + im * im;
        }

        return (power(2 * hz) + power(3 * hz) + power(4 * hz)) / power(hz);
      }

      expect(upperShare(82.41), greaterThan(upperShare(220)));
    });
  });

  group('on screen', () {
    testWidgets('the tuner has strings', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final settings = AppSettings();
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          micInput: FakeMicInput(),
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();
      final scope = AudioScope.of(tester.element(find.byType(HomeShell)));

      scope.navigation.open(AppSection.tuner);
      await tester.pumpAndSettle();
      // One field that names what is tuned: Chromatic first in its menu.
      final field = find.byKey(const Key('instrumentMenu'));
      expect(settings.tuning, TunerTuning.chromatic);
      expect(
        find.descendant(of: field, matching: find.text('Chromatic')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: field, matching: find.text('Guitar')),
        findsNothing,
        reason: 'the remembered instrument is not shown while chromatic',
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.text('Any note, no strings to choose'), findsOneWidget);
      await tester.tap(find.text('Violin').last);
      await tester.pumpAndSettle();
      expect(settings.tuning, TunerTuning.violin);
      expect(
        find.descendant(of: field, matching: find.text('Violin')),
        findsOneWidget,
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chromatic').last);
      await tester.pumpAndSettle();
      expect(settings.tuning, TunerTuning.chromatic);
      expect(settings.tunerInstrument, TunerTuning.violin);
    });
  });
}
