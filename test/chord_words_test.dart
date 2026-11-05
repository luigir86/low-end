import 'package:flutter_test/flutter_test.dart';
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
}
