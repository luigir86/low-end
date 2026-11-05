import 'dart:async';

/// Runs a task that brings the sound in line with the settings, one run at
/// a time: a request made while one runs waits for it, and every request
/// made meanwhile is answered by the same next run, which reads the
/// settings when its turn comes. So holding + renders the click or the
/// piano only as often as the engine can follow, always with the latest
/// tempo, instead of catching up with every step in turn.
///
/// The first request runs at once, so sound begins without delay. The
/// task must not throw: it reports its own failures.
class LatestRequest {
  LatestRequest(this._task);

  final Future<void> Function() _task;

  /// The run under way, or the one waiting for it, if any.
  Future<void>? _running;

  /// The run waiting for the one under way: further requests join it.
  Future<void>? _queued;

  /// Whether a run is under way or waiting.
  bool get busy => _running != null;

  /// Asks for a run; completes when the run that answers it is done.
  Future<void> run() {
    if (_queued case final queued?) return queued;
    final previous = _running;
    final Future<void> done;
    if (previous == null) {
      done = _task();
    } else {
      late final Future<void> next;
      next = previous.then((_) {
        // Its turn: from now on, a request waits for it to finish.
        if (identical(_queued, next)) _queued = null;
        return _task();
      });
      done = _queued = next;
    }
    late final Future<void> tracked;
    tracked = done.whenComplete(() {
      if (identical(_running, tracked)) _running = null;
    });
    return _running = tracked;
  }
}
