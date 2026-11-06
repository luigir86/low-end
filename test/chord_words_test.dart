import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/actions/app_actions.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/pitch.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:low_end/features/harmony/harmony_names.dart';

void main() {
  // The words of a chord follow the note names, not the app's language:
  // with C D E in an Italian app, C♯ major, not C♯ maggiore.
  test('letters go with English words, Do Re Mi with Italian ones', () {
    const major = (root: 1, quality: ChordQuality.major);
    const minor = (root: 9, quality: ChordQuality.minor);
    const dim = (root: 11, quality: ChordQuality.diminished);
    expect(chordSymbol(major, 'C♯', NoteNames.letters), 'C♯ major');
    expect(chordSymbol(minor, 'A', NoteNames.letters), 'A minor');
    expect(chordSymbol(major, 'Do♯', NoteNames.solfege), 'Do♯ maggiore');
    expect(chordSymbol(minor, 'La', NoteNames.solfege), 'La minore');
    expect(chordSymbol(dim, 'B', NoteNames.letters), 'B diminished');
    expect(chordSymbol(dim, 'Si', NoteNames.solfege), 'Si diminuito');
  });

  test('Do Re Mi in Spanish and French take their own words and spelling', () {
    const major = (root: 2, quality: ChordQuality.major);
    const minor = (root: 9, quality: ChordQuality.minor);
    const half = (root: 11, quality: ChordQuality.halfDiminished);
    const re = Note(2, 4);
    expect(re.name(NoteNames.solfegeSpanish), 'Re');
    expect(re.name(NoteNames.solfegeFrench), 'Ré');
    expect(const Note(1, 4).name(NoteNames.solfegeFrench, flat: true), 'Ré♭');
    expect(chordSymbol(major, 'Re', NoteNames.solfegeSpanish), 'Re mayor');
    expect(chordSymbol(minor, 'La', NoteNames.solfegeSpanish), 'La menor');
    expect(
      chordSymbol(half, 'Si', NoteNames.solfegeSpanish),
      'Si semidisminuido',
    );
    expect(chordSymbol(major, 'Ré', NoteNames.solfegeFrench), 'Ré majeur');
    expect(chordSymbol(minor, 'La', NoteNames.solfegeFrench), 'La mineur');
    expect(chordSymbol(half, 'Si', NoteNames.solfegeFrench), 'Si demi-diminué');
    // Every solfège numbers octaves one lower by default: La3 = 440 Hz.
    expect(const Note(9, 4).label(NoteNames.solfegeFrench), 'La3');
  });

  test('never letters with other words, whatever the language', () {
    final s = AppSettings();
    for (final lang in ['it', 'es', 'fr']) {
      expect(s.noteNames(Locale(lang)).isSolfege, isTrue, reason: lang);
      expect(s.noteNames(Locale(lang)).words, lang);
    }
    expect(s.noteNames(const Locale('en')), NoteNames.letters);
    expect(s.noteNames(const Locale('de')), NoteNames.letters);
    s.setNaming(NoteNaming.letters);
    for (final lang in ['en', 'it', 'es', 'fr']) {
      expect(s.noteNames(Locale(lang)).words, 'en', reason: lang);
    }
    // Do Re Mi in an English app has Italian words: Do maggiore.
    s.setNaming(NoteNaming.solfege);
    expect(s.noteNames(const Locale('en')), NoteNames.solfege);
    expect(s.noteNames(const Locale('fr')), NoteNames.solfegeFrench);
  });

  test('assistants may write Ré', () {
    expect(parseNote('Ré')?.pitchClass, 2);
    expect(parseNote('réb2'), (pitchClass: 1, octave: 2));
  });
}
