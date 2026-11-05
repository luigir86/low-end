/// The sample rate of every sound the app makes: the one phones play at
/// natively, so that nothing is resampled on the way out, and the one the
/// piano and the double bass were recorded at.
const audioSampleRate = 48000;

/// Samples in one pulse at [bpm] pulses a minute, whole: every loop is cut
/// into pulses of this length, so that the click and the piano agree to the
/// sample.
int pulseFrames(int bpm) => (audioSampleRate * 60 / bpm).round();

/// A bar of [pulses] pulses at [bpm], as the engine plays it: whole
/// samples.
Duration barDuration(int bpm, int pulses) => Duration(
  microseconds: pulseFrames(bpm) * pulses * 1000000 ~/ audioSampleRate,
);
