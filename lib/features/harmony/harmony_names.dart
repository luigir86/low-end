import 'dart:ui' show Locale;

import '../../audio/pitch.dart';
import '../../l10n/app_localizations.dart';
import 'drone_controller.dart';
import 'harmony.dart';

// How chords, progressions, keys and degrees are written on screen, in the
// player's language: one place for every name the Harmony shows.

/// The name of a kind of chord, as listed in the chord menu.
String chordName(AppLocalizations l10n, ChordQuality chord) => switch (chord) {
  ChordQuality.major => l10n.chordMajor,
  ChordQuality.minor => l10n.chordMinor,
  ChordQuality.dominant => l10n.chordDominant,
  ChordQuality.dominantFlat9 => l10n.chordDominantFlat9,
  ChordQuality.major7 => l10n.chordMajor7,
  ChordQuality.minor7 => l10n.chordMinor7,
  ChordQuality.halfDiminished => l10n.chordHalfDiminished,
  ChordQuality.diminished => l10n.chordDiminished,
  ChordQuality.sus4 => l10n.chordSus4,
};

/// A chord on [note], as musicians write it: "A major", "La minore", "A7",
/// "Rem7", "Domaj7"; its words in the language of [names].
String chordSymbol(DroneChord chord, String note, NoteNames names) =>
    _chordSymbol(chordWords(names), chord, note);

/// The words round a chord or key name ("major", "maggiore") follow the
/// note names, not the app's language: C D E go with English words
/// (C♯ major), Do Re Mi with Italian ones (Do♯ maggiore).
AppLocalizations chordWords(NoteNames names) =>
    lookupAppLocalizations(Locale(names == NoteNames.letters ? 'en' : 'it'));

String _chordSymbol(AppLocalizations l10n, DroneChord chord, String note) =>
    switch (chord.quality) {
      ChordQuality.major => l10n.droneChordMajor(note),
      ChordQuality.minor => l10n.droneChordMinor(note),
      ChordQuality.dominant => l10n.droneChordSeventh(note),
      ChordQuality.dominantFlat9 => '${note}7♭9',
      ChordQuality.major7 => '${note}maj7',
      ChordQuality.minor7 => '${note}m7',
      ChordQuality.halfDiminished => l10n.droneChordHalfDiminished(note),
      ChordQuality.diminished => l10n.droneChordDiminished(note),
      ChordQuality.sus4 => '${note}sus4',
    };

/// The name of a progression, as listed in its menu.
String progressionName(AppLocalizations l10n, Progression p) => switch (p) {
  Progression.twoFiveOne => 'II–V–I',
  Progression.minorTwoFiveOne => l10n.progressionMinorTwoFiveOne,
  Progression.circleOfFifths => l10n.progressionCircleOfFifths,
  Progression.oneSixTwoFive => 'I–VI–II–V',
  Progression.blues => l10n.progressionBlues,
  Progression.minorBlues => l10n.progressionMinorBlues,
  Progression.oneSixFourFive => 'I–VI–IV–V',
  Progression.oneFiveSixFour => 'I–V–VI–IV',
  Progression.andalusian => 'I–♭VII–♭VI–V',
};

/// The well-known song a progression is named after in the menu.
String progressionSong(Progression p) => switch (p) {
  Progression.twoFiveOne => 'Tune Up',
  Progression.minorTwoFiveOne => 'Blue Bossa',
  Progression.circleOfFifths => 'Autumn Leaves',
  Progression.oneSixTwoFive => 'I Got Rhythm',
  Progression.blues => 'Sweet Home Chicago',
  Progression.minorBlues => 'Mr. P.C.',
  Progression.oneSixFourFive => 'Stand by Me',
  Progression.oneFiveSixFour => 'With or Without You',
  Progression.andalusian => 'Hit the Road Jack',
};

/// The heading of a section of the progression menu.
String progressionSectionName(AppLocalizations l10n, ProgressionSection s) =>
    switch (s) {
      ProgressionSection.popRock => l10n.progressionSectionPopRock,
      ProgressionSection.blues => l10n.progressionSectionBlues,
      ProgressionSection.jazz => l10n.progressionSectionJazz,
    };

/// The line under the name in the menu: "Like With or Without You"; for I–VI–IV–V,
/// I–♭VII–♭VI–V and I–VI–II–V also their common names, the "giro di Do" of
/// Italian musicians, the Andalusian cadence and the Anatole of jazz
/// musicians.
String progressionNote(AppLocalizations l10n, Progression p) => switch (p) {
  Progression.oneSixFourFive => l10n.progressionGiroLike(progressionSong(p)),
  Progression.andalusian => l10n.progressionAndalusianLike(progressionSong(p)),
  Progression.oneSixTwoFive => l10n.progressionAnatoleLike(progressionSong(p)),
  _ => l10n.progressionLike(progressionSong(p)),
};

/// The key written out: "La maggiore", "C minor", spelled as the key is
/// (D♭ major, not C♯).
String keyName(DroneController drone, NoteNames names) {
  final tonic = spell(drone.note.pitchClass, drone.keyLetter, names);
  final words = chordWords(names);
  return drone.keyIsMinor
      ? words.droneChordMinor(tonic)
      : words.droneChordMajor(tonic);
}

/// A progression by its numerals, or the name of the blues, which is too long
/// to list (the key says whether it is minor): "II–V–I", "Blues".
String progressionShort(AppLocalizations l10n, Progression p) => switch (p) {
  Progression.minorTwoFiveOne => 'II–V–I',
  Progression.blues || Progression.minorBlues => l10n.progressionBluesShort,
  _ => progressionName(l10n, p),
};

/// "II–V–I in La maggiore": what is being practised, and in which key.
String keyLine(AppLocalizations l10n, DroneController drone, NoteNames names) =>
    l10n.keyLine(
      progressionShort(l10n, drone.progression),
      keyName(drone, names),
    );

/// The name of a degree of the scale, [degree] 0 for the tonic.
String degreeName(AppLocalizations l10n, int degree, {bool minor = false}) =>
    switch (degree) {
      0 => l10n.degreeName1,
      1 => l10n.degreeName2,
      2 => l10n.degreeName3,
      3 => l10n.degreeName4,
      4 => l10n.degreeName5,
      5 => l10n.degreeName6,
      _ => minor ? l10n.degreeName7Minor : l10n.degreeName7,
    };
