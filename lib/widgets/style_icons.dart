import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The pictures of the styles of Harmony, drawn on the same 24-unit grid as
/// the Material icons. The three ways the piano plays a chord are written as
/// in a score: a chord of three whole notes for the chord held a bar, a
/// chord of three quarter notes for the chord struck on every beat, three
/// quarter notes one above the other for the arpeggio. The notes stand a
/// hair apart, which a score would not do, so that they do not run into one
/// shape at this size. Two bare footprints, one a step ahead of the other,
/// for the walking bass; a single wave for the held tone, which is a drone,
/// not the piano.
enum StyleGlyph { heldChord, struckChord, arpeggio, footprints, wave }

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
      case StyleGlyph.heldChord:
        // A layer of its own, so the holes open onto the menu, not onto
        // black.
        canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
        for (final y in const [5.3, 12.0, 18.7]) {
          _wholeNote(canvas, ink, Offset(12, y));
        }
        canvas.restore();
      case StyleGlyph.struckChord:
        const x = 10.5;
        for (final y in const [6.7, 13.2, 19.7]) {
          _blackNote(canvas, ink, Offset(x, y), 2.95, 2.1);
        }
        // One stem for the three notes, on the right going up.
        canvas.drawRect(const Rect.fromLTRB(x + 1.5, 1.2, x + 2.9, 19.7), ink);
      case StyleGlyph.arpeggio:
        for (final (x, y) in const [(4.2, 19.5), (11.6, 15.5), (19.0, 11.5)]) {
          _blackNote(canvas, ink, Offset(x, y), 2.65, 1.9);
          canvas.drawRect(Rect.fromLTRB(x + 1.4, y - 11, x + 2.6, y), ink);
        }
      case StyleGlyph.footprints:
        // The left foot behind, the right one a step ahead, both turned a
        // little outwards as feet walk.
        _foot(canvas, ink, const Offset(7.2, 14.1), -12, mirrored: true);
        _foot(canvas, ink, const Offset(16.8, 9.9), 12, mirrored: false);
      case StyleGlyph.wave:
        // One wave across, as a steady tone would be drawn.
        canvas.drawPath(
          Path()
            ..moveTo(2, 12)
            ..quadraticBezierTo(7, 2, 12, 12)
            ..quadraticBezierTo(17, 22, 22, 12),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  /// A whole note about 8.4 units wide around [centre]: an open oval whose
  /// hole leans to the left, thick on the sides and thin above and below.
  void _wholeNote(Canvas canvas, Paint ink, Offset centre) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 8.4, height: 5.1),
      ink,
    );
    canvas.rotate(-25 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 3.3, height: 4.3),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  /// A filled note head around [centre], [rx] by [ry], tilted up to the
  /// right as engraved.
  void _blackNote(
    Canvas canvas,
    Paint ink,
    Offset centre,
    double rx,
    double ry,
  ) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(-20 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 2 * rx, height: 2 * ry),
      ink,
    );
    canvas.restore();
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
