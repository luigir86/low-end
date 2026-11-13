import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import 'metronome_controller.dart';

/// Metronome-only geometry: a thin outer wheel and beats inside it.
/// The shared dial size and the other sections keep their geometry.
class TempoDialGeometry {
  TempoDialGeometry(Size size) : dial = DialGeometry(size);

  final DialGeometry dial;
  // Half the previous 40 dp visual weight; smaller dials stay proportional.
  double get outer => dial.ringOuter;
  double get inner => outer - math.min(20, dial.radius * 0.14);

  // Dark margins enlarge the drag target without painting a heavy band.
  double get hitOuter => dial.radius;
  double get hitInner => dial.outerBandInner;
  double get beatOuter => dial.mainOuter;
  double get beatInner => dial.mainInner;
  double get beatWidth => beatOuter - beatInner;
  double get hubRadius => dial.centreRadius;
  double get hubSize => hubRadius * 1.65;

  Path _annulus(double inner, double outer) => Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: dial.center, radius: outer))
    ..addOval(Rect.fromCircle(center: dial.center, radius: inner));

  Path get band => _annulus(inner, outer);
  Path get hitBand => _annulus(hitInner, hitOuter);
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
    if (point.distance < geometry.hubRadius * 0.75) return null;
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
        if ((from + segment * t).distance < geometry.hubRadius * 0.75) return;
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
          // Paint independently of the hit-test clip so the static band
          // remains visible across signature changes and image captures.
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: CustomPaint(
                  painter: _TempoPainter(
                    fill: LowEndColors.of(context).stepFill,
                    ink: colors.surface,
                    rotation: _rotation,
                  ),
                ),
              ),
              ClipPath(
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
                  child: const SizedBox.expand(),
                ),
              ),
            ],
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
  Path getClip(Size size) => TempoDialGeometry(size).hitBand;

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
      final direction = Offset(math.sin(angle), -math.cos(angle));
      final length = width * (i % 4 == 0 ? 0.38 : 0.22);
      canvas.drawLine(
        center + direction * (radius - length / 2),
        center + direction * (radius + length / 2),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_TempoPainter old) =>
      old.fill != fill || old.ink != ink || old.rotation != rotation;
}
