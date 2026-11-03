import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The pictures of two styles of Harmony that Material's icon font lacks:
/// four strokes for the chord struck on every beat (its three dots would
/// read as "more"), and two bare footprints, one a step ahead of the other,
/// for the walking bass. Drawn on the same 24-unit grid as the Material
/// icons; the other styles use Material icons.
enum StyleGlyph { beats, footprints }

/// An icon like [Icon]: it takes its size and colour from the [IconTheme].
class StyleIcon extends StatelessWidget {
  const StyleIcon(this.glyph, {super.key});

  final StyleGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = theme.size ?? 24;
    var color = theme.color ?? Theme.of(context).colorScheme.onSurface;
    if (theme.opacity != null) {
      color = color.withValues(alpha: color.a * theme.opacity!);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(painter: _StyleIconPainter(glyph, color)),
      ),
    );
  }
}

class _StyleIconPainter extends CustomPainter {
  _StyleIconPainter(this.glyph, this.color);

  final StyleGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final ink = Paint()..color = color;
    switch (glyph) {
      case StyleGlyph.beats:
        _beats(canvas);
      case StyleGlyph.footprints:
        // The left foot behind, the right one a step ahead, both turned a
        // little outwards as feet walk.
        _foot(canvas, ink, const Offset(7.2, 14.1), -12, mirrored: true);
        _foot(canvas, ink, const Offset(16.8, 9.9), 12, mirrored: false);
    }
  }

  /// Four short upright strokes, evenly spaced: the four beats of a bar,
  /// as the long line of [Icons.horizontal_rule] is the chord held a bar.
  void _beats(Canvas canvas) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final x = 5.0 + i * 14 / 3;
      canvas.drawLine(Offset(x, 8), Offset(x, 16), line);
    }
  }

  /// A footprint about 16 units long around [centre], toes up, turned by
  /// [degrees]: the ball and the heel as one sole, the toes as dots, the big
  /// toe on the inner side: drawn as the right foot, [mirrored] for the left.
  void _foot(
    Canvas canvas,
    Paint ink,
    Offset centre,
    double degrees, {
    required bool mirrored,
  }) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.scale(mirrored ? -1.2 : 1.2, 1.2);
    // The sole: a broad ball narrowing to the heel along the outer edge.
    final sole = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(0, -1.4), width: 5.6, height: 6.6),
      )
      ..addOval(
        Rect.fromCenter(
          center: const Offset(0.5, 3.6),
          width: 4.2,
          height: 4.6,
        ),
      )
      ..addRect(const Rect.fromLTRB(-1.3, -1.4, 2.6, 3.6));
    canvas.drawPath(sole, ink);
    // The toes, the big one first, on the inner side.
    canvas.drawCircle(const Offset(-1.5, -6.1), 1.25, ink);
    canvas.drawCircle(const Offset(0.6, -6.5), 0.85, ink);
    canvas.drawCircle(const Offset(2.2, -5.7), 0.75, ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StyleIconPainter old) =>
      old.glyph != glyph || old.color != color;
}
