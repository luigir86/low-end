import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;

import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import 'clock_text.dart';
import 'player_controller.dart';
import 'ring_wave.dart';
import 'ring_window.dart';

/// The angle of a touch at [offset] on a dial of [size].
double touchAngle(Offset offset, Size size) {
  final d = offset - DialGeometry(size).center;
  return math.atan2(d.dx, -d.dy) % (2 * math.pi);
}

/// How far from a grip (the disc with the letter, or the line it sits on) a
/// finger may land and still take it: a 48 dp target (RF-PLY-11).
const gripReach = 24.0;

/// Where the disc of the grip of [edge] sits on a dial of [size], when the
/// end is at [time] of [window]. A is on the inner part of the ring and B on
/// the outer, so that the two stay in reach even when they are close.
Offset gripCenter(LoopEdge edge, RingWindow window, Duration time, Size size) {
  final dial = DialGeometry(size);
  final angle = window.angleOf(time);
  final r =
      dial.ringInner + dial.ringWidth * (edge == LoopEdge.start ? 0.25 : 0.75);
  return dial.center + Offset(math.sin(angle), -math.cos(angle)) * r;
}

/// The end whose grip is under a touch at [at] on a dial of [size], or null.
/// Of two in reach, the nearer one.
LoopEdge? gripAt(
  Offset at,
  Size size,
  RingWindow window, {
  Duration? start,
  Duration? end,
}) {
  final dial = DialGeometry(size);
  LoopEdge? best;
  var bestLine = double.infinity, bestDisc = double.infinity;
  for (final (edge, time) in [(LoopEdge.start, start), (LoopEdge.end, end)]) {
    if (time == null) continue;
    final angle = window.angleOf(time);
    final dir = Offset(math.sin(angle), -math.cos(angle));
    final from = dial.center + dir * dial.ringInner;
    // The distance to the radial line: the touch along it, kept on it.
    final along = ((at - from).dx * dir.dx + (at - from).dy * dir.dy).clamp(
      0.0,
      dial.ringWidth,
    );
    final line = (at - (from + dir * along)).distance;
    final disc = (at - gripCenter(edge, window, time, size)).distance;
    final near = math.min(line, disc);
    if (near > gripReach) continue;
    if (near < bestLine || (near == bestLine && disc < bestDisc)) {
      best = edge;
      bestLine = near;
      bestDisc = disc;
    }
  }
  return best;
}

/// A drag that wins at once, before the swipe between the sections, when the
/// finger lands on a grip of the passage (RF-PLY-11); anywhere else it does
/// not take part, and the touch, the long press and the swipe work as ever.
class _GripDrag extends PanGestureRecognizer {
  _GripDrag({required this.grips});

  /// The end under [local] (a point of the dial), or null.
  final LoopEdge? Function(Offset local) grips;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      grips(event.localPosition) != null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}

/// The Player's dial: the ring is the clock of the track (a whole turn is
/// its length, from 12 o'clock clockwise), with a tick every minute and a
/// point where it is listened to; the middle plays and pauses, or, with no
/// track, opens the file chooser. Touching the ring moves the listening
/// point (RF-PLY-02, RF-PLY-03).
class PlayerDial extends StatefulWidget {
  const PlayerDial({super.key, required this.player});

  final PlayerController player;

  /// Marks the middle of the dial, for tests.
  static const hubKey = Key('playerHub');

  /// How far the ring's slider moves the listening point for one step of a
  /// screen reader's increase or decrease.
  static const readerStep = Duration(seconds: 10);

  /// The same in the view of a passage, where a turn is a few seconds.
  static const passageStep = Duration(seconds: 1);

  @override
  State<PlayerDial> createState() => _PlayerDialState();
}

class _PlayerDialState extends State<PlayerDial> with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _read());

  /// Where the track is, read every frame while it plays.
  final _position = ValueNotifier<Duration>(Duration.zero);

  /// The same in whole seconds: the clock in the middle changes once a
  /// second only.
  final _seconds = ValueNotifier<int>(0);

  /// The loop being drawn by a long press and a slide: where the finger
  /// went down and where it is now, in the track; null when not drawing.
  (Duration, Duration)? _drawing;

  /// The size of the dial, for the gestures.
  var _size = Size.zero;

  /// The end whose grip is held, the distance in time from the finger to the
  /// end at the moment it was taken, and the time under the finger last.
  LoopEdge? _grabbed;
  var _gripOffset = Duration.zero;
  var _fingerAt = Duration.zero;

  /// The window on its way from [_from] to [_to] (RF-PLY-17): [_morph] runs
  /// from 0 to 1 along [_curve].
  late final AnimationController _morph = AnimationController(vsync: this)
    ..value = 1;
  late RingWindow _from, _to;
  var _curve = Easing.standard;

  /// True while the ring shows the passage and not the whole track.
  var _passageView = false;

  /// Waits for A and B to be left alone before the passage view fits them.
  Timer? _quiet;

  /// True when the phone asks for no animation.
  var _reduce = false;

  RingWindow get _window =>
      _from.lerp(_to, _curve.transform(_morph.value.clamp(0.0, 1.0)));

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_sync);
    _to = _from = _wanted();
    _passageView = _inPassage;
    _read();
  }

  @override
  void didUpdateWidget(PlayerDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player == widget.player) return;
    oldWidget.player.removeListener(_sync);
    widget.player.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.player.removeListener(_sync);
    _quiet?.cancel();
    _ticker.dispose();
    _morph.dispose();
    _position.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _read() {
    final at = widget.player.position;
    _position.value = at;
    _seconds.value = at.inSeconds;
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

  bool get _inPassage {
    final player = widget.player;
    return player.status == PlayerStatus.ready && player.looping;
  }

  /// The window that the player's state asks for: the passage while the loop
  /// is on, else the whole track.
  RingWindow _wanted() {
    final player = widget.player;
    if (player.status != PlayerStatus.ready) {
      return RingWindow.whole(Duration.zero);
    }
    if (player.looping) {
      return RingWindow.passage(
        player.loopStart!,
        player.loopEnd!,
        player.duration,
      );
    }
    return RingWindow.whole(player.duration);
  }

  /// Takes the ring to the window that the player asks for. Entering or
  /// leaving the passage view is animated at once; a passage whose ends were
  /// touched fits them only after [PlayerController.settleAfter] of quiet and
  /// with no grip held, so that the ring stays still under the finger.
  void _retarget() {
    if (!mounted) return;
    final wanted = _wanted();
    final passage = _inPassage;
    if (wanted == _to && passage == _passageView) {
      _quiet?.cancel();
      return;
    }
    if (passage == _passageView && passage) {
      if (_grabbed != null) return;
      _quiet?.cancel();
      _quiet = Timer(PlayerController.settleAfter, () {
        if (!mounted || _grabbed != null) return;
        final again = _wanted();
        if (_inPassage) _go(again, Durations.short4, Easing.standard);
      });
      return;
    }
    _quiet?.cancel();
    _passageView = passage;
    if (passage || widget.player.status != PlayerStatus.ready) {
      _go(
        wanted,
        Durations.medium4,
        passage ? Easing.emphasizedDecelerate : Easing.emphasizedAccelerate,
      );
    } else {
      _go(wanted, Durations.medium4, Easing.emphasizedAccelerate);
    }
  }

  void _go(RingWindow to, Duration time, Curve curve) {
    final first = _to.length <= Duration.zero || to.length <= Duration.zero;
    if (_reduce || first) {
      _morph.stop();
      setState(() {
        _from = _to = to;
        _morph.value = 1;
      });
      return;
    }
    _from = _window;
    _to = to;
    _curve = curve;
    _morph
      ..duration = time
      ..forward(from: 0);
  }

  /// The time under a touch at [at], in the window shown. While drawing, the
  /// touch cannot go round past 12 o'clock: it stops at the start or the end
  /// of the window.
  Duration _timeAt(Offset at, {Duration? last}) {
    final window = _window;
    final t = window.timeAt(touchAngle(at, _size));
    if (last == null) return t;
    final half = window.length ~/ 2;
    if ((t - last).abs() > half) {
      return last > window.from + half ? window.to : window.from;
    }
    return t;
  }

  bool _inHub(Offset at) {
    final g = DialGeometry(_size);
    return (at - g.center).distance < g.hub;
  }

  void _drawStart(LongPressStartDetails details) {
    if (_inHub(details.localPosition)) return;
    HapticFeedback.mediumImpact();
    final from = _timeAt(details.localPosition);
    setState(() => _drawing = (from, from));
  }

  void _drawMove(LongPressMoveUpdateDetails details) {
    final drawing = _drawing;
    if (drawing == null) return;
    final to = _timeAt(details.localPosition, last: drawing.$2);
    setState(() => _drawing = (drawing.$1, to));
  }

  void _drawEnd() {
    final drawing = _drawing;
    if (drawing == null) return;
    setState(() => _drawing = null);
    final (from, to) = drawing;
    final player = widget.player;
    // A slide under the shortest loop is a touch.
    if ((to - from).abs() < PlayerController.minLoop) {
      player.seek(from);
    } else {
      player.setLoop(from, to);
    }
  }

  /// The grip under a point of the dial, if the passage has one there.
  LoopEdge? _gripAt(Offset at) {
    final player = widget.player;
    if (player.status != PlayerStatus.ready || _size.isEmpty) return null;
    return gripAt(
      at,
      _size,
      _window,
      start: player.loopStart,
      end: player.loopEnd,
    );
  }

  void _gripStart(DragStartDetails details) {
    final edge = _gripAt(details.localPosition);
    if (edge == null) return;
    final player = widget.player;
    final end = edge == LoopEdge.start ? player.loopStart : player.loopEnd;
    if (end == null) return;
    HapticFeedback.selectionClick();
    _fingerAt = _timeAt(details.localPosition);
    _gripOffset = end - _fingerAt;
    setState(() => _grabbed = edge);
  }

  void _gripMove(DragUpdateDetails details) {
    final edge = _grabbed;
    if (edge == null) return;
    final window = _window;
    _fingerAt = _timeAt(details.localPosition, last: _fingerAt);
    final to = _fingerAt + _gripOffset;
    widget.player.moveEdge(
      edge,
      to < window.from ? window.from : (to > window.to ? window.to : to),
    );
  }

  void _gripEnd() {
    if (_grabbed == null) return;
    setState(() => _grabbed = null);
    _retarget();
  }

  void _seekBy(Duration by) {
    final player = widget.player;
    player.seek(player.position + by);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = widget.player;
    _reduce = MediaQuery.disableAnimationsOf(context);
    final ready = player.status == PlayerStatus.ready;
    final duration = player.duration;
    final position = player.position;
    final decimal = l10n.localeName == 'en' ? '.' : ',';
    // The stretch to draw: the loop, or the one being slid out.
    var arcStart = player.loopStart, arcEnd = player.loopEnd;
    final drawing = _drawing;
    final loopOn = drawing != null || player.looping;
    final peaks = player.peaks;
    if (drawing != null) {
      arcStart = drawing.$1 < drawing.$2 ? drawing.$1 : drawing.$2;
      arcEnd = drawing.$1 < drawing.$2 ? drawing.$2 : drawing.$1;
    }
    // A screen reader moves by 10 s round the track, by a second round a
    // passage.
    final step = _passageView ? PlayerDial.passageStep : PlayerDial.readerStep;
    // "1:12 of 6:03", for screen readers; kept within the track.
    String timeOf(Duration at) {
      final inside = at.isNegative
          ? Duration.zero
          : (at > duration ? duration : at);
      return l10n.playerTimeOf(
        clockText(inside, decimalSeparator: decimal),
        clockText(duration, decimalSeparator: decimal),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _morph,
              builder: (context, _) {
                final window = _window;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Drawn again only when the window changes.
                    RepaintBoundary(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          painter: _RingPainter(
                            window: window,
                            seam: _passageView,
                            fill: theme.colorScheme.outlineVariant,
                            edge: theme.colorScheme.outline,
                            tick: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    // The wave fills in as the file is read (RF-PLY-15); a
                    // track with none (too long for a web page) has none.
                    if (ready && peaks != null)
                      RepaintBoundary(
                        child: ExcludeSemantics(
                          child: ListenableBuilder(
                            listenable: peaks,
                            builder: (context, _) => AnimatedOpacity(
                              opacity: peaks.length > 0 ? 1 : 0,
                              duration: _reduce
                                  ? Duration.zero
                                  : Durations.medium1,
                              curve: Easing.standard,
                              child: CustomPaint(
                                painter: RingWave(
                                  peaks: peaks,
                                  window: window,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  gap: _passageView ? _seamGap : 0,
                                  passage:
                                      loopOn &&
                                          arcStart != null &&
                                          arcEnd != null
                                      ? (arcStart, arcEnd)
                                      : null,
                                  passageColor: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (ready)
                      RepaintBoundary(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            painter: _GripsPainter(
                              window: window,
                              start: arcStart,
                              end: arcEnd,
                              color: theme.colorScheme.primary,
                              onColor: theme.colorScheme.onPrimary,
                              edge: theme.colorScheme.surface,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ),
                      ),
                    if (ready)
                      RepaintBoundary(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            painter: _PlayheadPainter(
                              position: _position,
                              window: window,
                              color: theme.colorScheme.onSurface,
                              outline: theme.colorScheme.surface,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // The ring, as a slider for screen readers; a touch on it moves
            // the listening point. The middle is a button above it.
            Semantics(
              slider: true,
              enabled: ready,
              label: l10n.playerTrack,
              // Read when the Player changes (a seek, play, pause), not
              // every second: the time must not be announced by itself
              // (RF-PLY-16).
              value: ready ? timeOf(position) : null,
              increasedValue: ready ? timeOf(position + step) : null,
              decreasedValue: ready ? timeOf(position - step) : null,
              onIncrease: ready ? () => _seekBy(step) : null,
              onDecrease: ready ? () => _seekBy(-step) : null,
              // The way to choose a passage without dragging (RF-PLY-16).
              customSemanticsActions: ready
                  ? {
                      CustomSemanticsAction(label: l10n.playerMarkStart): () =>
                          player.mark(LoopEdge.start),
                      CustomSemanticsAction(label: l10n.playerMarkEnd): () =>
                          player.mark(LoopEdge.end),
                    }
                  : null,
              // A grip is dragged at once; anywhere else this does not take
              // part, so that a swipe still changes section.
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                gestures: {
                  _GripDrag: GestureRecognizerFactoryWithHandlers<_GripDrag>(
                    () => _GripDrag(grips: _gripAt),
                    (drag) => drag
                      ..onStart = _gripStart
                      ..onUpdate = _gripMove
                      ..onEnd = ((_) => _gripEnd())
                      ..onCancel = _gripEnd,
                  ),
                },
                child: GestureDetector(
                  key: const Key('playerRing'),
                  behavior: HitTestBehavior.opaque,
                  // The slider above says it all to a screen reader; a plain
                  // "tap" on it would do nothing.
                  excludeFromSemantics: true,
                  onTapUp: ready
                      ? (details) {
                          // The middle is the button's.
                          if (_inHub(details.localPosition)) return;
                          player.seek(_timeAt(details.localPosition));
                        }
                      : null,
                  // Hold and slide to draw a loop (RF-PLY-11): no drag, so
                  // that swiping between sections stays free.
                  onLongPressStart: ready ? _drawStart : null,
                  onLongPressMoveUpdate: ready ? _drawMove : null,
                  onLongPressEnd: ready ? (_) => _drawEnd() : null,
                  onLongPressCancel: ready
                      ? () => setState(() => _drawing = null)
                      : null,
                ),
              ),
            ),
            Center(
              child: FractionallySizedBox(
                widthFactor: DialGeometry.hubFraction,
                heightFactor: DialGeometry.hubFraction,
                // Round to the touch as well: the corners of its square
                // would take the grips that sit on the diagonals.
                child: ClipOval(
                  child: _Hub(
                    player: widget.player,
                    seconds: _seconds,
                    decimal: decimal,
                    grabbed: _grabbed,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The room the wave leaves free on each side of the seam at 12 o'clock in
/// the view of a passage, in radians (1°).
const _seamGap = math.pi / 180;

/// The middle of the dial: the button that plays and pauses, or asks for a
/// track.
class _Hub extends StatelessWidget {
  const _Hub({
    required this.player,
    required this.seconds,
    required this.decimal,
    required this.grabbed,
  });

  final PlayerController player;
  final ValueListenable<int> seconds;
  final String decimal;

  /// The end whose grip is held: the middle then shows its time.
  final LoopEdge? grabbed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final status = player.status;
    final label = switch (status) {
      PlayerStatus.empty => l10n.playerChoose,
      _ => player.isPlaying ? l10n.playerPause : l10n.playerPlay,
    };
    final Widget content = switch (status) {
      PlayerStatus.empty => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 32, color: theme.colorScheme.primary),
          Text(l10n.playerChoose, style: muted, textAlign: TextAlign.center),
        ],
      ),
      PlayerStatus.opening => const SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      PlayerStatus.ready => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            player.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          if (grabbed != null)
            // The time of the end being dragged, to the hundredth.
            Text(
              '${grabbed == LoopEdge.start ? 'A' : 'B'} ${clockText((grabbed == LoopEdge.start ? player.loopStart : player.loopEnd) ?? Duration.zero, hundredths: true, decimalSeparator: decimal)}',
              style: theme.textTheme.titleLarge,
            )
          else
            ValueListenableBuilder<int>(
              valueListenable: seconds,
              builder: (context, s, _) => Text(
                '${clockText(Duration(seconds: s), decimalSeparator: decimal)}'
                ' / ${clockText(player.duration, decimalSeparator: decimal)}',
                style: theme.textTheme.titleLarge,
              ),
            ),
        ],
      ),
    };
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: PlayerDial.hubKey,
          customBorder: const CircleBorder(),
          // Tapping before the track is ready is ignored: the chooser is
          // for an empty Player only.
          onTap: status == PlayerStatus.opening
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  if (status == PlayerStatus.empty) {
                    // First thing asked: a web page opens its chooser only
                    // inside the touch.
                    player.pick();
                  } else {
                    player.toggle();
                  }
                },
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.5 / DialGeometry.hubFraction,
              heightFactor: 0.5 / DialGeometry.hubFraction,
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring and its ticks: a whole ring, off, until a track is open. The
/// ticks sit on the outer edge, clear of the wave (RF-PLY-03). In the view of
/// a passage a [seam] marks 12 o'clock, where the turn starts again.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.window,
    required this.seam,
    required this.fill,
    required this.edge,
    required this.tick,
  });

  final RingWindow window;
  final bool seam;
  final Color fill;
  final Color edge;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final dial = DialGeometry(size);
    dial.paintSegment(
      canvas,
      startAngle: 0,
      sweep: 2 * math.pi,
      color: fill,
      border: edge,
    );
    if (window.length <= Duration.zero) return;
    final paint = Paint()
      ..color = tick
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final time in tickTimes(window)) {
      final a = window.angleOf(time);
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        dial.center + dir * (dial.ringInner + dial.ringWidth * 0.92),
        dial.center + dir * dial.ringOuter,
        paint,
      );
    }
    if (seam) {
      canvas.drawLine(
        dial.center + const Offset(0, -1) * dial.ringInner,
        dial.center + const Offset(0, -1) * dial.ringOuter,
        Paint()
          ..color = edge
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.window != window ||
      old.seam != seam ||
      old.fill != fill ||
      old.edge != edge ||
      old.tick != tick;
}

/// The grips of the passage: a line across the ring at A and at B, with a
/// disc and the letter to take it by (RF-PLY-11). A sits on the inner part of
/// the ring and B on the outer, so that both stay in reach when they are
/// close. The colour is not the only sign: there are the letters.
class _GripsPainter extends CustomPainter {
  _GripsPainter({
    required this.window,
    required this.start,
    required this.end,
    required this.color,
    required this.onColor,
    required this.edge,
    required this.style,
  });

  final RingWindow window;
  final Duration? start;
  final Duration? end;
  final Color color;
  final Color onColor;
  final Color edge;
  final TextStyle? style;

  @override
  void paint(Canvas canvas, Size size) {
    if (window.length <= Duration.zero) return;
    final dial = DialGeometry(size);
    for (final (letter, edgeOf, time) in [
      ('A', LoopEdge.start, start),
      ('B', LoopEdge.end, end),
    ]) {
      if (time == null) continue;
      final angle = window.angleOf(time);
      final dir = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        dial.center + dir * dial.ringInner,
        dial.center + dir * dial.ringOuter,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      final at = gripCenter(edgeOf, window, time, size);
      final radius = dial.ringWidth * 0.2;
      canvas
        ..drawCircle(at, radius, Paint()..color = color)
        ..drawCircle(
          at,
          radius,
          Paint()
            ..color = edge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      final text = TextPainter(
        text: TextSpan(
          text: letter,
          style: (style ?? const TextStyle()).copyWith(
            color: onColor,
            fontWeight: FontWeight.w700,
            fontSize: dial.ringWidth * 0.26,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width, text.height) / 2);
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_GripsPainter old) =>
      old.window != window ||
      old.start != start ||
      old.end != end ||
      old.color != color ||
      old.onColor != onColor ||
      old.edge != edge;
}

/// The playhead: a line across the whole ring where the track is heard, like
/// the line of an audio editor, a thin light stroke over a wider dark one so
/// that it shows on the wave as on the bare ring.
class _PlayheadPainter extends CustomPainter {
  _PlayheadPainter({
    required this.position,
    required this.window,
    required this.color,
    required this.outline,
  }) : super(repaint: position);

  final ValueListenable<Duration> position;
  final RingWindow window;
  final Color color;
  final Color outline;

  /// How far the line sticks out of the ring on each side, and its two
  /// widths, see [DialGeometry.ringWidth].
  static const _overhang = 0.06;
  static const _inner = 3.0;
  static const _outer = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final dial = DialGeometry(size);
    final angle = window.angleOf(position.value);
    final dir = Offset(math.sin(angle), -math.cos(angle));
    final from =
        dial.center + dir * (dial.ringInner - dial.ringWidth * _overhang);
    final to =
        dial.center + dir * (dial.ringOuter + dial.ringWidth * _overhang);
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = outline
        ..strokeWidth = _outer
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color
        ..strokeWidth = _inner
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PlayheadPainter old) =>
      old.window != window ||
      old.color != color ||
      old.outline != outline ||
      old.position != position;
}
