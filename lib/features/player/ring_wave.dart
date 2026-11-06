import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../widgets/dial.dart';
import 'ring_window.dart';
import 'track_peaks.dart';

/// The wave of the track inside the ring (RF-PLY-03, RF-PLY-15): the
/// loudness of each stretch, drawn as a shape that swells on both sides of
/// the middle of the ring. It fills up in the direction of the clock as the
/// file is read.
class RingWave extends CustomPainter {
  RingWave({
    required this.peaks,
    required this.window,
    required this.color,
    this.gap = 0,
    this.passage,
    this.passageColor,
  }) : super(repaint: peaks);

  final TrackPeaks peaks;
  final RingWindow window;
  final Color color;

  /// Room left clear on each side of 12 o'clock, in radians (the seam of
  /// the view of a passage).
  final double gap;

  /// A stretch of the window drawn in [passageColor] instead (the passage
  /// that repeats).
  final (Duration, Duration)? passage;
  final Color? passageColor;

  /// The most slices the wave is cut into.
  static const maxSlices = 720;

  /// How far the wave reaches from the middle of the ring, as a fraction of
  /// the ring's thickness: the quietest and the loudest.
  static const flat = 0.01;
  static const reach = 0.40;

  /// How many slices a window of [length] is cut into: no more than there
  /// are peaks in it.
  static int slicesFor(Duration length) => math.max(
    0,
    math.min(
      maxSlices,
      length.inMicroseconds ~/ TrackPeaks.frame.inMicroseconds,
    ),
  );

  /// The shape of the wave for [heights] (0..1, NaN for a slice not read:
  /// the shape stops there), centred on [dial]'s ring. Null when nothing is
  /// there to draw.
  static Path? shape(DialGeometry dial, Float32List heights, {double gap = 0}) {
    var read = 0;
    while (read < heights.length && !heights[read].isNaN) {
      read++;
    }
    if (read == 0) return null;
    final middle = dial.ringInner + dial.ringWidth / 2;
    Offset at(int i, double side) {
      final angle = gap + (i + 0.5) / heights.length * (2 * math.pi - 2 * gap);
      final half = dial.ringWidth * (flat + (reach - flat) * heights[i]);
      final r = middle + side * half;
      return dial.center + Offset(math.sin(angle) * r, -math.cos(angle) * r);
    }

    final path = Path()..moveTo(at(0, 1).dx, at(0, 1).dy);
    for (var i = 1; i < read; i++) {
      final p = at(i, 1);
      path.lineTo(p.dx, p.dy);
    }
    for (var i = read - 1; i >= 0; i--) {
      final p = at(i, -1);
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Float32List? _heights;
  (int, RingWindow, int)? _key;

  @override
  void paint(Canvas canvas, Size size) {
    final dial = DialGeometry(size);
    final count = slicesFor(window.length);
    if (count == 0 || peaks.length == 0) return;
    // The slices are worked out again only when the peaks, the window or
    // their number change.
    final key = (peaks.version, window, count);
    if (key != _key || _heights == null) {
      _heights = peaks.heights(window.from, window.to, count);
      _key = key;
    }
    final path = shape(dial, _heights!, gap: gap);
    if (path == null) return;
    canvas.drawPath(path, Paint()..color = color);
    final stretch = passage, inside = passageColor;
    if (stretch != null && inside != null) {
      final from = window.angleOf(stretch.$1);
      final to = window.angleOf(stretch.$2);
      final sector = Path()
        ..moveTo(dial.center.dx, dial.center.dy)
        ..arcTo(
          Rect.fromCircle(center: dial.center, radius: dial.ringOuter),
          from - math.pi / 2,
          to - from,
          false,
        )
        ..close();
      canvas
        ..save()
        ..clipPath(sector)
        ..drawPath(path, Paint()..color = inside)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(RingWave old) =>
      old.peaks != peaks ||
      old.window != window ||
      old.color != color ||
      old.gap != gap ||
      old.passage != passage ||
      old.passageColor != passageColor;
}
