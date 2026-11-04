import '../../metronome/metronome_controller.dart';
import '../../metronome/time_signature.dart';
import 'drone_controller.dart';
import 'harmony.dart';

/// Applies [song] as a preset: its key, progression and style on the piano
/// (the held tone gives way to it), and its tempo in 4/4 on the metronome.
/// What touching it in the list of example songs does, and the `song` of
/// the actions; the player may change any of it afterwards.
void applySong(
  ExampleSong song, {
  required DroneController drone,
  required MetronomeController metronome,
}) {
  drone
    ..setPitchClass(song.pitchClass)
    ..setProgression(song.progression)
    ..setVoicing(DroneVoicing.progression)
    ..setContinuous(false)
    ..setStyle(song.style);
  metronome
    ..setSignature(TimeSignature.fourFour)
    ..setBpm(song.bpm);
}
