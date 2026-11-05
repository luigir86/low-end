/// A section that plays a sound of its own, started and stopped from the
/// middle of its dial: the metronome or the Harmony.
abstract interface class SoundSection {
  bool get isPlaying;
  Future<void> start();
  Future<void> stop();
}
