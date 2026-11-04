import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'web_audio_engine.dart';

/// How long the engine plays silence after it starts, before the first
/// sound: the phone's audio output is still ramping up (routing to the
/// speaker, fading in), and a click that begins at that moment comes out as
/// a double "tra-ta" instead of one tick. In a browser the page's audio
/// output is already running when the engine starts, so a shorter wait
/// does: every first sound comes 0.2 s sooner there.
const engineWarmUp = Duration(milliseconds: kIsWeb ? 100 : 300);

/// The engine's sample rate: the one phones play at natively, so that
/// nothing is resampled on the way out, and the one the piano was recorded
/// at.
const engineSampleRate = 48000;

/// Frames the engine mixes at a time (SoLoud's default): it is also the
/// period of the audio device, so a sound comes out about that much later
/// than it is mixed (see [outputLatencyFor]).
const engineBufferFrames = 2048;

/// How long the engine's buffer holds a sound before it goes out.
const engineBufferLatency = Duration(
  microseconds: engineBufferFrames * 1000000 ~/ engineSampleRate,
);

/// Where the sound comes out, for [outputLatencyFor].
enum AudioOutputKind { speaker, wired, bluetooth, bleAudio }

/// About how long after it is mixed a sound is heard through [kind]: the
/// engine's buffer and the device's own path, and, over Bluetooth, the
/// radio. The screen shows the beat that much later, so the light and the
/// click come together.
Duration outputLatencyFor(AudioOutputKind kind) {
  return engineBufferLatency +
      switch (kind) {
        AudioOutputKind.speaker ||
        AudioOutputKind.wired => const Duration(milliseconds: 20),
        AudioOutputKind.bleAudio => const Duration(milliseconds: 100),
        AudioOutputKind.bluetooth => const Duration(milliseconds: 160),
      };
}

/// Starts an audio engine once, and lets the first sound wait until it has
/// warmed up. Tried again on the next call if it failed.
@visibleForTesting
class EngineStarter {
  EngineStarter(this._start, {this.warmUp = engineWarmUp});

  final Future<void> Function() _start;
  final Duration warmUp;
  Future<void>? _ready;

  Future<void> ensure() => _ready ??=
      (() async {
        await _start();
        await Future<void>.delayed(warmUp);
      })().catchError((Object error) {
        _ready = null;
        throw error;
      });
}

final _engine = EngineStarter(() async {
  final soloud = SoLoud.instance;
  if (soloud.isInitialized) return;
  // The web page loads the engine after the first frame.
  await webAudioEngineLoaded();
  await soloud.init(
    sampleRate: engineSampleRate,
    bufferSize: engineBufferFrames,
  );
  // A safety net on the whole mix: the piano, the click and the tone never
  // go past full scale together, however they pile up. With no drive (its
  // "threshold" is a boost, here 0 dB) it leaves alone everything below
  // the ceiling, and it looks 1 ms ahead, so it never bends an attack.
  final limiter = soloud.filters.limiterFilter;
  limiter.activate();
  limiter.threshold.value = 0;
  limiter.outputCeiling.value = -0.3;
});

/// Starts the SoLoud audio engine once for the whole app, so the drone and
/// the metronome never start it twice at the same time. Tried again on the
/// next call if it failed. The first call comes back once the engine has
/// warmed up (see [engineWarmUp]); later ones at once, unless in a web page
/// the browser holds the engine's sound: it is then woken, and warms up
/// again (see webAudioAwake).
Future<void> ensureSoLoud() async {
  await _engine.ensure();
  await webAudioAwake(engineWarmUp);
}

/// Starts the engine without asking for its sound: in a web page before any
/// touch, where the browser holds it silent until one (see LowEndApp).
Future<void> prepareSoLoud() => _engine.ensure();
