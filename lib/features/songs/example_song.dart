import '../metronome/metronome_controller.dart';
import '../harmony/drone_controller.dart';
import '../harmony/harmony.dart';

/// Applies [song] as a preset: its key, progression and style on the piano
/// (the held tone gives way to it), and on the metronome its time signature
/// and tempo, and its subdivision and click on 2 and 4 if it has them.
/// What touching it in the list of example songs does, and the `song` of
/// the actions; the player may change any of it afterwards. Playing, the
/// old song goes on, quieter, to the bar line, and the new one comes in
/// there (RF-ARM-15). With the metronome playing too, the clicks keep the
/// old tempo until that same bar line and change with the piano, as a band
/// does, instead of jumping at the touch.
void applySong(
  ExampleSong song, {
  required DroneController drone,
  required MetronomeController metronome,
}) {
  void harmony() => drone
    ..setPitchClass(song.pitchClass)
    ..setProgression(song.progression)
    ..setVoicing(DroneVoicing.progression)
    ..setContinuous(false)
    ..setStyle(song.style);
  void clicks() {
    metronome
      ..setSignature(song.signature)
      ..setBpm(song.bpm);
    if (song.subdivision case final s?) metronome.setSubdivision(s);
    if (song.backbeat case final b?) metronome.setBackbeat(b);
  }

  if (drone.isPlaying && metronome.isPlaying) {
    // The piano first: it picks the bar line, on the clicks still at the
    // old tempo; then the clicks are told to change there too. The piano's
    // new loop is mixed after this, at the new tempo.
    drone.applyAll(() {
      harmony();
    });
    metronome.changeAtBarLine(clicks);
    return;
  }
  // All at once: the piano gets one loop ready, for the whole song.
  drone.applyAll(() {
    harmony();
    clicks();
  });
}
