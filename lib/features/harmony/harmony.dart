/// Chords and progressions for the drone, in pure (just) intervals so the
/// notes do not beat against each other, which is what you want when
/// checking intonation.
library;

import '../metronome/subdivision.dart';
import '../metronome/time_signature.dart';
import 'drone_controller.dart';

/// The kind of a chord: its notes above the root as pure ratios, as
/// semitones, and as steps up the scale (2 for a third, 3 for a fourth, 6
/// for a seventh), which say what letter each note is written with.
enum ChordQuality {
  /// Major triad.
  major([1, 5 / 4, 3 / 2], [4, 7], [2, 4]),

  /// Minor triad.
  minor([1, 6 / 5, 3 / 2], [3, 7], [2, 4]),

  /// Dominant seventh, 7. The seventh is 16/9 (996 cents), the pure ratio
  /// closest to the minor seventh a bassist plays: the harmonic seventh,
  /// 7/4, would sound 31 cents flat of it.
  dominant([1, 5 / 4, 3 / 2, 16 / 9], [4, 7, 10], [2, 4, 6]),

  /// Dominant seventh with a flat ninth, 7♭9: the V of a minor key, from
  /// the harmonic minor. In C minor, G7♭9 is G B D F A♭: the major third is
  /// the leading tone to C, the ♭9 is the key's A♭. The ninth is 32/15, an
  /// octave above the pure half step 16/15.
  dominantFlat9([1, 5 / 4, 3 / 2, 16 / 9, 32 / 15], [4, 7, 10, 13], [
    2,
    4,
    6,
    8,
  ]),

  /// Major seventh, maj7 (15/8).
  major7([1, 5 / 4, 3 / 2, 15 / 8], [4, 7, 11], [2, 4, 6]),

  /// Minor seventh, m7 (9/5).
  minor7([1, 6 / 5, 3 / 2, 9 / 5], [3, 7, 10], [2, 4, 6]),

  /// Half-diminished seventh, m7♭5.
  halfDiminished([1, 6 / 5, 64 / 45, 16 / 9], [3, 6, 10], [2, 4, 6]),

  /// Diminished triad.
  diminished([1, 6 / 5, 64 / 45], [3, 6], [2, 4]),

  /// Suspended fourth, sus4: the fourth in place of the third.
  sus4([1, 4 / 3, 3 / 2], [5, 7], [3, 4]);

  const ChordQuality(this._ratios, this._semitones, this.letterSteps);

  final List<double> _ratios;
  final List<int> _semitones;

  /// How many letters above the root's each note above it is written.
  final List<int> letterSteps;

  /// Ratios to the root, the root first.
  List<double> get ratios => _ratios;

  /// The notes above the root, in semitones.
  List<int> get semitones => _semitones;
}

/// One chord of a progression: its root, in semitones above the key, its
/// quality and its Roman numeral.
class ProgressionStep {
  const ProgressionStep(this.offset, this.quality, this.numeral);

  final int offset;
  final ChordQuality quality;
  final String numeral;

  /// Steps up the scale from the key, 0 for I, 4 for V: which letter the
  /// root is written with. A ♭ before the numeral does not count.
  int get degree => const [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
  ].indexOf(numeral.replaceAll('♭', '').toUpperCase());
}

/// Standard progressions, one chord per bar, played over and over in the
/// key of the note touched. Each lasts 4, 8 or 12 bars, as musical phrases
/// do: a loop of three bars would start again where the ear still expects
/// the I. Jazz ones and the blues are in sevenths, the others in triads.
/// The menu lists them in this order: the giro di Do first, the one chosen
/// at the start, then from the easiest to the richest, in sections by
/// [ProgressionSection].
enum Progression {
  /// I–VI–IV–V, the "giro di Do" of Italian musicians and the doo-wop
  /// progression, as in Stand by Me: in C, C Am F G7.
  oneSixFourFive([
    ProgressionStep(0, ChordQuality.major, 'I'),
    ProgressionStep(9, ChordQuality.minor, 'VI'),
    ProgressionStep(5, ChordQuality.major, 'IV'),
    ProgressionStep(7, ChordQuality.dominant, 'V'),
  ]),

  /// I–V–VI–IV: in C, C G Am F.
  oneFiveSixFour([
    ProgressionStep(0, ChordQuality.major, 'I'),
    ProgressionStep(7, ChordQuality.major, 'V'),
    ProgressionStep(9, ChordQuality.minor, 'VI'),
    ProgressionStep(5, ChordQuality.major, 'IV'),
  ]),

  /// Andalusian cadence, in a minor key: in A, Am G F E.
  andalusian([
    ProgressionStep(0, ChordQuality.minor, 'I'),
    ProgressionStep(10, ChordQuality.major, '♭VII'),
    ProgressionStep(8, ChordQuality.major, '♭VI'),
    ProgressionStep(7, ChordQuality.major, 'V'),
  ], minor: true),

  /// Twelve-bar blues: I I I I, IV IV I I, V IV I V, all dominant sevenths.
  blues([
    ProgressionStep(0, ChordQuality.dominant, 'I'),
    ProgressionStep(0, ChordQuality.dominant, 'I'),
    ProgressionStep(0, ChordQuality.dominant, 'I'),
    ProgressionStep(0, ChordQuality.dominant, 'I'),
    ProgressionStep(5, ChordQuality.dominant, 'IV'),
    ProgressionStep(5, ChordQuality.dominant, 'IV'),
    ProgressionStep(0, ChordQuality.dominant, 'I'),
    ProgressionStep(0, ChordQuality.dominant, 'I'),
    ProgressionStep(7, ChordQuality.dominant, 'V'),
    ProgressionStep(5, ChordQuality.dominant, 'IV'),
    ProgressionStep(0, ChordQuality.dominant, 'I'),
    ProgressionStep(7, ChordQuality.dominant, 'V'),
  ]),

  /// Minor blues, twelve bars: Im7 for four, IVm7 IVm7 Im7 Im7, ♭VI7 V7♭9
  /// Im7 V7♭9. In C minor, Cm7 … Fm7 … A♭7 G7♭9.
  minorBlues([
    ProgressionStep(0, ChordQuality.minor7, 'I'),
    ProgressionStep(0, ChordQuality.minor7, 'I'),
    ProgressionStep(0, ChordQuality.minor7, 'I'),
    ProgressionStep(0, ChordQuality.minor7, 'I'),
    ProgressionStep(5, ChordQuality.minor7, 'IV'),
    ProgressionStep(5, ChordQuality.minor7, 'IV'),
    ProgressionStep(0, ChordQuality.minor7, 'I'),
    ProgressionStep(0, ChordQuality.minor7, 'I'),
    ProgressionStep(8, ChordQuality.dominant, '♭VI'),
    ProgressionStep(7, ChordQuality.dominantFlat9, 'V'),
    ProgressionStep(0, ChordQuality.minor7, 'I'),
    ProgressionStep(7, ChordQuality.dominantFlat9, 'V'),
  ], minor: true),

  /// Major II–V–I, closed by the VI7 that turns it around to the II: in C,
  /// Dm7 G7 Cmaj7 A7, and A7 leads back to Dm7.
  twoFiveOne([
    ProgressionStep(2, ChordQuality.minor7, 'II'),
    ProgressionStep(7, ChordQuality.dominant, 'V'),
    ProgressionStep(0, ChordQuality.major7, 'I'),
    ProgressionStep(9, ChordQuality.dominant, 'VI'),
  ]),

  /// Minor II–V–I, closed by the ♭VI7 that turns it around to the II: in
  /// C, Dm7♭5 G7♭9 Cm7 A♭7, darker than A7 and still in the key. The V has
  /// the ♭9 of the minor key (see [ChordQuality.dominantFlat9]).
  minorTwoFiveOne([
    ProgressionStep(2, ChordQuality.halfDiminished, 'II'),
    ProgressionStep(7, ChordQuality.dominantFlat9, 'V'),
    ProgressionStep(0, ChordQuality.minor7, 'I'),
    ProgressionStep(8, ChordQuality.dominant, '♭VI'),
  ], minor: true),

  /// I–VI–II–V, the jazz turnaround that jazz musicians call the Anatole,
  /// as in the A section of I Got Rhythm: in C, Cmaj7 A7 Dm7 G7.
  oneSixTwoFive([
    ProgressionStep(0, ChordQuality.major7, 'I'),
    ProgressionStep(9, ChordQuality.dominant, 'VI'),
    ProgressionStep(2, ChordQuality.minor7, 'II'),
    ProgressionStep(7, ChordQuality.dominant, 'V'),
  ]),

  /// Down the circle of fifths, eight bars, as in Autumn Leaves: in C,
  /// Dm7 G7 Cmaj7 Fmaj7 Bm7♭5 E7♭9 Am7 A7, and A7 turns it around to Dm7.
  /// E7♭9 is the V of A minor, so it has the ♭9 of that key.
  circleOfFifths([
    ProgressionStep(2, ChordQuality.minor7, 'II'),
    ProgressionStep(7, ChordQuality.dominant, 'V'),
    ProgressionStep(0, ChordQuality.major7, 'I'),
    ProgressionStep(5, ChordQuality.major7, 'IV'),
    ProgressionStep(11, ChordQuality.halfDiminished, 'VII'),
    ProgressionStep(4, ChordQuality.dominantFlat9, 'III'),
    ProgressionStep(9, ChordQuality.minor7, 'VI'),
    ProgressionStep(9, ChordQuality.dominant, 'VI'),
  ]);

  const Progression(this.steps, {this.minor = false});

  final List<ProgressionStep> steps;

  /// The key is minor.
  final bool minor;

  /// The section of the menu it is listed in.
  ProgressionSection get section => switch (this) {
    oneFiveSixFour ||
    oneSixFourFive ||
    andalusian => ProgressionSection.popRock,
    blues || minorBlues => ProgressionSection.blues,
    _ => ProgressionSection.jazz,
  };
}

/// The sections of the progression menu, by genre, in this order.
enum ProgressionSection { popRock, blues, jazz }

/// A song to practise on, and the whole preset it sets in one tap: its key
/// (as a pitch class) and progression in Harmony with the way the piano
/// plays it, and the metronome's time signature and tempo, with its
/// subdivision and its click on 2 and 4 when the song asks for them. The
/// example songs are written here; a song can also be read from and written
/// to JSON ([fromJson], [toJson]), so that one made elsewhere (by an
/// assistant, or one day by the player) is the same object. The names are
/// the songs' own and are not translated.
class ExampleSong {
  const ExampleSong(
    this.title,
    this.artist,
    this.pitchClass,
    this.progression,
    this.bpm,
    this.style, {
    this.signature = TimeSignature.fourFour,
    this.subdivision,
    this.backbeat,
  });

  /// Reads a song written by [toJson]; throws a [FormatException] naming
  /// the field that is missing or wrong.
  factory ExampleSong.fromJson(Map<String, Object?> json) {
    T field<T>(String name) => switch (json[name]) {
      final T value => value,
      _ => throw FormatException('"$name" is missing or wrong in a song.'),
    };
    T named<T>(String name, Iterable<T> values, String Function(T) id) {
      final text = field<String>(name);
      return values.where((v) => id(v) == text).firstOrNull ??
          (throw FormatException('"$name" cannot be "$text" in a song.'));
    }

    final pitchClass = field<int>('key');
    final bpm = field<int>('bpm');
    if (pitchClass < 0 || pitchClass > 11) {
      throw const FormatException('"key" must be from 0 (C) to 11 (B).');
    }
    if (bpm <= 0) throw const FormatException('"bpm" must be positive.');
    return ExampleSong(
      field<String>('title'),
      json['artist'] == null ? '' : field<String>('artist'),
      pitchClass,
      named('progression', Progression.values, (p) => p.name),
      bpm,
      named('style', DroneStyle.values, (s) => s.name),
      signature: json['signature'] == null
          ? TimeSignature.fourFour
          : named('signature', TimeSignature.all, (s) => s.label),
      subdivision: json['subdivision'] == null
          ? null
          : named<Subdivision>('subdivision', Subdivision.values, (s) => s.id),
      backbeat: json['backbeat'] == null ? null : field<bool>('backbeat'),
    );
  }

  final String title;

  /// Who wrote it or made it known: the artist of the famous recording, or
  /// for a jazz standard its composer ("Miles Davis"); may be empty.
  final String artist;

  /// The key, in semitones above C.
  final int pitchClass;
  final Progression progression;

  /// The tempo, counted in the beats of [signature].
  final int bpm;

  /// The metronome's time signature: 4/4, but 2/4 for a song whose chords
  /// change every half bar, so that each chord still lasts one bar.
  final TimeSignature signature;

  /// How the piano plays it, as the song is played: a jazz standard over
  /// a walking bass, the bossa nova arpeggiated, the slow anthem held a
  /// bar, the rest struck on every beat (a shuffle blues is not walked).
  final DroneStyle style;

  /// What fills each beat of the metronome; null leaves the player's.
  final Subdivision? subdivision;

  /// Whether the click falls on 2 and 4 only; null leaves the player's.
  final bool? backbeat;

  /// The song as JSON, with the names the actions use; the fields left to
  /// the player are left out.
  Map<String, Object> toJson() => {
    'title': title,
    if (artist.isNotEmpty) 'artist': artist,
    'key': pitchClass,
    'progression': progression.name,
    'bpm': bpm,
    'style': style.name,
    'signature': signature.label,
    if (subdivision case final s?) 'subdivision': s.id,
    'backbeat': ?backbeat,
  };
}

/// The songs offered, in the order of the progression menu; none is in
/// D♭ or G♭, so there is no spelling to choose.
const exampleSongs = [
  ExampleSong(
    'Stand by Me',
    'Ben E. King',
    9,
    Progression.oneSixFourFive,
    118,
    DroneStyle.beat,
  ),
  ExampleSong(
    'With or Without You',
    'U2',
    2,
    Progression.oneFiveSixFour,
    110,
    DroneStyle.held,
  ),
  ExampleSong(
    'Hit the Road Jack',
    'Ray Charles',
    9,
    Progression.andalusian,
    168,
    DroneStyle.beat,
  ),
  ExampleSong(
    'Sweet Home Chicago',
    'Robert Johnson',
    4,
    Progression.blues,
    100,
    DroneStyle.beat,
  ),
  ExampleSong(
    'Mr. P.C.',
    'John Coltrane',
    0,
    Progression.minorBlues,
    160,
    DroneStyle.walking,
  ),
  ExampleSong(
    'Tune Up',
    'Miles Davis',
    2,
    Progression.twoFiveOne,
    160,
    DroneStyle.walking,
  ),
  ExampleSong(
    'Blue Bossa',
    'Kenny Dorham',
    0,
    Progression.minorTwoFiveOne,
    140,
    DroneStyle.arpeggio,
  ),
  // Two chords a bar in 4/4, so one a bar in 2/4: B♭ G7 Cm7 F7, the first
  // two bars of the A section, over and over.
  ExampleSong(
    'I Got Rhythm',
    'George Gershwin',
    10,
    Progression.oneSixTwoFive,
    160,
    DroneStyle.walking,
    signature: TimeSignature.twoFour,
  ),
  ExampleSong(
    'Autumn Leaves',
    'Joseph Kosma',
    7,
    Progression.circleOfFifths,
    120,
    DroneStyle.walking,
  ),
];
