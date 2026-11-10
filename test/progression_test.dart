import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/pitch.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:low_end/features/metronome/time_signature.dart';

/// A bar clock set by hand, as the metronome would be.
class _Clock extends ChangeNotifier implements BarClock {
  @override
  Duration barLength = const Duration(seconds: 2);

  @override
  double? barPhase;

  int bpm = 120;

  @override
  int get soundingBpm => bpm;

  @override
  TimeSignature signature = TimeSignature.fourFour;
}

/// The frequencies sounding, each to a millionth of a hertz.
Matcher _sounds(List<double> hz) => pairwiseCompare<double, double>(
  hz,
  (a, b) => (a - b).abs() < 1e-6,
  'within 1e-6 Hz of',
);

double _hz(int pitchClass) =>
    Note(pitchClass, DroneController.rootOctave).frequency();

void main() {
  late SilentToneOutput output;
  late _Clock clock;
  late DroneController drone;

  setUp(() {
    output = SilentToneOutput();
    clock = _Clock();
    drone = DroneController(output, clock: clock);
  });

  // testWidgets for its fake clock: the bar timers run without waiting.
  testWidgets('II–V–I in C plays Dm7, G7, Cmaj7 and A7, one chord a bar', (
    tester,
  ) async {
    drone.setVoicing(DroneVoicing.progression);
    drone.setProgression(Progression.twoFiveOne);
    await drone.tapNote(0); // C
    await tester.pump();
    expect(drone.currentChord?.root, 2);
    expect(
      output.frequencies,
      _sounds([_hz(2), _hz(2) * 6 / 5, _hz(2) * 3 / 2, _hz(2) * 9 / 5]),
    );
    expect(drone.chordTones, {5, 9, 0}); // F, A and C
    // The numerals stay on their notes while it plays.
    expect(drone.degreeLabels, {2: 'II', 7: 'V', 0: 'I', 9: 'VI'});
    // Every chord is made ready at the start.
    expect(output.prepared, hasLength(4));

    await tester.pump(const Duration(seconds: 2));
    expect(drone.step, 1);
    expect(output.frequencies.first, closeTo(_hz(7), 1e-9)); // G
    // The dominant has its seventh.
    final g = _hz(7);
    expect(output.frequencies, _sounds([g, g * 5 / 4, g * 3 / 2, g * 16 / 9]));

    await tester.pump(const Duration(seconds: 2));
    expect(drone.step, 2);
    expect(output.frequencies.first, closeTo(_hz(0), 1e-9)); // C

    // Then A7, which turns it around to Dm7: four bars, as a phrase is.
    await tester.pump(const Duration(seconds: 2));
    expect(drone.step, 3);
    expect(output.frequencies.first, closeTo(_hz(9), 1e-9));
    expect(drone.chordTones, {1, 4, 7}); // C♯, E and G

    // And round again.
    await tester.pump(const Duration(seconds: 2));
    expect(drone.step, 0);
    await drone.stop();
  });

  test('on the piano, a bar timer late by more than a bar shows the chord '
      'the sound is on', () async {
    // Bars of 0.2 s, real time: the piano's chords follow its own clock.
    clock.barLength = const Duration(milliseconds: 200);
    final piano = SilentPianoOutput();
    final harmony = DroneController(output, clock: clock, piano: piano)
      ..setVoicing(DroneVoicing.progression)
      ..setProgression(Progression.oneSixFourFive);
    await harmony.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(harmony.step, 0);
    // The screen's thread held up (a page in the background, a slow
    // phone): the bar timer comes some two bars late.
    sleep(const Duration(milliseconds: 450));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // About 0.52 s into the loop: the third bar.
    expect(harmony.step, 2);
    await harmony.stop();
    harmony.dispose();
  });

  testWidgets('changes chord on the metronome\'s "one"', (tester) async {
    clock.barPhase = 0.75; // A quarter of the bar still to go.
    drone.setVoicing(DroneVoicing.progression);
    await drone.tapNote(0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(drone.step, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(drone.step, 1, reason: 'half a second, then the bar line');
    await drone.stop();
  });

  testWidgets('a new key or progression starts again from its first chord', (
    tester,
  ) async {
    drone.setVoicing(DroneVoicing.progression);
    drone.setProgression(Progression.twoFiveOne);
    await drone.tapNote(0);
    await tester.pump(const Duration(seconds: 2));
    expect(drone.step, 1);
    drone.setPitchClass(7); // G: II is A minor.
    await tester.pump();
    expect(drone.step, 0);
    expect(drone.currentChord?.root, 9);
    drone.setProgression(Progression.blues);
    expect(drone.step, 0);
    expect(drone.progression.steps, hasLength(12));
    await drone.stop();
  });

  test('the chord types sound their pure intervals', () async {
    drone.setVoicing(DroneVoicing.chord);
    await drone.start();
    final a = _hz(9);
    expect(output.frequencies, _sounds([a, a * 5 / 4, a * 3 / 2]));
    final expected = {
      ChordQuality.minor: [6 / 5, 3 / 2],
      ChordQuality.dominant: [5 / 4, 3 / 2, 16 / 9],
      ChordQuality.dominantFlat9: [5 / 4, 3 / 2, 16 / 9, 32 / 15],
      ChordQuality.major7: [5 / 4, 3 / 2, 15 / 8],
      ChordQuality.minor7: [6 / 5, 3 / 2, 9 / 5],
      ChordQuality.halfDiminished: [6 / 5, 64 / 45, 16 / 9],
      ChordQuality.diminished: [6 / 5, 64 / 45],
      ChordQuality.sus4: [4 / 3, 3 / 2],
    };
    for (final e in expected.entries) {
      drone.setChord(e.key);
      await pumpEventQueue();
      expect(output.frequencies, _sounds([a, for (final r in e.value) a * r]));
    }
    await drone.stop();
  });

  test('the blues is all dominant sevenths', () async {
    drone
      ..setVoicing(DroneVoicing.progression)
      ..setProgression(Progression.blues)
      ..setPitchClass(0);
    expect(Progression.blues.steps.map((s) => s.quality).toSet(), {
      ChordQuality.dominant,
    });
    expect(drone.currentChord?.quality, ChordQuality.dominant);
    await drone.start();
    final c = _hz(0);
    expect(output.frequencies, _sounds([c, c * 5 / 4, c * 3 / 2, c * 16 / 9]));
    await drone.stop();
  });

  test('jazz progressions are in sevenths, the others in triads', () {
    drone
      ..setVoicing(DroneVoicing.progression)
      ..setProgression(Progression.twoFiveOne)
      ..setPitchClass(0);
    // II–V–I: Dm7, G7, Cmaj7.
    expect(drone.currentChord, (root: 2, quality: ChordQuality.minor7));
    for (final p in [Progression.oneFiveSixFour, Progression.oneSixFourFive]) {
      drone.setProgression(p);
      for (final s in p.steps.where(
        (s) => s.quality != ChordQuality.dominant,
      )) {
        expect(s.quality.semitones, hasLength(2), reason: p.name);
      }
    }
    for (final p in [Progression.oneSixTwoFive]) {
      for (final s in p.steps) {
        expect(s.quality.semitones, hasLength(3), reason: p.name);
      }
    }
  });

  test('the Andalusian cadence is a minor key: Am G F E', () {
    drone
      ..setVoicing(DroneVoicing.progression)
      ..setProgression(Progression.andalusian)
      ..setPitchClass(9);
    expect(drone.keyIsMinor, isTrue);
    expect(Progression.andalusian.steps.map((s) => (s.offset + 9) % 12), [
      9,
      7,
      5,
      4,
    ]);
    expect(drone.keyNotes, contains(7)); // G is in A minor.
  });

  group('chords are spelled as in their key', () {
    List<String> names(DroneController d, int key, Progression p) {
      d
        ..setVoicing(DroneVoicing.progression)
        ..setProgression(p)
        ..setPitchClass(key);
      return [
        for (var i = 0; i < p.steps.length; i++)
          spell(
            (key + p.steps[i].offset) % 12,
            d.letterAt(i),
            NoteNames.letters,
          ),
      ];
    }

    test('minor II–V–I in C♯ and F♯ minor', () {
      expect(names(drone, 1, Progression.minorTwoFiveOne), [
        'D♯',
        'G♯',
        'C♯',
        'C♯',
      ]);
      expect(names(drone, 6, Progression.minorTwoFiveOne), [
        'G♯',
        'C♯',
        'F♯',
        'F♯',
      ]);
    });

    test('I–VI–IV–V in F♯ has D♯ minor, not E♭', () {
      expect(names(drone, 6, Progression.oneSixFourFive), [
        'F♯',
        'D♯',
        'B',
        'C♯',
      ]);
    });

    test('the flat keys keep their flats', () {
      expect(names(drone, 10, Progression.twoFiveOne), ['C', 'F', 'B♭', 'G']);
      expect(names(drone, 3, Progression.oneFiveSixFour), [
        'E♭',
        'B♭',
        'C',
        'A♭',
      ]);
    });

    test('C♯ can be written D♭, and its chords follow: G♭, A♭', () {
      expect(drone.spelledFlat(1), isFalse);
      drone.toggleSpelling(1);
      expect(drone.spelledFlat(1), isTrue);
      expect(names(drone, 1, Progression.oneFiveSixFour), [
        'D♭',
        'A♭',
        'B♭',
        'G♭',
      ]);
      drone.toggleSpelling(6);
      expect(names(drone, 6, Progression.twoFiveOne), ['A♭', 'D♭', 'G♭', 'E♭']);
      // In solfège too.
      expect(spell(6, drone.keyLetter, NoteNames.solfege), 'Sol♭');
      // Only C♯/D♭ and F♯/G♭ change: E♭ stays E♭.
      drone.toggleSpelling(3);
      expect(drone.spelledFlat(3), isFalse);
      drone.toggleSpelling(1);
      drone.setPitchClass(1);
      expect(spell(1, drone.keyLetter, NoteNames.letters), 'C♯');
    });
  });

  test('minor II–V–I has a half-diminished II', () {
    final steps = Progression.minorTwoFiveOne.steps;
    expect(steps.first.quality, ChordQuality.halfDiminished);
    expect(ChordQuality.halfDiminished.semitones, [3, 6, 10]);
    expect(steps[2].quality, ChordQuality.minor7);
  });

  test('the minor II–V–I rests on the I for two bars, with no turnaround', () {
    // In C minor Dm7♭5 G7♭9 Cm7 Cm7: A♭7 would want G, not Dm7♭5.
    final steps = Progression.minorTwoFiveOne.steps;
    expect(steps.length, 4);
    for (final step in steps.sublist(2)) {
      expect(
        (step.offset, step.quality, step.numeral),
        (0, ChordQuality.minor7, 'I'),
      );
    }
  });

  test('the major jazz loops turn around on a VI7, not resting on the I', () {
    // In C: A7 leads back to Dm7.
    final major = Progression.twoFiveOne.steps.last;
    expect((major.offset, major.quality), (9, ChordQuality.dominant));
    final circle = Progression.circleOfFifths.steps;
    expect(
      (circle.last.offset, circle.last.quality),
      (9, ChordQuality.dominant),
    );
    // Each of them ends on the dominant of its first chord.
    for (final p in [Progression.twoFiveOne, Progression.circleOfFifths]) {
      expect(
        (p.steps.first.offset + 7) % 12,
        p.steps.last.offset,
        reason: p.name,
      );
    }
  });

  test('every progression lasts 4, 8 or 12 bars, as phrases do', () {
    for (final p in Progression.values) {
      expect([4, 8, 12], contains(p.steps.length), reason: p.name);
    }
  });

  test('the circle of fifths in G is Autumn Leaves: Am7 D7 Gmaj7 Cmaj7 F♯m7♭5 B7 Em7', () {
    drone
      ..setVoicing(DroneVoicing.progression)
      ..setProgression(Progression.circleOfFifths)
      ..setPitchClass(7);
    const p = Progression.circleOfFifths;
    expect(
      [
        for (var i = 0; i < p.steps.length; i++)
          spell(
            (7 + p.steps[i].offset) % 12,
            drone.letterAt(i),
            NoteNames.letters,
          ),
      ],
      ['A', 'D', 'G', 'C', 'F♯', 'B', 'E', 'E'],
    );
    expect(p.steps[4].quality, ChordQuality.halfDiminished);
    // E7♭9: the V of A minor.
    expect(p.steps[5].quality, ChordQuality.dominantFlat9);
    // Em7 for a bar, then E7 back to Am7.
    expect(p.steps[6].quality, ChordQuality.minor7);
    expect(p.steps[7].quality, ChordQuality.dominant);
    expect(drone.keyIsMinor, isFalse);
  });

  test('the minor blues in C minor has A♭7 and G7 in bars 9 and 10', () {
    drone
      ..setVoicing(DroneVoicing.progression)
      ..setProgression(Progression.minorBlues)
      ..setPitchClass(0);
    expect(drone.keyIsMinor, isTrue);
    const p = Progression.minorBlues;
    expect(
      spell((0 + p.steps[8].offset) % 12, drone.letterAt(8), NoteNames.letters),
      'A♭',
    );
    expect(p.steps[8].quality, ChordQuality.dominant);
    expect(p.steps[9].offset, 7);
    expect(p.steps.first.quality, ChordQuality.minor7);
  });
}
