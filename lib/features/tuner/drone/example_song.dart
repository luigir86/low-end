import '../../metronome/metronome_controller.dart';
import 'drone_controller.dart';
import 'harmony.dart';

/// Applies [song] as a preset: its key, progression and style on the piano
/// (the held tone gives way to it), and on the metronome its time signature
/// and tempo, and its subdivision and click on 2 and 4 if it has them.
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
    ..setSignature(song.signature)
    ..setBpm(song.bpm);
  if (song.subdivision case final s?) metronome.setSubdivision(s);
  if (song.backbeat case final b?) metronome.setBackbeat(b);
}
