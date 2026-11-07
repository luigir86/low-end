import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import 'clock_text.dart';
import 'flag_drag.dart';
import 'flag_painter.dart';
import 'marquee.dart';
import 'player_controller.dart';
import 'ring_wave.dart';
import 'ring_window.dart';

/// The angle of a touch at [offset] on a dial of [size].
double touchAngle(Offset offset, Size size) {
  final d = offset - DialGeometry(size).center;
  return math.atan2(d.dx, -d.dy) % (2 * math.pi);
}

/// How far from a flag (its pennant, or its pole) a finger may land and
/// still take it: a 48 dp target (RF-PLY-08).
const gripReach = 24.0;

/// How far beyond the ring a finger may be and still put a flag on it.
const _bandMargin = 24.0;

/// How far above the finger a flag dragged outside the ring is drawn, so that
/// the finger does not cover it.
const _liftAbove = 40.0;

/// The pennant of a flag on the ring, in logical pixels, for a ring [width]
/// thick: 0.4 of it wide and 0.3 high, at least as big as a letter.
Size pennantSize(double width) =>
    Size(math.max(20, width * 0.4), math.max(16, width * 0.3));

/// Where the pennant of the flag of [edge] sits on a dial of [size], when the
/// flag is at [time] of [window]: A on the inner part of the ring and B on the
/// outer, so that the two stay in reach when close, and each pennant moved
/// along the ring by half its width towards the passage.
Offset gripCenter(LoopEdge edge, RingWindow window, Duration time, Size size) {
  final dial = DialGeometry(size);
  final angle = window.angleOf(time);
  final start = edge == LoopEdge.start;
  final r = dial.ringInner + dial.ringWidth * (start ? 0.25 : 0.75);
  final pole = dial.center + Offset(math.sin(angle), -math.cos(angle)) * r;
  final half = pennantSize(dial.ringWidth).width / 2;
  // Clockwise tangent at the angle; the start's pennant goes with the clock,
  // the end's against it.
  final tangent = Offset(math.cos(angle), math.sin(angle));
  return pole + tangent * (start ? half : -half);
}

/// Where the flag of [edge] waits, in a lower corner of a dial of [size]: a
/// 48 dp target touching the sides of the square, on the lower diagonals
/// (A on the left, B on the right).
Offset holderCenter(LoopEdge edge, Size size) {
  final dial = DialGeometry(size);
  final d = dial.radius - gripReach;
  return dial.center + Offset(edge == LoopEdge.start ? -d : d, d);
}

/// The flag on the ring under a touch at [at] on a dial of [size], or null.
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
    // The distance to the pole: the touch along it, kept on it.
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

/// The Player's dial: the ring is the clock of the track (a whole turn is
/// its length, from 12 o'clock clockwise), with a tick every minute and a
/// point where it is listened to; the middle plays and pauses, or, with no
/// track, opens the file chooser. Touching the ring moves the listening
/// point. The passage that repeats is chosen with the flags A and B that wait
/// in the lower corners: drag one onto the ring, or touch it and then the
/// ring (RF-PLY-08).
class PlayerDial extends StatefulWidget {
  const PlayerDial({super.key, required this.player});

  final PlayerController player;

  /// Marks the middle of the dial, for tests.
  static const hubKey = Key('playerHub');

  /// How far the ring's slider moves the listening point for one step of a
  /// screen reader's increase or decrease.
  static const readerStep = Duration(seconds: 10);

  @override
  State<PlayerDial> createState() => _PlayerDialState();
}

class _PlayerDialState extends State<PlayerDial>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _read());

  /// Where the track is, read every frame while it plays.
  final _position = ValueNotifier<Duration>(Duration.zero);

  /// The same in whole seconds: the clock in the middle changes once a
  /// second only.
  final _seconds = ValueNotifier<int>(0);

  /// The size of the dial, for the gestures.
  var _size = Size.zero;

  /// The flag under the finger, if one is dragged: where the finger went down
  /// (a corner or the ring), where the finger is, and, on the ring, the time
  /// under it. A flag taken from the ring keeps its distance in time from the
  /// finger.
  LoopEdge? _carried;
  var _fromRing = false;
  var _moved = false;
  var _downAt = Offset.zero;
  var _finger = Offset.zero;
  Duration? _carriedAt;
  var _gripOffset = Duration.zero;
  var _fingerAt = Duration.zero;
  var _wasOnRing = false;

  /// True when the phone asks for no animation.
  var _reduce = false;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_sync);
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
    _ticker.dispose();
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
  }

  RingWindow get _window {
    final player = widget.player;
    return RingWindow.whole(
      player.status == PlayerStatus.ready ? player.duration : Duration.zero,
    );
  }

  /// The time under a touch at [at]. While a flag is dragged, the touch
  /// cannot go round past 12 o'clock: it stops at the start or the end of the
  /// track.
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

  /// True where a flag may be put: from the hub's edge to a little beyond
  /// the ring.
  bool _inBand(Offset at) {
    final g = DialGeometry(_size);
    final d = (at - g.center).distance;
    return d >= g.hub && d <= g.ringOuter + _bandMargin;
  }

  /// The flag under a point of the dial: on the ring first, else one waiting
  /// in its corner (a corner inside the ring belongs to the ring).
  LoopEdge? _flagAt(Offset at) {
    final player = widget.player;
    if (player.status != PlayerStatus.ready || _size.isEmpty) return null;
    final onRing = gripAt(
      at,
      _size,
      _window,
      start: player.loopStart,
      end: player.loopEnd,
    );
    if (onRing != null) return onRing;
    return _holderAt(at);
  }

  LoopEdge? _holderAt(Offset at) {
    final dial = DialGeometry(_size);
    if ((at - dial.center).distance <= dial.ringOuter) return null;
    for (final edge in LoopEdge.values) {
      if ((at - holderCenter(edge, _size)).distance <= gripReach) return edge;
    }
    return null;
  }

  void _flagDown(DragDownDetails details) {
    final edge = _flagAt(details.localPosition);
    _carried = edge;
    _moved = false;
    if (edge == null) return;
    final player = widget.player;
    final onRing = gripAt(
      details.localPosition,
      _size,
      _window,
      start: player.loopStart,
      end: player.loopEnd,
    );
    _fromRing = onRing != null;
    _downAt = _finger = details.localPosition;
    _carriedAt = null;
    _wasOnRing = _fromRing;
    if (_fromRing) {
      final end = edge == LoopEdge.start ? player.loopStart : player.loopEnd;
      _fingerAt = _timeAt(details.localPosition);
      _gripOffset = (end ?? _fingerAt) - _fingerAt;
    }
  }

  void _flagMove(DragUpdateDetails details) {
    final edge = _carried;
    if (edge == null) return;
    // A touch that wanders a little is still a touch.
    if (!_moved) {
      if ((details.localPosition - _downAt).distance < kTouchSlop) return;
      _moved = true;
      HapticFeedback.selectionClick();
    }
    _finger = details.localPosition;
    if (_fromRing) {
      final window = _window;
      _fingerAt = _timeAt(details.localPosition, last: _fingerAt);
      final to = _fingerAt + _gripOffset;
      // Stops at the ends of the track, and at a second from the other flag
      // (the player decides).
      widget.player.moveEdge(
        edge,
        to < window.from ? window.from : (to > window.to ? window.to : to),
      );
      setState(() {});
      return;
    }
    final onRing = _inBand(details.localPosition);
    if (onRing) {
      _carriedAt = _timeAt(details.localPosition, last: _carriedAt);
    } else {
      _carriedAt = null;
    }
    if (onRing != _wasOnRing) HapticFeedback.selectionClick();
    _wasOnRing = onRing;
    setState(() {});
  }

  void _flagEnd() {
    final edge = _carried;
    if (edge == null) return;
    final moved = _moved, at = _carriedAt, fromRing = _fromRing;
    setState(() {
      _carried = null;
      _carriedAt = null;
      _moved = false;
    });
    final player = widget.player;
    if (!moved) {
      // Touched, not dragged (the touch recogniser lost the pointer to the
      // drag): a corner arms its flag, a flag on the ring becomes the one the
      // arrows move.
      if (fromRing) {
        player.focus(edge);
      } else {
        player.arm(edge);
      }
      return;
    }
    if (!fromRing && at != null) player.place(edge, at);
  }

  void _seekBy(Duration by) {
    final player = widget.player;
    player.seek(player.position + by);
  }

  void _tap(Offset at) {
    final player = widget.player;
    if (player.status != PlayerStatus.ready || _size.isEmpty) return;
    // The middle is the button's.
    if (_inHub(at)) return;
    final dial = DialGeometry(_size);
    if ((at - dial.center).distance > dial.radius) return;
    final armed = player.armed;
    final time = _timeAt(at);
    if (armed != null) {
      player.place(armed, time);
    } else {
      player.seek(time);
    }
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
    final window = _window;
    final peaks = player.peaks;
    final carried = _carried != null && _moved ? _carried : null;
    // The flag dragged to the ring hides the other when it would be pushed
    // out of its place: it is drawn as a trace and goes back to its corner.
    final stretch = (player.loopStart, player.loopEnd);
    final loopOn = player.looping;
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

    // The time the middle shows for the flag held.
    Duration? heldAt;
    if (carried != null) {
      heldAt = _fromRing
          ? (carried == LoopEdge.start ? player.loopStart : player.loopEnd)
          : _carriedAt;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Drawn again only when the track changes.
            RepaintBoundary(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _RingPainter(
                    window: window,
                    fill: theme.colorScheme.outlineVariant,
                    edge: theme.colorScheme.outline,
                    tick: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            // The wave fills in as the file is read (RF-PLY-15); a track
            // with none (too long for a web page) has none.
            if (ready && peaks != null)
              RepaintBoundary(
                child: ExcludeSemantics(
                  child: ListenableBuilder(
                    listenable: peaks,
                    builder: (context, _) => AnimatedOpacity(
                      opacity: peaks.length > 0 ? 1 : 0,
                      duration: _reduce ? Duration.zero : Durations.medium1,
                      curve: Easing.standard,
                      child: CustomPaint(
                        painter: RingWave(
                          peaks: peaks,
                          window: window,
                          color: theme.colorScheme.onSurfaceVariant,
                          passage: loopOn ? (stretch.$1!, stretch.$2!) : null,
                          passageColor: LowEndColors.of(context).activeFill,
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
                    painter: _FlagsPainter(
                      window: window,
                      start: _shown(LoopEdge.start, player, carried),
                      end: _shown(LoopEdge.end, player, carried),
                      returning: _returning(player, carried),
                      carried: carried,
                      fromRing: _fromRing,
                      carriedAt: _carriedAt,
                      finger: _finger,
                      armed: player.armed,
                      colors: FlagColors.of(theme),
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
              increasedValue: ready
                  ? timeOf(position + PlayerDial.readerStep)
                  : null,
              decreasedValue: ready
                  ? timeOf(position - PlayerDial.readerStep)
                  : null,
              onIncrease: ready ? () => _seekBy(PlayerDial.readerStep) : null,
              onDecrease: ready ? () => _seekBy(-PlayerDial.readerStep) : null,
              // The way to choose a passage without dragging (RF-PLY-16).
              customSemanticsActions: ready
                  ? {
                      CustomSemanticsAction(label: l10n.playerMarkStart): () =>
                          player.mark(LoopEdge.start),
                      CustomSemanticsAction(label: l10n.playerMarkEnd): () =>
                          player.mark(LoopEdge.end),
                    }
                  : null,
              // A flag is dragged at once; anywhere else this does not take
              // part, so that a swipe still changes section.
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                gestures: {
                  FlagDrag: GestureRecognizerFactoryWithHandlers<FlagDrag>(
                    () => FlagDrag(flagAt: _flagAt),
                    (drag) => drag
                      ..onDown = _flagDown
                      ..onUpdate = _flagMove
                      ..onEnd = ((_) => _flagEnd())
                      ..onCancel = _flagEnd,
                  ),
                },
                child: GestureDetector(
                  key: const Key('playerRing'),
                  behavior: HitTestBehavior.opaque,
                  // The slider above says it all to a screen reader; a plain
                  // "tap" on it would do nothing.
                  excludeFromSemantics: true,
                  onTapUp: ready
                      ? (details) => _tap(details.localPosition)
                      : null,
                ),
              ),
            ),
            // The flags in the corners, for a screen reader: a button each,
            // whose activation marks the flag where the track is heard
            // (RF-PLY-16). They take no touch of their own.
            if (ready)
              for (final edge in LoopEdge.values)
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: holderCenter(edge, _size),
                    width: gripReach * 2,
                    height: gripReach * 2,
                  ),
                  child: Semantics(
                    button: true,
                    label: edge == LoopEdge.start
                        ? l10n.playerFlagStart
                        : l10n.playerFlagEnd,
                    onTapHint: edge == LoopEdge.start
                        ? l10n.playerMarkStart
                        : l10n.playerMarkEnd,
                    onTap: () => player.mark(edge),
                    child: const SizedBox.expand(),
                  ),
                ),
            Center(
              child: FractionallySizedBox(
                widthFactor: DialGeometry.hubFraction,
                heightFactor: DialGeometry.hubFraction,
                // Round to the touch as well: the corners of its square
                // would take the flags that sit on the diagonals.
                child: ClipOval(
                  child: _Hub(
                    player: widget.player,
                    seconds: _seconds,
                    decimal: decimal,
                    heldEdge: carried,
                    heldAt: heldAt,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Where the flag of [edge] is on the ring now, or null if it waits in its
  /// corner: the player's, or, for the one carried from a corner, the time
  /// under the finger while it is over the ring.
  Duration? _shown(LoopEdge edge, PlayerController player, LoopEdge? carried) {
    if (carried == edge && !_fromRing) return _carriedAt;
    return edge == LoopEdge.start ? player.loopStart : player.loopEnd;
  }

  /// The flag that would go back to its corner if the one carried were
  /// dropped where it is (RF-PLY-08, rule 2), or null.
  LoopEdge? _returning(PlayerController player, LoopEdge? carried) {
    final at = _carriedAt;
    if (carried == null || _fromRing || at == null) return null;
    final minimum = PlayerController.minLoop;
    if (carried == LoopEdge.start) {
      final end = player.loopEnd;
      return end != null && end - at < minimum ? LoopEdge.end : null;
    }
    final start = player.loopStart;
    return start != null && at - start < minimum ? LoopEdge.start : null;
  }
}

/// How wide the title and artist are, of the middle's diameter (RF-PLY-19).
const _marqueeFraction = 0.8;

/// The middle of the dial: the button that plays and pauses, or asks for a
/// track.
class _Hub extends StatelessWidget {
  const _Hub({
    required this.player,
    required this.seconds,
    required this.decimal,
    required this.heldEdge,
    required this.heldAt,
  });

  final PlayerController player;
  final ValueListenable<int> seconds;
  final String decimal;

  /// The flag held and the time it is at on the ring: the middle then shows
  /// it, to the hundredth. Null while no flag is over the ring.
  final LoopEdge? heldEdge;
  final Duration? heldAt;

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
    Widget content(double diameter) => switch (status) {
      PlayerStatus.empty => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 32,
            color: LowEndColors.of(context).activeFill,
          ),
          Text(l10n.playerChoose, style: muted, textAlign: TextAlign.center),
        ],
      ),
      PlayerStatus.opening => const SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      // No play icon: the time is the clock of the track and the whole middle
      // is the button, as the tempo is on the metronome (RF-PLY-02).
      PlayerStatus.ready => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (player.hasTags)
            SizedBox(
              width: diameter * _marqueeFraction,
              child: Marquee(
                text: [
                  player.title,
                  player.artist,
                ].whereType<String>().join(' \u00b7 '),
                style: muted,
                playing: player.isPlaying,
              ),
            ),
          if (heldEdge != null && heldAt != null)
            // The time of the flag being dragged, to the hundredth.
            Text(
              '${heldEdge == LoopEdge.start ? 'A' : 'B'} ${clockText(heldAt!, hundredths: true, decimalSeparator: decimal)}',
              style: theme.textTheme.headlineSmall,
            )
          else
            ValueListenableBuilder<int>(
              valueListenable: seconds,
              builder: (context, s, _) => Text(
                clockText(Duration(seconds: s), decimalSeparator: decimal),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          if (!player.isPlaying)
            Text(
              l10n.playerHubHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
          child: LayoutBuilder(
            builder: (context, box) => Center(
              child: FractionallySizedBox(
                widthFactor: 0.5 / DialGeometry.hubFraction,
                heightFactor: 0.5 / DialGeometry.hubFraction,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: content(box.biggest.shortestSide),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring and its ticks: a whole ring, off, until a track is open. The
/// ticks sit on the outer edge, clear of the wave (RF-PLY-03).
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.window,
    required this.fill,
    required this.edge,
    required this.tick,
  });

  final RingWindow window;
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
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.window != window ||
      old.fill != fill ||
      old.edge != edge ||
      old.tick != tick;
}

/// The flags A and B (RF-PLY-08): each waits in its corner, solid, until it is
/// on the ring, where its corner shows a trace; the one touched in its corner
/// has a halo; the one dragged follows the finger, over the ring or, outside
/// it, lifted above the finger. A flag about to go back to its corner is a
/// trace on the ring.
class _FlagsPainter extends CustomPainter {
  _FlagsPainter({
    required this.window,
    required this.start,
    required this.end,
    required this.returning,
    required this.carried,
    required this.fromRing,
    required this.carriedAt,
    required this.finger,
    required this.armed,
    required this.colors,
  });

  final RingWindow window;

  /// The time of each flag on the ring, or null while it is in its corner.
  final Duration? start;
  final Duration? end;

  /// The flag that goes back to its corner if the carried one is dropped.
  final LoopEdge? returning;

  /// The flag under the finger; whether it came from the ring; the time
  /// under the finger over the ring, else null; and the finger itself.
  final LoopEdge? carried;
  final bool fromRing;
  final Duration? carriedAt;
  final Offset finger;
  final LoopEdge? armed;
  final FlagColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final dial = DialGeometry(size);
    for (final edge in LoopEdge.values) {
      final startEdge = edge == LoopEdge.start;
      final time = startEdge ? start : end;
      // The corner: ready, or a trace while the flag is on the ring or in
      // the hand; a flag that goes back is ready again.
      final away = (time != null && returning != edge) || carried == edge;
      paintCornerFlag(
        canvas,
        holderCenter(edge, size),
        startEdge,
        away
            ? FlagLook.trace
            : (armed == edge ? FlagLook.armed : FlagLook.solid),
        colors,
      );
      if (time != null && window.length > Duration.zero) {
        final pole = window.angleOf(time);
        final dir = Offset(math.sin(pole), -math.cos(pole));
        final look = returning == edge ? FlagLook.trace : FlagLook.solid;
        paintPole(
          canvas,
          dial.center + dir * dial.ringInner,
          dial.center + dir * dial.ringOuter,
          look,
          colors,
        );
        final box = pennantSize(dial.ringWidth);
        paintPennant(
          canvas,
          Rect.fromCenter(
            center: gripCenter(edge, window, time, size),
            width: box.width,
            height: box.height,
          ),
          startEdge ? 'A' : 'B',
          look,
          colors,
        );
      }
    }
    // Dragged outside the ring, lifted above the finger so that the finger
    // does not cover it.
    final held = carried;
    if (held != null && !fromRing && carriedAt == null) {
      paintCornerFlag(
        canvas,
        finger - const Offset(0, _liftAbove),
        held == LoopEdge.start,
        FlagLook.solid,
        colors,
      );
    }
  }

  @override
  bool shouldRepaint(_FlagsPainter old) =>
      old.window != window ||
      old.start != start ||
      old.end != end ||
      old.returning != returning ||
      old.carried != carried ||
      old.fromRing != fromRing ||
      old.carriedAt != carriedAt ||
      old.finger != finger ||
      old.armed != armed ||
      old.colors != colors;
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
