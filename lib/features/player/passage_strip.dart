import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../app/style.dart';
import '../../l10n/app_localizations.dart';
import 'clock_text.dart';
import 'flag_drag.dart';
import 'flag_painter.dart';
import 'player_controller.dart';
import 'ring_window.dart';
import 'track_peaks.dart';

/// A full-track waveform that zooms to the marked passage (RF-PLY-17).
/// Drag a handle to refine an endpoint or tap the waveform to seek.
class PassageStrip extends StatefulWidget {
  const PassageStrip({super.key, required this.player});

  final PlayerController player;

  /// Marks the strip, for tests.
  static const stripKey = Key('playerStrip');

  /// The tallest the strip is at normal text size, in logical pixels.
  static const height = LowEndShape.controlRowHeight;

  /// Room on each side, so that a pole at the very start or end of the track
  /// can still be taken.
  static const margin = 12.0;

  /// How far from a pole, sideways, a finger may land and still take it
  /// (a 48 dp target).
  static const reach = 24.0;

  /// How far the strip's sliders move a flag for one step of a screen
  /// reader's increase or decrease.
  static const readerStep = PlayerController.coarseStep;

  /// Within this distance of an end of the strip, a held pole pushes the
  /// strip wider that way.
  static const edgeZone = 24.0;

  /// How often, and by how much of the window, the strip widens while
  /// pushed: about half the window more each second, at least 20 ms a step.
  static const pushTick = Duration(milliseconds: 16);
  static const pushRate = 0.01;
  static const pushMin = Duration(milliseconds: 20);

  @override
  State<PassageStrip> createState() => _PassageStripState();
}

class _PassageStripState extends State<PassageStrip>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _read());

  /// Where the track is, read every frame while it plays.
  final _position = ValueNotifier<Duration>(Duration.zero);

  /// The window on its way from [_from] to [_to] (RF-PLY-17): [_morph] runs
  /// from 0 to 1.
  late final AnimationController _morph = AnimationController(vsync: this)
    ..value = 1;
  late RingWindow _from, _to;

  /// Waits for A and B to be left alone before the window fits them.
  Timer? _quiet;

  var _width = 0.0;
  LoopEdge? _held;
  var _moved = false;
  var _downAt = Offset.zero;
  var _offset = Duration.zero;
  var _fingerAt = Duration.zero;
  var _reduce = false;

  /// A pole held against an edge widens the window that way (-1 left, 1
  /// right), a little every frame, as a text selection scrolls.
  Timer? _push;
  var _pushWay = 0;

  RingWindow get _window =>
      _from.lerp(_to, Easing.standard.transform(_morph.value.clamp(0.0, 1.0)));

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_sync);
    _to = _from = _wanted();
    _read();
    _sync();
  }

  @override
  void didUpdateWidget(PassageStrip old) {
    super.didUpdateWidget(old);
    if (old.player == widget.player) return;
    old.player.removeListener(_sync);
    widget.player.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.player.removeListener(_sync);
    _quiet?.cancel();
    _push?.cancel();
    _ticker.dispose();
    _morph.dispose();
    _position.dispose();
    super.dispose();
  }

  void _read() => _position.value = widget.player.position;

  RingWindow _wanted() {
    final player = widget.player;
    final a = player.loopStart, b = player.loopEnd;
    if (a == null || b == null) return RingWindow.whole(player.duration);
    return RingWindow.passage(a, b, player.duration);
  }

  /// The frames run only while the track plays, to save battery.
  void _sync() {
    _read();
    final turning = widget.player.isPlaying;
    if (turning && !_ticker.isActive) {
      _ticker.start();
    } else if (!turning && _ticker.isActive) {
      _ticker.stop();
    }
    _retarget();
  }

  /// The window fits the passage after [PlayerController.settleAfter] of
  /// quiet and with no pole held, so that the strip stays still under the
  /// finger and under the arrows.
  void _retarget() {
    if (!mounted) return;
    final wanted = _wanted();
    if (wanted == _to) {
      _quiet?.cancel();
      return;
    }
    if (_held != null) return;
    _quiet?.cancel();
    _quiet = Timer(PlayerController.settleAfter, () {
      if (!mounted || _held != null) return;
      final again = _wanted();
      if (again == _to) return;
      if (_reduce) {
        setState(() => _from = _to = again);
        return;
      }
      _from = _window;
      _to = again;
      _morph
        ..duration = Durations.short4
        ..forward(from: 0);
    });
  }

  String _clock(Duration time, AppLocalizations l10n) => clockText(
    time,
    hundredths: true,
    decimalSeparator: l10n.localeName == 'en' ? '.' : ',',
  );

  double _x(RingWindow window, Duration time) =>
      PassageStrip.margin +
      window.fractionOf(time) * (_width - 2 * PassageStrip.margin);

  Duration _timeAt(double dx) => _window.timeAtFraction(
    (dx - PassageStrip.margin) / math.max(1, _width - 2 * PassageStrip.margin),
  );

  /// The flag under [at]: its pole within reach, sideways, or its pennant;
  /// of two, the nearer.
  LoopEdge? _flagAt(Offset at) {
    final player = widget.player;
    final a = player.loopStart, b = player.loopEnd;
    if (a == null || b == null || _width <= 0) return null;
    final window = _window;
    LoopEdge? best;
    var bestAway = double.infinity;
    for (final (edge, time) in [(LoopEdge.start, a), (LoopEdge.end, b)]) {
      final away = (at.dx - _x(window, time)).abs();
      if (away <= PassageStrip.reach && away < bestAway) {
        best = edge;
        bestAway = away;
      }
    }
    return best;
  }

  void _down(DragDownDetails details) {
    final edge = _flagAt(details.localPosition);
    _held = edge;
    _moved = false;
    if (edge == null) return;
    _downAt = details.localPosition;
    final player = widget.player;
    final end = edge == LoopEdge.start ? player.loopStart : player.loopEnd;
    _fingerAt = _timeAt(details.localPosition.dx);
    _offset = (end ?? _fingerAt) - _fingerAt;
  }

  void _move(DragUpdateDetails details) {
    final edge = _held;
    if (edge == null) return;
    if (!_moved) {
      if ((details.localPosition - _downAt).distance < kTouchSlop) return;
      _moved = true;
      HapticFeedback.selectionClick();
    }
    final dx = details.localPosition.dx;
    _pushTowards(
      dx < PassageStrip.margin + PassageStrip.edgeZone
          ? -1
          : dx > _width - PassageStrip.margin - PassageStrip.edgeZone
          ? 1
          : 0,
    );
    final window = _window;
    _fingerAt = _timeAt(details.localPosition.dx);
    final to = _fingerAt + _offset;
    // Stops at the ends of the track and of the window shown; the player
    // keeps a second from the other flag.
    widget.player.moveEdge(
      edge,
      to < window.from ? window.from : (to > window.to ? window.to : to),
    );
  }

  void _pushTowards(int way) {
    if (way == _pushWay) return;
    _pushWay = way;
    _push?.cancel();
    _push = way == 0
        ? null
        : Timer.periodic(PassageStrip.pushTick, (_) => _pushOnce());
  }

  /// Widens the window by a step on the side of [_pushWay] and takes the
  /// held flag to its new edge, up to the ends of the track.
  void _pushOnce() {
    final edge = _held;
    if (!mounted || edge == null || _pushWay == 0) return _pushTowards(0);
    final player = widget.player;
    final window = _window;
    final step = Duration(
      microseconds: math.max(
        (window.length.inMicroseconds * PassageStrip.pushRate).round(),
        PassageStrip.pushMin.inMicroseconds,
      ),
    );
    final RingWindow wider;
    if (_pushWay > 0) {
      final to = window.to + step;
      wider = RingWindow(
        window.from,
        to > player.duration ? player.duration : to,
      );
    } else {
      final from = window.from - step;
      wider = RingWindow(from.isNegative ? Duration.zero : from, window.to);
    }
    if (wider == window) return;
    setState(() {
      _from = _to = wider;
      _morph.value = 1;
    });
    player.moveEdge(edge, _pushWay > 0 ? wider.to : wider.from);
  }

  void _end() {
    _pushTowards(0);
    final edge = _held;
    if (edge == null) return;
    final moved = _moved;
    _held = null;
    _moved = false;
    // Touched, not dragged: the flag becomes the one the arrows move.
    if (!moved) widget.player.focus(edge);
    _retarget();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = widget.player;
    _reduce = MediaQuery.disableAnimationsOf(context);
    final scale = MediaQuery.textScalerOf(context);
    // With large text the flags grow and the strip with them.
    final height = math.max(PassageStrip.height, 2 * scale.scale(20) + 24);
    final a = player.loopStart, b = player.loopEnd;
    return SizedBox(
      key: PassageStrip.stripKey,
      width: double.infinity,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth;
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _morph,
                builder: (context, _) {
                  final window = _window;
                  return RepaintBoundary(
                    child: ExcludeSemantics(
                      child: ListenableBuilder(
                        listenable: player.peaks ?? _position,
                        builder: (context, _) => CustomPaint(
                          size: Size(constraints.maxWidth, height),
                          painter: _StripPainter(
                            window: window,
                            peaks: player.peaks,
                            start: a,
                            end: b,
                            active: player.activeEdge,
                            looping: player.looping,
                            colors: FlagColors.of(theme),
                            fill: theme.colorScheme.outlineVariant,
                            outline: theme.colorScheme.outline,
                            tick: theme.colorScheme.onSurfaceVariant,
                            wave: theme.colorScheme.onSurfaceVariant,
                            startLabel: a == null ? '' : 'A ${_clock(a, l10n)}',
                            endLabel: b == null ? '' : '${_clock(b, l10n)} B',
                            textScaler: scale,
                            peaksVersion: player.peaks?.version ?? 0,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              RepaintBoundary(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _morph,
                    builder: (context, _) => CustomPaint(
                      painter: _CursorPainter(
                        position: _position,
                        window: _window,
                        margin: PassageStrip.margin,
                        color: theme.colorScheme.onSurface,
                        outline: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ),
              // The poles, as sliders for a screen reader: an increase or a
              // decrease moves the flag by a tenth of a second (RF-PLY-16).
              if (a != null && b != null)
                for (final (edge, time) in [
                  (LoopEdge.start, a),
                  (LoopEdge.end, b),
                ])
                  Positioned(
                    left: math.max(0, _x(_window, time) - PassageStrip.reach),
                    width: PassageStrip.reach * 2,
                    top: 0,
                    bottom: 0,
                    child: Semantics(
                      slider: true,
                      label: edge == LoopEdge.start
                          ? l10n.playerStartAt(_clock(time, l10n))
                          : l10n.playerEndAt(_clock(time, l10n)),
                      onIncrease: () =>
                          player.nudge(edge, PassageStrip.readerStep),
                      onDecrease: () =>
                          player.nudge(edge, -PassageStrip.readerStep),
                      child: const SizedBox.expand(),
                    ),
                  ),
              // A pole is dragged at once; elsewhere this does not take part,
              // so that a swipe changes section and a touch moves the
              // listening point.
              RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                gestures: {
                  FlagDrag: GestureRecognizerFactoryWithHandlers<FlagDrag>(
                    () => FlagDrag(flagAt: _flagAt),
                    (drag) => drag
                      ..onDown = _down
                      ..onUpdate = _move
                      ..onEnd = ((_) => _end())
                      ..onCancel = _end,
                  ),
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapUp: (details) =>
                      player.seek(_timeAt(details.localPosition.dx)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The base, the ticks, the wave of the window and the flags.
class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.window,
    required this.peaks,
    required this.start,
    required this.end,
    required this.active,
    required this.looping,
    required this.colors,
    required this.fill,
    required this.outline,
    required this.tick,
    required this.wave,
    required this.startLabel,
    required this.endLabel,
    required this.textScaler,
    required this.peaksVersion,
  });

  final RingWindow window;
  final TrackPeaks? peaks;
  final Duration? start;
  final Duration? end;
  final LoopEdge active;
  final bool looping;
  final FlagColors colors;
  final Color fill;
  final Color outline;
  final Color tick;
  final Color wave;
  final String startLabel;
  final String endLabel;
  final TextScaler textScaler;
  final int peaksVersion;

  static const _radius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    canvas
      ..drawRRect(box, Paint()..color = fill)
      ..drawRRect(
        box,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    if (window.length <= Duration.zero) return;
    final inner = size.width - 2 * PassageStrip.margin;
    double x(Duration t) => PassageStrip.margin + window.fractionOf(t) * inner;

    if (start != null && end != null) {
      canvas.drawRect(
        Rect.fromLTRB(x(start!), 0, x(end!), size.height),
        Paint()
          ..color = colors.primary.withValues(alpha: looping ? 0.28 : 0.08),
      );
    }

    // The ticks, on the top edge, on the true multiples of the track.
    final ticks = Paint()
      ..color = tick
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final time in tickTimes(window)) {
      canvas.drawLine(Offset(x(time), 0), Offset(x(time), 6), ticks);
    }

    // The wave, one value every two logical pixels at most, and never more
    // than the frames of the window.
    final read = peaks;
    final pennantH = math.max(20.0, textScaler.scale(20));
    final top = pennantH + 2, bottom = size.height - pennantH - 2;
    if (read != null && read.length > 0 && bottom > top) {
      final count = math.max(
        0,
        math.min(
          (inner / 2).floor(),
          window.length.inMicroseconds ~/ TrackPeaks.frame.inMicroseconds,
        ),
      );
      if (count > 0) {
        final heights = read.heights(window.from, window.to, count);
        final middle = (top + bottom) / 2, reach = (bottom - top) / 2;
        final path = Path();
        var drawn = 0;
        for (var i = 0; i < count; i++) {
          final h = heights[i];
          if (h.isNaN) break;
          final half = reach * (0.02 + 0.98 * h);
          final left = PassageStrip.margin + inner * i / count;
          path.addRect(
            Rect.fromLTRB(
              left,
              middle - half,
              left + inner / count,
              middle + half,
            ),
          );
          drawn++;
        }
        if (drawn > 0) {
          final a = start, b = end;
          canvas.drawPath(path, Paint()..color = wave);
          if (looping && a != null && b != null) {
            canvas
              ..save()
              ..clipRect(Rect.fromLTRB(x(a), 0, x(b), size.height))
              ..drawPath(path, Paint()..color = colors.primary)
              ..restore();
          }
        }
      }
    }

    // The poles and the pennants: the active flag solid, the other hollow.
    for (final (edge, time, label) in [
      (LoopEdge.start, start, startLabel),
      (LoopEdge.end, end, endLabel),
    ]) {
      if (time == null) continue;
      final px = x(time);
      final look = edge == active ? FlagLook.solid : FlagLook.hollow;
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, size.height),
        Paint()
          ..color = colors.primary
          ..strokeWidth = 2.5,
      );
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: (colors.style ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: (pennantH * 0.72).clamp(9.0, 16.0),
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = text.width + 12;
      text.dispose();
      final isStart = edge == LoopEdge.start;
      var left = isStart ? px : px - w;
      left = left.clamp(0.0, math.max(0.0, size.width - w));
      final topY = isStart ? 2.0 : size.height - pennantH - 2;
      paintPennant(
        canvas,
        Rect.fromLTWH(left, topY, w, pennantH),
        label,
        look,
        colors,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.window != window ||
      old.start != start ||
      old.end != end ||
      old.active != active ||
      old.looping != looping ||
      old.colors != colors ||
      old.fill != fill ||
      old.wave != wave ||
      old.startLabel != startLabel ||
      old.endLabel != endLabel ||
      old.textScaler != textScaler ||
      old.peaksVersion != peaksVersion;
}

/// The listening point on the strip: a vertical line over the whole height,
/// a light stroke over a wider dark one.
class _CursorPainter extends CustomPainter {
  _CursorPainter({
    required this.position,
    required this.window,
    required this.margin,
    required this.color,
    required this.outline,
  }) : super(repaint: position);

  final ValueListenable<Duration> position;
  final RingWindow window;
  final double margin;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final at = position.value;
    // Only inside the window shown.
    if (at < window.from || at > window.to) return;
    final x = margin + window.fractionOf(at) * (size.width - 2 * margin);
    final from = const Offset(0, -2) + Offset(x, 0);
    final to = Offset(x, size.height + 2);
    canvas
      ..drawLine(
        from,
        to,
        Paint()
          ..color = outline
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        from,
        to,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_CursorPainter old) =>
      old.window != window || old.color != color || old.outline != outline;
}
