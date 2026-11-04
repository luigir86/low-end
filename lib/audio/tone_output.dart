import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'drone_sound.dart';
import 'off_thread.dart';
import 'soloud_engine.dart';

/// Plays one or more sustained tones at once, as one sound.
///
/// Kept behind an interface so the rest of the app can be tested without a
/// real audio device.
abstract class ToneOutput {
  /// Starts (or retunes, if already playing) the given frequencies in Hz.
  /// [gains] holds one relative volume per frequency, 0 to 1.
  Future<void> play(
    List<double> frequencies,
    List<double> gains,
    double volume,
  );

  /// Gets [sounds] (frequencies and gains, as for [play]) ready to play at
  /// once later, such as the chords of a progression.
  Future<void> prepare(List<(List<double>, List<double>)> sounds);

  Future<void> stop();
}

/// [ToneOutput] backed by the SoLoud audio engine.
///
/// Plays the tone made by DroneSound as a seamless loop. Calls to [play]
/// are expected one at a time (DroneController waits for each one to
/// finish before the next).
class SoLoudToneOutput implements ToneOutput {
  static const _fade = Duration(milliseconds: 80);

  /// The tones built and loaded so far, by [_key].
  final _sources = <String, Future<AudioSource>>{};
  SoundHandle? _handle;
  String? _playing;

  SoLoud get _soloud => SoLoud.instance;

  static String _key(List<double> frequencies, List<double> gains) =>
      '$frequencies $gains';

  /// Static, so that the closure sent to the isolate cannot capture `this`
  /// (and with it the futures of [_sources], which cannot be sent).
  static Future<Uint8List> _build(
    List<double> frequencies,
    List<double> gains,
  ) => offThread(() => DroneSound.loopWav(frequencies, gains));

  /// The loaded tone for these frequencies, built the first time it is
  /// asked for.
  Future<AudioSource> _source(List<double> frequencies, List<double> gains) =>
      _sources.putIfAbsent(_key(frequencies, gains), () async {
        // The engine starts and warms up while the tone is built; its sound
        // is woken by play.
        final engine = prepareSoLoud()..ignore();
        // Building the tone takes a moment: away from the screen's thread.
        final wav = await _build(frequencies, gains);
        await engine;
        return _soloud.loadMem('drone.wav', wav);
      });

  @override
  Future<void> play(
    List<double> frequencies,
    List<double> gains,
    double volume,
  ) async {
    assert(gains.length == frequencies.length);
    final key = _key(frequencies, gains);
    if (_handle != null && key == _playing) {
      _setVolume(volume);
      return;
    }
    // In a web page the engine's sound may be held (before the first
    // touch, asleep, interrupted): it is woken while the tone is got.
    final awake = ensureSoLoud()..ignore();
    final AudioSource source;
    try {
      source = await _source(frequencies, gains);
    } catch (_) {
      // Let the next call try again.
      _sources.remove(key);
      rethrow;
    }
    await awake;
    final handle = _soloud.play(source, volume: 0, looping: true);
    // The new tone fades in while the old one fades out: no click, no gap.
    _soloud.fadeVolume(handle, volume, _fade);
    final old = _handle;
    _handle = handle;
    _playing = key;
    await _fadeOut(old);
  }

  @override
  Future<void> prepare(List<(List<double>, List<double>)> sounds) async {
    final keep = {for (final (f, g) in sounds) _key(f, g), ?_playing};
    // Free the tones no longer needed, such as another key's chords.
    for (final key in _sources.keys.toList()) {
      if (!keep.contains(key)) _dispose(key);
    }
    await Future.wait([for (final (f, g) in sounds) _source(f, g)]);
  }

  void _setVolume(double volume) {
    final handle = _handle;
    if (handle != null) _soloud.fadeVolume(handle, volume, _fade);
  }

  @override
  Future<void> stop() async {
    final handle = _handle;
    _handle = null;
    _playing = null;
    await _fadeOut(handle);
    for (final key in _sources.keys.toList()) {
      _dispose(key);
    }
  }

  /// Fades [handle] out and stops it, without a click.
  Future<void> _fadeOut(SoundHandle? handle) async {
    if (handle == null) return;
    _soloud.fadeVolume(handle, 0, _fade);
    _soloud.scheduleStop(handle, _fade);
    await Future<void>.delayed(_fade);
  }

  void _dispose(String key) {
    final source = _sources.remove(key);
    source?.then(_soloud.disposeSource).catchError((Object _) {});
  }
}

/// [ToneOutput] that makes no sound; used where audio is unavailable.
@visibleForTesting
class SilentToneOutput implements ToneOutput {
  List<double> frequencies = const [];
  double volume = 0;

  /// What [prepare] was last asked for.
  List<(List<double>, List<double>)> prepared = const [];

  @override
  Future<void> play(List<double> f, List<double> gains, double v) async {
    frequencies = f;
    volume = v;
  }

  @override
  Future<void> prepare(List<(List<double>, List<double>)> sounds) async =>
      prepared = sounds;

  @override
  Future<void> stop() async => frequencies = const [];
}
