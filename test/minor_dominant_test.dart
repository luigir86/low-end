import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/pitch.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/walking_bass.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/harmony/harmony_names.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:low_end/l10n/app_localizations.dart';

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

/// The piano's chords of a progression in C, as Harmony plays them.
List<PianoChord> _chords(Progression p) => [
  for (final step in p.steps)
    [
      48 + step.offset,
      ...[
        for (final s in step.quality.semitones)
          60 + (step.offset + s - 60) % 12,
      ]..sort(),
    ],
];

void main() {
  test('the V of a minor key is a 7♭9: major third, perfect fifth, minor '
      'seventh and flat ninth', () {
    expect(ChordQuality.dominantFlat9.semitones, [4, 7, 10, 13]);
    expect(ChordQuality.dominantFlat9.ratios, [
      1,
      5 / 4,
      3 / 2,
      16 / 9,
      32 / 15,
    ]);
    // Minor II–V–I in C: Dm7♭5 G7♭9 Cm7 Cm7.
    expect(
      [for (final s in Progression.minorTwoFiveOne.steps) s.quality],
      [
        ChordQuality.halfDiminished,
        ChordQuality.dominantFlat9,
        ChordQuality.minor7,
        ChordQuality.minor7,
      ],
    );
    // The minor blues: both its V chords.
    final blues = Progression.minorBlues.steps;
    expect(blues[9].quality, ChordQuality.dominantFlat9);
    expect(blues[11].quality, ChordQuality.dominantFlat9);
    // The major II–V–I keeps its plain G7.
    expect(Progression.twoFiveOne.steps[1].quality, ChordQuality.dominant);
  });

  test('G7♭9 is written G7♭9, its ♭9 as A♭', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      chordSymbol(
        (root: 7, quality: ChordQuality.dominantFlat9),
        'G',
        NoteNames.letters,
      ),
      'G7♭9',
    );
    expect(chordName(l10n, ChordQuality.dominantFlat9), contains('7♭9'));
    // A♭ is a letter above G: the ninth.
    expect(ChordQuality.dominantFlat9.letterSteps.last % 7, 1);
  });

  group('in a minor II–V–I in C', () {
    late SilentToneOutput tone;
    late SilentPianoOutput piano;
    late DroneController drone;

    setUp(() {
      tone = SilentToneOutput();
      piano = SilentPianoOutput();
      drone = DroneController(tone, clock: _Clock(), piano: piano);
      drone
        ..setVoicing(DroneVoicing.progression)
        ..setProgression(Progression.minorTwoFiveOne)
        ..setStyle(DroneStyle.beat);
    });

    test('the piano plays G7♭9: G, then D F A♭ B close together', () async {
      await drone.tapNote(0);
      expect(piano.chords![1], [55, 62, 65, 68, 71]);
    });

    testWidgets('the held tone leaves the ♭9 out: a half step that beats', (
      tester,
    ) async {
      drone.setContinuous(true);
      await drone.tapNote(0);
      await tester.pump(const Duration(seconds: 2));
      expect(drone.step, 1);
      // Bar 2 of the held tone: a plain G7, G B D F.
      expect(drone.currentChord?.quality, ChordQuality.dominant);
      final g = Note(7, DroneController.rootOctave).frequency();
      expect(tone.frequencies, hasLength(4));
      expect(tone.frequencies.first, closeTo(g, 1e-6));
      expect(tone.frequencies.last, closeTo(g * 16 / 9, 1e-6));
      // The piano again: the ♭9 (A♭, 68) comes back.
      drone.setContinuous(false);
      await tester.pump();
      expect(piano.chords![1], contains(68));
      await drone.stop();
    });
  });

  group('the walking bass on a 7♭9', () {
    test('walks the harmonic minor from its fifth', () {
      final s = WalkingBass.scaleOf({0, 4, 7, 10, 1});
      // G A♭ B C D E♭ F, over G7♭9 in C minor.
      expect(s.scale, [0, 1, 4, 5, 7, 8, 10]);
      expect(s.second, 1);
      expect(s.sixth, 8);
      // A plain 7 still walks the mixolydian.
      expect(WalkingBass.scaleOf({0, 4, 7, 10}).scale, [0, 2, 4, 5, 7, 9, 10]);
    });

    test('never walks A or E natural over G7♭9 in C minor', () {
      final loop = _chords(Progression.minorTwoFiveOne);
      // Four times round, so that every pattern has its turn.
      final chords = [for (var i = 0; i < 4; i++) ...loop];
      final line = WalkingBass.line(chords, TimeSignature.fourFour);
      for (var bar = 1; bar < chords.length; bar += 4) {
        for (final n in line) {
          // The last beat leads into Cm7 and may be a half step from it.
          if (n.at < bar * 4 || n.at >= bar * 4 + 3) continue;
          expect(
            n.midi % 12,
            isNot(anyOf(9, 4)),
            reason: 'bar $bar at ${n.at}',
          );
        }
      }
    });
  });
}
