import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:low_end/audio/loop_engine.dart';

/// A sound engine with no sound and its own clock, moved on by [advance]:
/// voices know where they are, how loud, and when they stop, as SoLoud's
/// would, so that the looping bars can be followed sample by sample.
class FakeLoopEngine implements LoopEngine {
  /// The engine's clock.
  Duration now = Duration.zero;

  final voices = <SoundHandle, FakeVoice>{};
  final _lengths = <AudioSource, Duration>{};
  final loaded = <String>[];
  final disposed = <AudioSource>{};
  var _next = 1;

  void advance(Duration time) => now += time;

  /// The voices that play [name].
  Iterable<FakeVoice> playing(String name) =>
      voices.values.where((v) => v.name == name && v.isValidAt(now));

  @override
  Future<void> ensure() async {}

  @override
  Future<AudioSource> loadMem(String path, Uint8List bytes) async {
    final header = ByteData.sublistView(bytes);
    final rate = header.getUint32(24, Endian.little);
    final block = header.getUint16(32, Endian.little);
    final data = header.getUint32(40, Endian.little);
    final source = _FakeSource(path);
    _lengths[source] = Duration(
      microseconds: (data / block / rate * 1e6).round(),
    );
    loaded.add(path);
    return source;
  }

  @override
  Duration getLength(AudioSource source) => _lengths[source]!;

  @override
  Future<void> disposeSource(AudioSource source) async => disposed.add(source);

  @override
  Duration getEngineTime() => now;

  SoundHandle _add(FakeVoice voice) {
    final handle = SoundHandle(_next++);
    voices[handle] = voice;
    return handle;
  }

  @override
  SoundHandle play(
    AudioSource source, {
    double volume = 1,
    bool paused = false,
    bool looping = false,
  }) => _add(
    FakeVoice(
      source.soundPath,
      _lengths[source]!,
      looping: looping,
      volume: volume,
      startsAt: paused ? null : now,
      at: now,
    ),
  );

  @override
  SoundHandle playScheduled(
    AudioSource source,
    Duration atTime, {
    double volume = 1,
    bool looping = false,
  }) => _add(
    FakeVoice(
      source.soundPath,
      _lengths[source]!,
      looping: looping,
      volume: volume,
      startsAt: atTime,
      at: now,
    ),
  );

  FakeVoice? _voice(SoundHandle handle) => voices[handle];

  @override
  bool getIsValidVoiceHandle(SoundHandle handle) =>
      _voice(handle)?.isValidAt(now) ?? false;

  @override
  Duration getPosition(SoundHandle handle) => _voice(handle)!.positionAt(now);

  @override
  void seek(SoundHandle handle, Duration time) {
    final voice = _voice(handle)!;
    voice.offset = time;
    if (voice.startsAt != null) voice.startsAt = now;
  }

  @override
  void setPause(SoundHandle handle, bool pause) {
    final voice = _voice(handle)!;
    if (pause) {
      voice.offset = voice.positionAt(now);
      voice.startsAt = null;
    } else {
      voice.startsAt ??= now;
    }
  }

  @override
  void setVolume(SoundHandle handle, double volume) =>
      _voice(handle)?.fade(now, now, volume, Duration.zero);

  @override
  void fadeVolume(SoundHandle handle, double to, Duration time) =>
      _voice(handle)?.fade(now, now, to, time);

  @override
  void fadeScheduled(
    SoundHandle handle,
    Duration atTime,
    double to,
    Duration time, {
    bool thenStop = false,
  }) {
    final voice = _voice(handle);
    if (voice == null) return;
    voice.fade(now, atTime, to, time);
    if (thenStop) voice.stopAt(atTime + time);
  }

  @override
  void stopScheduled(SoundHandle handle, Duration atTime) =>
      _voice(handle)?.stopAt(atTime);

  @override
  void scheduleStop(SoundHandle handle, Duration time) =>
      _voice(handle)?.stopAt(now + time);

  @override
  Future<void> stop(SoundHandle handle) async => _voice(handle)?.stopAt(now);
}

/// A sound loaded in the [FakeLoopEngine]: SoLoud makes its own only.
class _FakeSource implements AudioSource {
  _FakeSource(this.soundPath);

  @override
  final String soundPath;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One voice of the [FakeLoopEngine].
class FakeVoice {
  FakeVoice(
    this.name,
    this.length, {
    required this.looping,
    required double volume,
    required this.startsAt,
    required Duration at,
  }) : _from = volume,
       _to = volume,
       _fadeFrom = at;

  /// The name the sound was loaded under ('piano-loop.wav', 'tail.wav').
  final String name;
  final Duration length;
  final bool looping;

  /// When it sounds from [offset], on the engine's clock; null while paused.
  Duration? startsAt;
  Duration offset = Duration.zero;
  Duration? stopsAt;

  double _from, _to;
  Duration _fadeFrom, _fadeFor = Duration.zero;

  void stopAt(Duration time) {
    final was = stopsAt;
    if (was == null || time < was) stopsAt = time;
  }

  /// From the volume at [now] to [to], over [time] from [from].
  void fade(Duration now, Duration from, double to, Duration time) {
    _from = volumeAt(now);
    _to = to;
    _fadeFrom = from;
    _fadeFor = time;
  }

  double volumeAt(Duration time) {
    if (time < _fadeFrom) return _from;
    if (time >= _fadeFrom + _fadeFor) return _to;
    final done = (time - _fadeFrom).inMicroseconds / _fadeFor.inMicroseconds;
    return _from + (_to - _from) * done;
  }

  bool isValidAt(Duration time) {
    final stop = stopsAt;
    if (stop != null && time >= stop) return false;
    final start = startsAt;
    if (looping || start == null) return true;
    return offset + (time - start) < length;
  }

  /// Whether it is heard at [time]: started, not yet stopped.
  bool soundsAt(Duration time) {
    final start = startsAt;
    return start != null && time >= start && isValidAt(time);
  }

  Duration positionAt(Duration time) {
    final start = startsAt;
    if (start == null || time <= start) return offset;
    final at = offset + (time - start);
    return looping
        ? Duration(microseconds: at.inMicroseconds % length.inMicroseconds)
        : at;
  }
}

/// A WAV header for a mono sound of [length], with no samples: all the
/// fake engine reads of it.
Uint8List fakeWav(Duration length) {
  const rate = 48000;
  final frames = (length.inMicroseconds * rate / 1e6).round();
  final bytes = ByteData(44);
  void ascii(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + frames * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, frames * 2, Endian.little);
  return bytes.buffer.asUint8List();
}
