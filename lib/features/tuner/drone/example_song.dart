import '../../metronome/metronome_controller.dart';
import '../../metronome/time_signature.dart';
import 'drone_controller.dart';
import 'harmony.dart';

/// Sets the key, the progression and the tempo of [song], and the walking
/// bass for a jazz standard (see [DroneController.setSongStyle]): what
/// touching it in the list of example songs does, and the `song` of the
/// actions.
void applySong(
  ExampleSong song, {
  required DroneController drone,
  required MetronomeController metronome,
}) {
  drone
    ..setPitchClass(song.pitchClass)
    ..setProgression(song.progression)
    ..setVoicing(DroneVoicing.progression)
    ..setSongStyle(walking: song.walking);
  metronome
    ..setSignature(TimeSignature.fourFour)
    ..setBpm(song.bpm);
}
