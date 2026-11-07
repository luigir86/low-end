import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import 'metronome_controller.dart';

/// The tempo control fits inside the beat ring; other dials keep their geometry.
class TempoDialGeometry {
  TempoDialGeometry(Size size) : dial = DialGeometry(size);

  final DialGeometry dial;
  double get outer => dial.ringInner - 4;
  double get inner => math.max(outer - 40, dial.radius * 0.31);
  double get hubSize => inner * 1.65;

  Path get band => Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: dial.center, radius: outer))
    ..addOval(Rect.fromCircle(center: dial.center, radius: inner));
}

/// RF-MET-09: an endless relative jog wheel, not an absolute circular slider.
class MetronomeTempoDial extends StatefulWidget {
  const MetronomeTempoDial({super.key, required this.metronome});

  final MetronomeController metronome;

  /// Fixed gain, independent of the speed of the hand: 90° = 30 BPM.
  static const bpmPerRadian = 60 / math.pi;

  @override
  State<MetronomeTempoDial> createState() => _MetronomeTempoDialState();
}

class _MetronomeTempoDialState extends State<MetronomeTempoDial> {
  Size _size = Size.zero;
  double? _previous;
  Offset? _previousPoint;
  double _pending = 0;
  double _rotation = 0;
  bool _moving = false;

  double? _angle(Offset local) {
    final geometry = TempoDialGeometry(_size);
    final point = local - geometry.dial.center;
    // The angle is undefined at the centre; re-enter without a jump.
    if (point.distance < geometry.inner * 0.75) return null;
    return math.atan2(point.dx, -point.dy);
  }

  void _down(DragDownDetails details) {
    _previous = _angle(details.localPosition);
    _previousPoint = details.localPosition;
    _pending = 0;
    _moving = false;
  }

  void _update(DragUpdateDetails details) {
    final angle = _angle(details.localPosition);
    final previous = _previous;
    final previousPoint = _previousPoint;
    _previous = angle;
    _previousPoint = details.localPosition;
    if (angle == null || previous == null) return;
    // Also reject a fast straight crossing whose events skip the centre.
    if (previousPoint != null) {
      final geometry = TempoDialGeometry(_size);
      final from = previousPoint - geometry.dial.center;
      final segment = details.localPosition - previousPoint;
      if (segment.distanceSquared > 0) {
        final t =
            (-(from.dx * segment.dx + from.dy * segment.dy) /
                    segment.distanceSquared)
                .clamp(0.0, 1.0);
        if ((from + segment * t).distance < geometry.inner * 0.75) return;
      }
    }
    // Shortest signed arc also works across the seam at twelve o'clock.
    final change = math.atan2(
      math.sin(angle - previous),
      math.cos(angle - previous),
    );
    _pending += change * MetronomeTempoDial.bpmPerRadian;
    if (!_moving) {
      final geometry = TempoDialGeometry(_size);
      final travel =
          _pending.abs() /
          MetronomeTempoDial.bpmPerRadian *
          (geometry.inner + geometry.outer) /
          2;
      if (travel < 4) return;
      _moving = true;
    }
    setState(() => _rotation = (_rotation + change) % (2 * math.pi));
    final steps = _pending.round();
    if (steps == 0) return;
    _pending -= steps;
    final metronome = widget.metronome;
    metronome.step(steps);
    // Discard overshoot: reversing at a bound responds immediately.
    if (metronome.bpm == MetronomeController.minBpm ||
        metronome.bpm == metronome.maxTempo) {
      _pending = 0;
    }
  }

  void _end() {
    _previous = null;
    _previousPoint = null;
    _pending = 0;
    _moving = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final metronome = widget.metronome;
    final increase = metronome.bpm < metronome.maxTempo;
    final decrease = metronome.bpm > MetronomeController.minBpm;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_size != constraints.biggest) _end();
        _size = constraints.biggest;
        return Semantics(
          slider: true,
          label: l10n.tempoDial,
          hint: l10n.tempoDialHint,
          value: l10n.bpmValue('${metronome.bpm}'),
          increasedValue: increase
              ? l10n.bpmValue('${metronome.bpm + 1}')
              : null,
          decreasedValue: decrease
              ? l10n.bpmValue('${metronome.bpm - 1}')
              : null,
          onIncrease: increase ? () => metronome.step(1) : null,
          onDecrease: decrease ? () => metronome.step(-1) : null,
          excludeSemantics: true,
          // Clip hit-testing as well as painting: the centre and outer beats
          // fall through to their own start/stop controls.
          child: ClipPath(
            key: const Key('metronomeTempoDial'),
            clipper: const _BandClipper(),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              gestures: {
                _TempoPan: GestureRecognizerFactoryWithHandlers<_TempoPan>(
                  _TempoPan.new,
                  (drag) => drag
                    ..onDown = _down
                    ..onUpdate = _update
                    ..onEnd = ((_) => _end())
                    ..onCancel = _end,
                ),
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _TempoPainter(
                    // Neutral, conspicuous and derived from each theme.
                    fill: Color.lerp(colors.surface, colors.onSurface, 0.72)!,
                    ink: colors.surface,
                    rotation: _rotation,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wins before page/landscape swipes, only where the band was hit. One finger
/// owns the gesture; extra pointers do not become a centroid or a new origin.
class _TempoPan extends PanGestureRecognizer {
  int? _pointer;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      _pointer == null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointer = event.pointer;
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _pointer = null;
  }
}

class _BandClipper extends CustomClipper<Path> {
  const _BandClipper();

  @override
  Path getClip(Size size) => TempoDialGeometry(size).band;

  @override
  bool shouldReclip(_BandClipper oldClipper) => false;
}

class _TempoPainter extends CustomPainter {
  const _TempoPainter({
    required this.fill,
    required this.ink,
    required this.rotation,
  });

  final Color fill;
  final Color ink;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = TempoDialGeometry(size);
    final center = geometry.dial.center;
    final radius = (geometry.inner + geometry.outer) / 2;
    final width = geometry.outer - geometry.inner;
    canvas.drawPath(geometry.band, Paint()..color = fill);
    final tick = Paint()
      ..color = ink
      ..strokeWidth = 1.2;
    for (var i = 0; i < 48; i++) {
      final angle = i * math.pi / 24 + rotation;
      if (math.atan2(math.sin(angle), math.cos(angle)).abs() < 0.65) continue;
      final direction = Offset(math.sin(angle), -math.cos(angle));
      final length = width * (i % 4 == 0 ? 0.38 : 0.22);
      canvas.drawLine(
        center + direction * (radius - length / 2),
        center + direction * (radius + length / 2),
        tick,
      );
    }
    // Relative direction cues, no thumb or fixed numeric scale.
    for (final sign in [-1, 1]) {
      final angle = sign * 0.44;
      final at = center + Offset(math.sin(angle), -math.cos(angle)) * radius;
      final reach = math.min(6.0, width * 0.2);
      canvas.drawLine(at - Offset(reach, 0), at + Offset(reach, 0), tick);
      if (sign > 0) {
        canvas.drawLine(at - Offset(0, reach), at + Offset(0, reach), tick);
      }
    }
    final arrow = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 - 0.18,
      0.36,
      false,
      arrow,
    );
    final end = center + Offset(math.sin(0.18), -math.cos(0.18)) * radius;
    canvas.drawLine(end, end + const Offset(-4, -3), arrow);
    canvas.drawLine(end, end + const Offset(-4, 3), arrow);
  }

  @override
  bool shouldRepaint(_TempoPainter old) =>
      old.fill != fill || old.ink != ink || old.rotation != rotation;
}
