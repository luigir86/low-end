/// Long sums cut into small steps, so that in a browser (where there is no
/// isolate) they can run a slice at a time with the screen drawn in
/// between, instead of holding it up for seconds.
///
/// The work is a `sync*` function that yields after each small piece; its
/// result goes in a [StepResult]. [runSteps] runs it all at once, as
/// before; [runInSlices] a few milliseconds at a time. The heavy inner
/// loops stay in plain functions called from the steps, where the compiler
/// keeps their variables in registers.
library;

import 'dart:async';

/// Where a piece of work cut into steps leaves its result.
class StepResult<T> {
  late T value;
}

/// Runs every step at once.
void runSteps(Iterable<void> steps) {
  for (final _ in steps) {}
}

/// Thrown by [runInSlices] when its work was cancelled.
class StepsCancelled implements Exception {
  const StepsCancelled();
}

/// A piece of work run by [runInSlices], which can be asked to hurry (no
/// more pauses: the player is waiting for it) or to give up.
class SlicedWork {
  bool _hurry = false;
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  /// From now on it runs to the end without letting the screen in.
  void hurry() => _hurry = true;

  /// It stops at its next step, with [StepsCancelled].
  void cancel() => _cancelled = true;
}

/// Runs [steps] about [slice] at a time, letting the screen draw and the
/// touches through in between, until [work] says to hurry.
Future<void> runInSlices(
  Iterable<void> steps,
  SlicedWork work, {
  Duration slice = const Duration(milliseconds: 6),
}) async {
  final watch = Stopwatch()..start();
  // Started on a later turn of the event loop: the caller's frame first.
  await Future<void>.delayed(Duration.zero);
  for (final _ in steps) {
    if (work._cancelled) throw const StepsCancelled();
    if (!work._hurry && watch.elapsed > slice) {
      await Future<void>.delayed(Duration.zero);
      if (work._cancelled) throw const StepsCancelled();
      watch.reset();
    }
  }
}
