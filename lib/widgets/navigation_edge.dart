import 'package:flutter/material.dart';

import '../app/style.dart';

/// The side of the tabs that faces the screen: the top of the bottom bar,
/// the end of the rail in landscape.
enum NavigationEdgeSide { top, end }

/// The ground of the tabs with a thin [accent] line on the side that faces
/// the screen, the accent fading from it into the ground: one warm edge
/// instead of two hard lines.
class NavigationEdge extends Decoration {
  const NavigationEdge({
    required this.ground,
    required this.accent,
    required this.side,
  });

  final Color ground;
  final Color accent;
  final NavigationEdgeSide side;

  /// How much accent the glow starts with, next to the line.
  static const glowStrength = 0.28;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _NavigationEdgePainter(this);

  @override
  bool operator ==(Object other) =>
      other is NavigationEdge &&
      other.ground == ground &&
      other.accent == accent &&
      other.side == side;

  @override
  int get hashCode => Object.hash(ground, accent, side);
}

class _NavigationEdgePainter extends BoxPainter {
  _NavigationEdgePainter(this.edge);

  final NavigationEdge edge;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final box = offset & size;
    canvas.drawRect(box, Paint()..color = edge.ground);
    const line = LowEndShape.navigationLine;
    const glow = LowEndShape.navigationGlow;
    final Rect lineRect;
    final Rect glowRect;
    final Alignment from;
    final Alignment to;
    if (edge.side == NavigationEdgeSide.top) {
      lineRect = Rect.fromLTWH(box.left, box.top, box.width, line);
      glowRect = Rect.fromLTWH(box.left, box.top + line, box.width, glow);
      from = Alignment.topCenter;
      to = Alignment.bottomCenter;
    } else {
      final rtl = configuration.textDirection == TextDirection.rtl;
      final x = rtl ? box.left : box.right - line;
      lineRect = Rect.fromLTWH(x, box.top, line, box.height);
      glowRect = rtl
          ? Rect.fromLTWH(box.left + line, box.top, glow, box.height)
          : Rect.fromLTWH(x - glow, box.top, glow, box.height);
      from = rtl ? Alignment.centerLeft : Alignment.centerRight;
      to = rtl ? Alignment.centerRight : Alignment.centerLeft;
    }
    final strength = NavigationEdge.glowStrength;
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = LinearGradient(
          begin: from,
          end: to,
          colors: [
            edge.accent.withValues(alpha: strength),
            edge.accent.withValues(alpha: strength * 0.35),
            edge.accent.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(glowRect),
    );
    canvas.drawRect(lineRect, Paint()..color = edge.accent);
  }
}
