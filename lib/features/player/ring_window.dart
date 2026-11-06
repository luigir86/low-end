import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The stretch of the track that the ring shows, from 12 o'clock clockwise
/// for a whole turn (RF-PLY-03). For now it is always the whole track; the
/// view of a passage will be another window on the same ring.
@immutable
class RingWindow {
  const RingWindow(this.from, this.to);

  /// The whole track.
  factory RingWindow.whole(Duration duration) =>
      RingWindow(Duration.zero, duration);

  final Duration from;
  final Duration to;

  Duration get length => to - from;

  /// Where [time] sits on the ring: 0 is the top, clockwise, a whole turn
  /// the window; a time outside it stops at its edges.
  double angleOf(Duration time) {
    if (length <= Duration.zero) return 0;
    final turn = (time - from).inMicroseconds / length.inMicroseconds;
    return turn.clamp(0.0, 1.0) * 2 * math.pi;
  }

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
