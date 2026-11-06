import 'package:flutter/material.dart';

/// How a flag looks (RF-PLY-08): the colour is never the only sign, there are
/// the letter and the fill.
enum FlagLook {
  /// In its corner, ready; on the ring; on the strip when it is the active one.
  solid,

  /// On the strip when it is not the active one.
  hollow,

  /// Where the flag is not (its corner while it is on the ring) or soon will
  /// not be (the other flag, about to go back): a dashed outline.
  trace,

  /// Touched in its corner, waiting for a touch on the ring: solid, with a
  /// halo.
  armed,
}

/// The colours a flag is painted with.
@immutable
class FlagColors {
  const FlagColors({
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.trace,
    required this.style,
  });

  factory FlagColors.of(ThemeData theme) => FlagColors(
    primary: theme.colorScheme.primary,
    onPrimary: theme.colorScheme.onPrimary,
    surface: theme.colorScheme.surface,
    trace: theme.colorScheme.onSurfaceVariant,
    style: theme.textTheme.labelLarge,
  );

  final Color primary;
  final Color onPrimary;
  final Color surface;

  /// The dashes, at least 3:1 on the dial (WCAG 1.4.11).
  final Color trace;
  final TextStyle? style;

  @override
  bool operator ==(Object other) =>
      other is FlagColors &&
      other.primary == primary &&
      other.onPrimary == onPrimary &&
      other.surface == surface &&
      other.trace == trace &&
      other.style == style;

  @override
  int get hashCode => Object.hash(primary, onPrimary, surface, trace, style);
}

/// The size of a flag in a corner: 34 dp the pole, 24 dp the whole width.
const flagPole = 34.0;
const flagWidth = 24.0;

/// The radius of the halo of an armed flag.
const flagHalo = 26.0;

/// Draws [path] as dashes of [dash] dp with gaps of the same length.
void _dashed(Canvas canvas, Path path, Paint paint, {double dash = 3}) {
  for (final metric in path.computeMetrics()) {
    var at = 0.0;
    while (at < metric.length) {
      final end = at + dash > metric.length ? metric.length : at + dash;
      canvas.drawPath(metric.extractPath(at, end), paint);
      at += dash * 2;
    }
  }
}

/// Paints the pennant of a flag in [rect], with its [letter]: the part that
/// the three places of a flag (corner, ring, strip) have in common.
void paintPennant(
  Canvas canvas,
  Rect rect,
  String letter,
  FlagLook look,
  FlagColors colors,
) {
  final shape = RRect.fromRectAndRadius(rect, const Radius.circular(3));
  final solid = look == FlagLook.solid || look == FlagLook.armed;
  final ink = switch (look) {
    FlagLook.solid || FlagLook.armed => colors.onPrimary,
    FlagLook.hollow => colors.primary,
    FlagLook.trace => colors.trace,
  };
  if (solid) {
    canvas.drawRRect(shape, Paint()..color = colors.primary);
  } else if (look == FlagLook.hollow) {
    canvas
      ..drawRRect(shape, Paint()..color = colors.surface)
      ..drawRRect(
        shape,
        Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  } else {
    _dashed(
      canvas,
      Path()..addRRect(shape),
      Paint()
        ..color = colors.trace
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
  final text = TextPainter(
    text: TextSpan(
      text: letter,
      style: (colors.style ?? const TextStyle()).copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
        fontSize: (rect.height * 0.72).clamp(9.0, 16.0),
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, rect.center - Offset(text.width, text.height) / 2);
  text.dispose();
}

/// A pole from [from] to [to]: solid, or dashed for a trace.
void paintPole(
  Canvas canvas,
  Offset from,
  Offset to,
  FlagLook look,
  FlagColors colors, {
  double width = 2.5,
}) {
  final trace = look == FlagLook.trace;
  final paint = Paint()
    ..color = trace ? colors.trace : colors.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = trace ? 1.5 : width
    ..strokeCap = trace ? StrokeCap.butt : StrokeCap.round;
  if (trace) {
    _dashed(
      canvas,
      Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy),
      paint,
    );
  } else {
    canvas.drawLine(from, to, paint);
  }
}

/// Paints the flag of a corner, its drawing [flagPole] high and [flagWidth]
/// wide centred on [center]: the pennant towards the passage, that is to the
/// right of the pole for [start] and to the left for the end.
void paintCornerFlag(
  Canvas canvas,
  Offset center,
  bool start,
  FlagLook look,
  FlagColors colors,
) {
  final top = center.dy - flagPole / 2, bottom = center.dy + flagPole / 2;
  final poleX = center.dx + (start ? -flagWidth / 2 + 3 : flagWidth / 2 - 3);
  if (look == FlagLook.armed) {
    canvas.drawCircle(
      center,
      flagHalo,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
  paintPole(canvas, Offset(poleX, top), Offset(poleX, bottom), look, colors);
  const w = flagWidth - 6, h = 16.0;
  final left = start ? poleX : poleX - w;
  paintPennant(
    canvas,
    Rect.fromLTWH(left, top, w, h),
    start ? 'A' : 'B',
    look,
    colors,
  );
}
