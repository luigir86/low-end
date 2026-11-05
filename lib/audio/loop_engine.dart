import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'soloud_engine.dart';

/// The few calls of the sound engine that the looping bars use (see
/// BarLoopPlayer and LoopTransport), named as SoLoud names them. Behind
/// this interface the loops, their bar-line entries, tails and fades can be
/// tested on a fake engine with its own clock, with no sound card.
abstract interface class LoopEngine {
  /// The SoLoud engine of the app.
  static const LoopEngine soloud = _SoLoudLoopEngine();

  /// Starts the engine if it is not yet (see ensureSoLoud).
  Future<void> ensure();

  Future<AudioSource> loadMem(String path, Uint8List bytes);
  Duration getLength(AudioSource source);
  Future<void> disposeSource(AudioSource source);

  /// The engine's own clock, the time base of the scheduled calls.
  Duration getEngineTime();

  SoundHandle play(
    AudioSource source, {
    double volume = 1,
    bool paused = false,
    bool looping = false,
  });

  /// Starts [source] at [atTime] on the engine's clock, to the sample.
  SoundHandle playScheduled(
    AudioSource source,
    Duration atTime, {
    double volume = 1,
    bool looping = false,
  });

  bool getIsValidVoiceHandle(SoundHandle handle);
  Duration getPosition(SoundHandle handle);
  void seek(SoundHandle handle, Duration time);
  void setPause(SoundHandle handle, bool pause);
  void setVolume(SoundHandle handle, double volume);

  /// From the volume [handle] has now to [to] over [time].
  void fadeVolume(SoundHandle handle, double to, Duration time);

  /// The same, starting at [atTime] on the engine's clock; then stops it
  /// if [thenStop].
  void fadeScheduled(
    SoundHandle handle,
    Duration atTime,
    double to,
    Duration time, {
    bool thenStop = false,
  });

  /// Stops [handle] at [atTime] on the engine's clock, to the sample.
  void stopScheduled(SoundHandle handle, Duration atTime);

  /// Stops [handle] [time] from now.
  void scheduleStop(SoundHandle handle, Duration time);

  Future<void> stop(SoundHandle handle);
}

class _SoLoudLoopEngine implements LoopEngine {
  const _SoLoudLoopEngine();

  SoLoud get _soloud => SoLoud.instance;

  @override
  Future<void> ensure() => ensureSoLoud();

  @override
  Future<AudioSource> loadMem(String path, Uint8List bytes) =>
      _soloud.loadMem(path, bytes);

  @override
  Duration getLength(AudioSource source) => _soloud.getLength(source);

  @override
  Future<void> disposeSource(AudioSource source) =>
      _soloud.disposeSource(source);

  @override
  Duration getEngineTime() => _soloud.getEngineTime();

  @override
  SoundHandle play(
    AudioSource source, {
    double volume = 1,
    bool paused = false,
    bool looping = false,
  }) => _soloud.play(source, volume: volume, paused: paused, looping: looping);

  @override
  SoundHandle playScheduled(
    AudioSource source,
    Duration atTime, {
    double volume = 1,
    bool looping = false,
  }) => _soloud.playScheduled(source, atTime, volume: volume, looping: looping);

  @override
  bool getIsValidVoiceHandle(SoundHandle handle) =>
      _soloud.getIsValidVoiceHandle(handle);

  @override
  Duration getPosition(SoundHandle handle) => _soloud.getPosition(handle);

  @override
  void seek(SoundHandle handle, Duration time) => _soloud.seek(handle, time);

  @override
  void setPause(SoundHandle handle, bool pause) =>
      _soloud.setPause(handle, pause);

  @override
  void setVolume(SoundHandle handle, double volume) =>
      _soloud.setVolume(handle, volume);

  @override
  void fadeVolume(SoundHandle handle, double to, Duration time) =>
      _soloud.fadeVolume(handle, to, time);

  @override
  void fadeScheduled(
    SoundHandle handle,
    Duration atTime,
    double to,
    Duration time, {
    bool thenStop = false,
  }) => _soloud.fadeScheduled(handle, atTime, to, time, thenStop: thenStop);

  @override
  void stopScheduled(SoundHandle handle, Duration atTime) =>
      _soloud.stopScheduled(handle, atTime);

  @override
  void scheduleStop(SoundHandle handle, Duration time) =>
      _soloud.scheduleStop(handle, time);

  @override
  Future<void> stop(SoundHandle handle) => _soloud.stop(handle);
}
