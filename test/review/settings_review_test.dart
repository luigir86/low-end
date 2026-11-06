import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/pitch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSettings.load', () {
    test('defaults with nothing saved', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppSettings.load();
      expect(s.languageCode, isNull);
      expect(s.naming, NoteNaming.auto);
      expect(s.a4, 440);
      expect(s.locale, isNull);
    });

    test('saves and reads back every setting', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppSettings.load();
      s.setLanguage('it');
      s.setNaming(NoteNaming.letters);
      s.setReferencePitch(442);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), 'it');
      expect(prefs.getString('note_names'), 'letters');
      expect(prefs.getDouble('reference_pitch'), 442);

      final again = await AppSettings.load();
      expect(again.languageCode, 'it');
      expect(again.naming, NoteNaming.letters);
      expect(again.a4, 442);

      again.setLanguage(null);
      expect(prefs.containsKey('language'), isFalse);
      expect((await AppSettings.load()).languageCode, isNull);
    });

    test('saves the screen option', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await AppSettings.load();
      expect(s.keepScreenOn, isTrue);
      s.setKeepScreenOn(false);

      final again = await AppSettings.load();
      expect(again.keepScreenOn, isFalse);
    });

    test(
      'ignores a screen option of the wrong kind, and an old theme',
      () async {
        SharedPreferences.setMockInitialValues({
          // Saved by versions that had a choice of theme: now left alone.
          'theme': 'light',
          'keep_screen_on': 'yes',
        });
        final s = await AppSettings.load();
        expect(s.keepScreenOn, isTrue);
      },
    );

    test('ignores unknown saved strings and numbers', () async {
      SharedPreferences.setMockInitialValues({
        'language': 'de',
        'note_names': 'klingon',
        'reference_pitch': 446.0,
      });
      final s = await AppSettings.load();
      expect(s.languageCode, isNull);
      expect(s.naming, NoteNaming.auto);
      expect(s.a4, 440);
    });

    test('ignores NaN and empty strings', () async {
      SharedPreferences.setMockInitialValues({
        'language': '',
        'note_names': '',
        'reference_pitch': double.nan,
      });
      final s = await AppSettings.load();
      expect(s.languageCode, isNull);
      expect(s.naming, NoteNaming.auto);
      expect(s.a4, 440);
    });

    // A value saved with another type (an older build, a restored backup, a
    // hand-edited file) must not stop the app from opening.
    test('survives a reference pitch saved as an int', () async {
      SharedPreferences.setMockInitialValues({'reference_pitch': 442});
      final s = await AppSettings.load();
      expect(s.a4, anyOf(440, 442));
    });

    test('survives a language saved with the wrong type', () async {
      SharedPreferences.setMockInitialValues({
        'language': 1,
        'note_names': true,
      });
      final s = await AppSettings.load();
      expect(s.languageCode, isNull);
      expect(s.naming, NoteNaming.auto);
    });
  });

  group('note names', () {
    test('auto follows the app language', () {
      final s = AppSettings();
      expect(s.noteNames(const Locale('it')), NoteNames.solfege);
      expect(s.noteNames(const Locale('it', 'CH')), NoteNames.solfege);
      expect(s.noteNames(const Locale('en')), NoteNames.letters);
      expect(s.noteNames(const Locale('de')), NoteNames.letters);
      s.setNaming(NoteNaming.solfege);
      expect(s.noteNames(const Locale('en')), NoteNames.solfege);
      s.setNaming(NoteNaming.letters);
      expect(s.noteNames(const Locale('it')), NoteNames.letters);
    });

    test('Italian octave numbers are one lower: La3 = 440 Hz', () {
      const a4 = Note(9, 4);
      expect(a4.label(NoteNames.letters), 'A4');
      expect(a4.label(NoteNames.solfege), 'La3');
      expect(const Note(0, 4).label(NoteNames.solfege), 'Do3');
      // Bass open strings.
      expect(const Note(4, 1).label(NoteNames.solfege), 'Mi0');
      expect(const Note(9, 1).label(NoteNames.solfege), 'La0');
      expect(const Note(7, 2).label(NoteNames.solfege), 'Sol1');
      expect(const Note(11, 0).label(NoteNames.letters), 'B0');
      expect(const Note(11, 0).label(NoteNames.solfege), 'Si-1');
      expect(const Note(10, 1).label(NoteNames.solfege), 'Si♭0');
      expect(Note.nearest(440).label(NoteNames.solfege), 'La3');
      expect(Note.nearest(30.87).label(NoteNames.letters), 'B0');
    });

    test('Note.nearest round-trips midi across the bass range', () {
      for (var midi = 23; midi <= 79; midi++) {
        final hz = 440 * _pow2((midi - 69) / 12);
        final n = Note.nearest(hz);
        expect(n.midi, midi);
        expect(n.frequency(), closeTo(hz, 1e-6));
        // With a different reference the same note sits elsewhere.
        expect(Note.nearest(hz * 442 / 440, a4: 442).midi, midi);
      }
    });

    test('Note.nearest at the B/C octave boundary', () {
      // B3 (246.94) vs C4 (261.63): octave number changes at C.
      expect(Note.nearest(246.94), const Note(11, 3));
      expect(Note.nearest(261.63), const Note(0, 4));
      // Just above the B-C midpoint rounds to C4.
      expect(Note.nearest(254.3), const Note(0, 4));
    });
  });
}

double _pow2(double x) => math.pow(2, x).toDouble();
