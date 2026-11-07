import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// How a flag looks (RF-PLY-08): the colour is never the only sign, there are
/// the letter and the fill.
enum FlagLook {
  /// The selected handle in the waveform.
  solid,

  /// On the strip when it is not the active one.
  hollow,
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
    primary: theme.extension<LowEndColors>()!.activeFill,
    onPrimary: theme.extension<LowEndColors>()!.onActiveFill,
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
  final solid = look == FlagLook.solid;
  final ink = switch (look) {
    FlagLook.solid => colors.onPrimary,
    FlagLook.hollow => colors.primary,
  };
  if (solid) {
    canvas.drawRRect(shape, Paint()..color = colors.primary);
    canvas.drawRRect(
      shape,
      Paint()
        ..color = colors.trace
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  } else {
    canvas
      ..drawRRect(shape, Paint()..color = colors.surface)
      ..drawRRect(
        shape,
        Paint()
          ..color = colors.primary
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
