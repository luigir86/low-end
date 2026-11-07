import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The stretch of the track that the ring shows, from 12 o'clock clockwise
/// for a whole turn (RF-PLY-03): the whole track, or, with the loop on, the
/// passage with a margin on each side (RF-PLY-17).
@immutable
class RingWindow {
  const RingWindow(this.from, this.to);

  /// The whole track.
  factory RingWindow.whole(Duration duration) =>
      RingWindow(Duration.zero, duration);

  /// The passage [a] to [b] with a margin on each side: a quarter of its
  /// length, between half a second and ten, and never beyond the track.
  factory RingWindow.passage(Duration a, Duration b, Duration duration) {
    final start = a < b ? a : b, end = a < b ? b : a;
    final margin = Duration(
      microseconds: ((end - start).inMicroseconds / 4).round().clamp(
        _minMargin.inMicroseconds,
        _maxMargin.inMicroseconds,
      ),
    );
    final from = start - margin, to = end + margin;
    return RingWindow(
      from.isNegative ? Duration.zero : from,
      to > duration ? duration : to,
    );
  }

  static const _minMargin = Duration(milliseconds: 500);
  static const _maxMargin = Duration(seconds: 10);

  final Duration from;
  final Duration to;

  /// The window [t] of the way from this one to [other] (0 is this one,
  /// 1 the other).
  RingWindow lerp(RingWindow other, double t) {
    Duration mix(Duration x, Duration y) => Duration(
      microseconds: (x.inMicroseconds + (y - x).inMicroseconds * t).round(),
    );
    return RingWindow(mix(from, other.from), mix(to, other.to));
  }

  Duration get length => to - from;

  /// How far [time] is through the window, 0 to 1; a time outside it stops
  /// at its edges.
  double fractionOf(Duration time) {
    if (length <= Duration.zero) return 0;
    final turn = (time - from).inMicroseconds / length.inMicroseconds;
    return turn.clamp(0.0, 1.0);
  }

  /// The time [fraction] of the way through the window (0 to 1): the other
  /// way round of [fractionOf]; outside it stops at the edges.
  Duration timeAtFraction(double fraction) =>
      from +
      Duration(
        microseconds: (length.inMicroseconds * fraction.clamp(0.0, 1.0))
            .round(),
      );

  /// Where [time] sits on the ring: 0 is the top, clockwise, a whole turn
  /// the window; a time outside it stops at its edges.
  double angleOf(Duration time) => fractionOf(time) * 2 * math.pi;

  /// The time at [angle] (0 at the top, clockwise): the other way round of
  /// [angleOf].
  Duration timeAt(double angle) {
    final turn = (angle % (2 * math.pi)) / (2 * math.pi);
    return from +
        Duration(microseconds: (length.inMicroseconds * turn).round());
  }

  @override
  bool operator ==(Object other) =>
      other is RingWindow && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// How far apart the ticks of a window of [length] are: half a second under
/// 5 s, a second under 20 s, five seconds under a minute, ten under two
/// minutes, a minute up to twenty, then five (RF-PLY-03).
Duration tickInterval(Duration length) {
  if (length < const Duration(seconds: 5)) {
    return const Duration(milliseconds: 500);
  }
  if (length < const Duration(seconds: 20)) return const Duration(seconds: 1);
  if (length < const Duration(minutes: 1)) return const Duration(seconds: 5);
  if (length < const Duration(minutes: 2)) return const Duration(seconds: 10);
  if (length > const Duration(minutes: 20)) return const Duration(minutes: 5);
  return const Duration(minutes: 1);
}

/// The times of the ticks inside [window]: the multiples of
/// [tickInterval] of the track itself (1:13,0, 1:14,0…), not of the window.
/// The top of the ring needs none, nor does the very end.
List<Duration> tickTimes(RingWindow window) {
  final step = tickInterval(window.length);
  if (window.length <= Duration.zero) return const [];
  final unit = step.inMicroseconds;
  final first = (window.from.inMicroseconds ~/ unit + 1) * unit;
  return [
    for (var t = first; t < window.to.inMicroseconds; t += unit)
      Duration(microseconds: t),
  ];
}
