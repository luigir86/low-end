import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The three sections' own pictures, for the tabs: a classic metronome, a
/// keyboard and a tuning fork. Material has none of them in its icon font,
/// so they are drawn here on the same 24-unit grid as the Material icons,
/// with about the same stroke (the fork a little slimmer).
enum SectionGlyph { metronome, piano, tuningFork }

/// An icon like [Icon]: it takes its size and colour from the [IconTheme]
/// (the navigation bar and rail set them), outlined or, for the selected
/// tab, filled.
class SectionIcon extends StatelessWidget {
  const SectionIcon(this.glyph, {super.key, this.filled = false});

  final SectionGlyph glyph;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    var color = theme.color ?? Theme.of(context).colorScheme.onSurface;
    if (theme.opacity != null) {
      color = color.withValues(alpha: color.a * theme.opacity!);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SectionIconPainter(glyph, filled: filled, color: color),
        ),
      ),
    );
  }
}

class _SectionIconPainter extends CustomPainter {
  _SectionIconPainter(this.glyph, {required this.filled, required this.color});

  final SectionGlyph glyph;
  final bool filled;
  final Color color;

  static const _stroke = 2.0;

  Paint get _line => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = _stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()..color = color;

  /// Paints over what is below with nothing, to cut gaps in a filled shape.
  Paint _cut(double width) => Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    // A layer of its own, so the cuts open onto the bar, not onto black.
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
    switch (glyph) {
      case SectionGlyph.metronome:
        _metronome(canvas);
      case SectionGlyph.piano:
        _piano(canvas);
      case SectionGlyph.tuningFork:
        _tuningFork(canvas);
    }
    canvas.restore();
  }

  // The case of a classic metronome: a pyramid with a flat top.
  static final _case = Path()
    ..moveTo(9, 2.5)
    ..lineTo(15, 2.5)
    ..lineTo(19.5, 20.5)
    ..lineTo(4.5, 20.5)
    ..close();

  /// How much the sides of the case lean, the tuning fork leans the same.
  static final _lean = math.atan2(4.5, 18);

  // The case, the bar the pendulum stands on, and the pendulum leaning a
  // little to the right with its weight.
  void _metronome(Canvas canvas) {
    const pivot = Offset(12, 15.5);
    const tip = Offset(14.2, 6.5);
    final weight = Offset.lerp(pivot, tip, 0.45)!;
    if (!filled) {
      canvas.drawPath(_case, _line);
      canvas.drawLine(const Offset(6.3, 15.5), const Offset(17.7, 15.5), _line);
      canvas.drawLine(pivot, tip, _line);
      canvas.drawCircle(weight, 1.8, _fill);
      return;
    }
    // Filled, the bar, the pendulum and its weight are cut out of the case.
    canvas.drawPath(_case, _line);
    canvas.drawPath(_case, _fill);
    canvas.drawLine(const Offset(4, 15.5), const Offset(20, 15.5), _cut(1.6));
    canvas.drawLine(pivot, tip, _cut(1.8));
    canvas.drawCircle(weight, 1.8, Paint()..blendMode = BlendMode.clear);
  }

  // A keyboard from the front: three white keys and two black ones.
  void _piano(Canvas canvas) {
    final frame = RRect.fromLTRBR(3, 4, 21, 20, const Radius.circular(2));
    const gaps = [9.0, 15.0];
    final blacks = [
      for (final x in gaps) Rect.fromLTRB(x - 1.8, 4, x + 1.8, 13),
    ];
    if (!filled) {
      canvas.drawRRect(frame, _line);
      for (final x in gaps) {
        canvas.drawLine(Offset(x, 13), Offset(x, 20), _line..strokeWidth = 1.6);
      }
      for (final b in blacks) {
        canvas.drawRect(b, _fill);
      }
      return;
    }
    // Filled, the white keys are bronze and the black ones are dark.
    canvas.drawRRect(frame, _line);
    canvas.drawRRect(frame, _fill);
    for (final x in gaps) {
      canvas.drawLine(Offset(x, 13), Offset(x, 21), _cut(1.6));
    }
    for (final b in blacks) {
      canvas.drawRect(b, Paint()..blendMode = BlendMode.clear);
    }
  }

  // A slim fork with a knob at the end of the stem, leaning like the side of
  // the metronome. Filled, the strokes are bolder.
  void _tuningFork(Canvas canvas) {
    canvas.save();
    canvas.translate(12, 12);
    canvas.rotate(_lean);
    canvas.translate(-12, -12);
    final fork = Path()
      ..moveTo(9.25, 1.5)
      ..lineTo(9.25, 10.5)
      ..arcToPoint(
        const Offset(14.75, 10.5),
        radius: const Radius.circular(2.75),
        clockwise: false,
      )
      ..lineTo(14.75, 1.5)
      ..moveTo(12, 13.25)
      ..lineTo(12, 21);
    canvas.drawPath(fork, _line..strokeWidth = filled ? 2.6 : 1.8);
    canvas.drawCircle(const Offset(12, 21.5), filled ? 1.8 : 1.5, _fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SectionIconPainter old) =>
      old.glyph != glyph || old.filled != filled || old.color != color;
}
