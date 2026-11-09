import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../widgets/dial.dart';

/// The Player's dial: the same circle as every tab, with a thin band
/// outside the ring for the times of the track, as the metronome keeps its
/// wheel outside the beats (RF-PLY-03). The ring of the wave sits inside
/// the band, a little narrower than the other tabs' rings.
class PlayerDialGeometry extends DialGeometry {
  PlayerDialGeometry(super.size);

  /// The smallest dial that shows the times: below it (a narrow landscape
  /// screen) only the ticks are drawn and the band stays thin.
  static const minLabelledRadius = 120.0;

  /// The room kept outside the ring for the ticks and, on a dial large
  /// enough, the times.
  double get band => labelled ? 28.0 : 10.0;

  /// True when the dial is large enough for the times.
  bool get labelled => radius >= minLabelledRadius;

  /// Where the band ends towards the ring: the outer edge of the ring.
  @override
  double get ringOuter => radius * 0.97 - band;

  @override
  double get ringInner => ringOuter - radius * 0.30;

  /// The middle, where the time and the play button are.
  @override
  double get hub => ringInner - radius * 0.03;
}

/// The marks of a track's times on the ring: a number every [major], a
/// short tick every [minor], chosen from round steps so that no more than
/// [maxLabels] numbers go round the ring.
class TimeScale {
  const TimeScale(this.major, this.minor);

  final Duration major;
  final Duration minor;

  /// The most numbers on the ring.
  static const maxLabels = 8;

  /// The round steps, each with its ticks in between.
  static const _steps = [
    (1, 1),
    (2, 1),
    (5, 1),
    (10, 5),
    (15, 5),
    (30, 10),
    (60, 15),
    (120, 30),
    (300, 60),
    (600, 120),
    (1200, 300),
    (1800, 600),
    (3600, 900),
  ];

  /// The scale of a track of [length]: the smallest round step that keeps
  /// the numbers to [maxLabels].
  factory TimeScale.of(Duration length) {
    final seconds = length.inMilliseconds / 1000;
    for (final (major, minor) in _steps) {
      if (seconds / major <= maxLabels) {
        return TimeScale(Duration(seconds: major), Duration(seconds: minor));
      }
    }
    final (major, minor) = _steps.last;
    final times = (seconds / major / maxLabels).ceil();
    return TimeScale(
      Duration(seconds: major * times),
      Duration(seconds: minor * times),
    );
  }

  /// How close to the end of the turn a number may sit, as a fraction of
  /// the turn: nearer, it would touch the 0:00 at the top.
  static const endRoom = 0.06;

  /// The times that carry a number, from 0:00, on a track of [length].
  List<Duration> labels(Duration length) => [
    for (var t = Duration.zero; t < length; t += major)
      if (t == Duration.zero ||
          (length - t).inMicroseconds / length.inMicroseconds >= endRoom)
        t,
  ];

  /// The times of the short ticks in between, not on a number and not on
  /// the 0:00 the end comes back to.
  List<Duration> ticks(Duration length) {
    if (minor == major) return const [];
    final room = length * endRoom * 0.25;
    return [
      for (var t = minor; t < length - room; t += minor)
        if (t.inMicroseconds % major.inMicroseconds != 0) t,
    ];
  }
}

/// Where a number of [size] goes at [angle] (0 at the top, clockwise): just
/// outside the tick at [from], whatever side of the dial it is on.
Offset labelCentre(Offset centre, double from, double angle, Size size) {
  final reach =
      (math.sin(angle).abs() * size.width +
          math.cos(angle).abs() * size.height) /
      2;
  final r = from + reach;
  return centre + Offset(math.sin(angle), -math.cos(angle)) * r;
}
