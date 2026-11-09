import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'subdivision.dart';

/// The notes that fill a beat, drawn: one quarter note, two eighths tied by
/// a beam, three of a triplet tied by a beam under a "3", four sixteenths
/// under two beams; the swung ones are the same notes with "Swing" beside
/// them, as written in a score. Drawn, not typed, since no font has the triplet and the
/// others would not sit on the same line.
class NoteIcon extends StatelessWidget {
  const NoteIcon(this.subdivision, {super.key, this.height = 28, this.color});

  final Subdivision subdivision;
  final double height;

  /// The text colour around it unless given.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final notes = subdivision.notes;
    final ink = color ?? DefaultTextStyle.of(context).style.color!;
    final figure = CustomPaint(
      size: Size(notes == 1 ? height * 0.5 : notes * height * 0.4, height),
      painter: _NotePainter(
        notes: notes,
        triplet: subdivision == Subdivision.triplets,
        color: ink,
      ),
    );
    return ExcludeSemantics(
      child: subdivision.swung
          // Written straight, with the word that says how it is played.
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                figure,
                SizedBox(width: height * 0.2),
                Text(
                  'Swing',
                  maxLines: 1,
                  // Part of the drawing, sized by [height] like the notes:
                  // the field already grows [height] with large text, and
                  // scaling the word again made it twice as large, out of
                  // the menu's line.
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: ink,
                    fontSize: height * 0.42,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            )
          : figure,
    );
  }
}

class _NotePainter extends CustomPainter {
  const _NotePainter({
    required this.notes,
    required this.triplet,
    required this.color,
  });

  final int notes;
  final bool triplet;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final paint = Paint()..color = color;
    final rx = h * 0.14;
    final ry = h * 0.1;
    final stroke = h * 0.07;
    final headY = h * 0.82;
    // The stems end higher on a lone note; under the "3" they stop lower.
    final top = notes == 1 ? h * 0.12 : (triplet ? h * 0.46 : h * 0.2);
    final step = size.width / notes;
    final beam = h * 0.1;
    final stems = <double>[];
    for (var i = 0; i < notes; i++) {
      final cx = step * (i + 0.5);
      canvas.save();
      canvas.translate(cx, headY);
      canvas.rotate(-0.35);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        paint,
      );
      canvas.restore();
      final x = cx + rx - stroke / 2;
      stems.add(x);
      canvas.drawRect(
        Rect.fromLTRB(x - stroke / 2, top, x + stroke / 2, headY),
        paint,
      );
    }
    if (notes > 1) {
      final beams = notes == 4 ? 2 : 1;
      for (var b = 0; b < beams; b++) {
        final y = top + b * beam * 1.7;
        canvas.drawRect(
          Rect.fromLTRB(
            stems.first - stroke / 2,
            y,
            stems.last + stroke / 2,
            y + beam,
          ),
          paint,
        );
      }
    }
    if (triplet) {
      final text = TextPainter(
        text: TextSpan(
          text: '3',
          style: TextStyle(
            color: color,
            fontSize: h * 0.38,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          (size.width - text.width) / 2,
          math.max(0, top - text.height - h * 0.04),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_NotePainter old) =>
      old.notes != notes || old.triplet != triplet || old.color != color;
}
