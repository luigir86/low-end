import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';

void main() {
  keyTests();
  late SilentToneOutput output;
  late DroneController drone;

  setUp(() {
    output = SilentToneOutput();
    drone = DroneController(output);
  });

  test('a note key plays, switches and stops', () async {
    await drone.tapNote(2); // D
    expect(drone.isPlaying, isTrue);
    // Always octave 3: D3.
    expect(output.frequencies.single, closeTo(146.83, 0.01));

    await drone.tapNote(9); // Another key switches to A3.
    expect(drone.isPlaying, isTrue);
    expect(output.frequencies.single, closeTo(220, 0.01));

    await drone.tapNote(9); // The lit key again stops it.
    expect(drone.isPlaying, isFalse);
    expect(output.frequencies, isEmpty);
  });

  test('plays chords in pure intervals', () async {
    drone.setVoicing(DroneVoicing.chord);
    await drone.start();
    final root = drone.frequency;
    expect(output.frequencies, [root, root * 5 / 4, root * 3 / 2]);

    drone.setChord(ChordQuality.minor);
    await _settle();
    expect(output.frequencies, [root, root * 6 / 5, root * 3 / 2]);

    drone.setChord(ChordQuality.dominant);
    await _settle();
    expect(output.frequencies, [
      root,
      root * 5 / 4,
      root * 3 / 2,
      root * 16 / 9,
    ]);

    drone.setVoicing(DroneVoicing.root);
    await _settle();
    expect(output.frequencies, [root]);
  });

  test('retunes while playing when the reference pitch changes', () async {
    await drone.start();
    drone.setReferencePitch(442);
    await _settle();
    expect(
      output.frequencies.single,
      closeTo(221, 0.001),
    ); // A3, with A4 at 442
  });

  test('names the other notes of the chord', () {
    drone.setPitchClass(9); // A
    expect(drone.chordTones, isEmpty, reason: 'root only');
    drone.setVoicing(DroneVoicing.chord);
    expect(drone.chordTones, {1, 4}); // C# and E
    drone.setChord(ChordQuality.minor);
    expect(drone.chordTones, {0, 4}); // C and E
    drone.setChord(ChordQuality.dominant);
    expect(drone.chordTones, {1, 4, 7}); // C#, E and G
  });
}

/// Lets queued sound changes reach the output: the controller applies them
/// one after the other (see DroneController._sync).
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void keyTests() {
  late DroneController drone;
  setUp(() => drone = DroneController(SilentToneOutput()));

  test('only a progression shows a key, with its seven notes', () async {
    expect(drone.keyNotes, isEmpty);
    drone.setVoicing(DroneVoicing.progression);
    await drone.tapNote(0); // C major: the white keys.
    expect(drone.keyNotes, {0, 2, 4, 5, 7, 9, 11});
    await drone.tapNote(9); // A minor would share them, but it is major here.
    expect(drone.keyNotes, {9, 11, 1, 2, 4, 6, 8});
    drone.setProgression(Progression.minorTwoFiveOne);
    expect(drone.keyNotes, {9, 11, 0, 2, 4, 5, 7}); // A natural minor.
  });

  test('the notes of the key are written with a letter each', () async {
    drone.setVoicing(DroneVoicing.progression);
    drone.toggleSpelling(6); // G♭ rather than F♯.
    await drone.tapNote(6);
    // G♭ major has C♭ (letter 0) and not B, and F (3) and not E♯.
    expect(drone.keyLetterOf(6), 4); // G
    expect(drone.keyLetterOf(11), 0); // C♭
    expect(drone.keyLetterOf(5), 3); // F
    expect(drone.keyLetterOf(0), isNull); // C is not in the key
  });
}
