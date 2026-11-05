import 'package:flutter/foundation.dart';

import 'loop_transport.dart';

/// The screen's clock for a loop the audio engine plays: where in the loop
/// the sound is as it is heard, so that the light comes with the sound and
/// not before it, and how long until a sound that waits comes in. The
/// sound keeps its own perfect time in the engine; this only follows it.
class SoundClock {
  SoundClock([Stopwatch? watch]) : _watch = watch ?? Stopwatch();

  final Stopwatch _watch;

  /// Where in the loop the clock started.
  Duration _startedAt = Duration.zero;

  /// How long into the clock the sound begins, when it waits.
  Duration _waiting = Duration.zero;

  bool get isRunning => _watch.isRunning;

  /// Where in the loop the clock started (see [heard]).
  Duration get startedAt => _startedAt;

  /// Lines the clock up with a loop that began as [start] says, heard
  /// [latency] after the engine plays it. A [fresh] start (from the top of
  /// the loop) lights up once its first sound comes out; a loop carrying
  /// on shows its place as it was that long ago.
  void heard(
    LoopStart start, {
    required Duration latency,
    required bool fresh,
  }) {
    if (fresh) {
      _startedAt = start.position;
      _waiting = start.delay + latency;
    } else {
      _startedAt = start.position - latency;
      _waiting = start.delay;
    }
    _watch
      ..reset()
      ..start();
  }

  /// Starts again [at] that far into the loop, at once: a new tempo
  /// carrying on from the same place in the bar.
  void restartAt(Duration at) {
    _startedAt = at;
    _waiting = Duration.zero;
    _watch
      ..reset()
      ..start();
  }

  void stop() => _watch.stop();

  /// How long until the sound comes in, or null when it does not wait (or
  /// the clock is stopped).
  Duration? get waitLeft {
    if (!_watch.isRunning) return null;
    final left = _waiting - _watch.elapsed;
    return left > Duration.zero ? left : null;
  }

  /// How far into the loop the sound is, as heard, or null while it has
  /// not come in yet.
  Duration? get position {
    final elapsed = _watch.elapsed;
    if (elapsed < _waiting) return null;
    return _startedAt + elapsed - _waiting;
  }

  @visibleForTesting
  Duration get elapsed => _watch.elapsed;
}
