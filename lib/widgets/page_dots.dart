import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A row of [count] dots, the [current] one filled: the pages of the guide,
/// the chords of a progression. Only a picture; what it shows is said in
/// words beside it.
///
/// More than [maxInRow] dots do not fit one row inside the dial, so they
/// go in rows of [perRow], the way the bars of a song are read: twelve-bar
/// blues as three phrases of four.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.current,
    this.size = 10,
    this.maxInRow = 8,
    this.perRow = 4,
  });

  final int count;
  final int current;
  final double size;
  final int maxInRow;
  final int perRow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget dot(int i) => Container(
      width: size,
      height: size,
      margin: EdgeInsets.symmetric(horizontal: size / 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: i == current ? LowEndColors.of(context).activeFill : null,
        border: Border.all(color: colors.outline, width: 1.2),
      ),
    );
    Widget row(int from, int to) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = from; i < to; i++) dot(i)],
    );
    if (count <= maxInRow) return ExcludeSemantics(child: row(0, count));
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: size * 2 / 3,
        children: [
          for (var from = 0; from < count; from += perRow)
            row(from, math.min(from + perRow, count)),
        ],
      ),
    );
  }
}
