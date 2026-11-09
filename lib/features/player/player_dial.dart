import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;

import '../../app/style.dart';
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
import 'time_scale.dart';
import 'track_peaks.dart';

/// The angle of a touch at [offset] on a dial of [size].
double touchAngle(Offset offset, Size size) {
  final d = offset - DialGeometry(size).center;
  return math.atan2(d.dx, -d.dy) % (2 * math.pi);
}

/// The full-track clock; tap the ring to seek or the hub to play and pause.
class PlayerDial extends StatefulWidget {
  const PlayerDial({
    super.key,
    required this.player,
    this.recordingTime,
    this.takeLevels,
  });

  final PlayerController player;

  /// How long the take is so far, while recording: the ring then shows the
  /// take, not the track.
  final ValueListenable<Duration>? recordingTime;

  /// The loudness of the take so far, drawn as a wave that grows round the
  /// ring while recording (RF-PLY-20).
  final TrackPeaks? takeLevels;

  /// Marks the middle of the dial, for tests.
  static const hubKey = Key('playerHub');

  /// How far the ring's slider moves the listening point for one step of a
  /// screen reader's increase or decrease.
  static const readerStep = Duration(seconds: 10);

  /// How far from the centre of a grip a finger may land and still take it
  /// (a 48 dp target).
  static const gripReach = 24.0;

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

  /// True when the phone asks for no animation.
  var _reduce = false;

  /// The grip held on the ring, and how the finger goes round: the angle
  /// counted on past a whole turn, so that 12 o'clock is a wall, not a jump
  /// from the end to the start.
  LoopEdge? _held;
  var _moved = false;
  var _downAt = Offset.zero;
  var _lastAngle = 0.0;
  var _turn = 0.0;

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
    final recorded = widget.recordingTime;
    if (recorded != null) {
      return RingWindow.whole(recordingTurn(recorded.value));
    }
    final player = widget.player;
    return RingWindow.whole(
      player.status == PlayerStatus.ready ? player.duration : Duration.zero,
    );
  }

  void _seekBy(Duration by) {
    final player = widget.player;
    player.seek(player.position + by);
  }

  void _tap(Offset at) {
    final player = widget.player;
    if (player.status != PlayerStatus.ready || _size.isEmpty) return;
    final dial = PlayerDialGeometry(_size);
    final distance = (at - dial.center).distance;
    if (distance < dial.hub || distance > dial.radius) return;
    player.seek(_window.timeAt(touchAngle(at, _size)));
  }

  /// The centre of the grip of a flag at [time]: on the ring, inside its
  /// outer edge, so that the whole grip can be touched.
  Offset _gripCentre(Duration time) {
    final dial = PlayerDialGeometry(_size);
    final angle = _window.angleOf(time);
    return dial.center +
        Offset(math.sin(angle), -math.cos(angle)) *
            (dial.ringOuter - gripRadius(dial));
  }

  /// The grip under [at], within a 48 dp target; of two, the nearer.
  LoopEdge? _gripAt(Offset at) {
    final player = widget.player;
    if (player.status != PlayerStatus.ready || _size.isEmpty) return null;
    if (widget.recordingTime != null) return null;
    LoopEdge? best;
    var bestAway = double.infinity;
    for (final (edge, time) in [
      (LoopEdge.start, player.loopStart),
      (LoopEdge.end, player.loopEnd),
    ]) {
      if (time == null) continue;
      final away = (at - _gripCentre(time)).distance;
      if (away <= PlayerDial.gripReach && away < bestAway) {
        best = edge;
        bestAway = away;
      }
    }
    return best;
  }

  void _gripDown(DragDownDetails details) {
    _held = _gripAt(details.localPosition);
    _moved = false;
    _downAt = details.localPosition;
    _lastAngle = touchAngle(details.localPosition, _size);
    final edge = _held;
    if (edge == null) return;
    final player = widget.player;
    final time = edge == LoopEdge.start ? player.loopStart! : player.loopEnd!;
    _turn = _window.angleOf(time);
  }

  void _gripMove(DragUpdateDetails details) {
    final edge = _held;
    if (edge == null) return;
    if (!_moved) {
      if ((details.localPosition - _downAt).distance < kTouchSlop) return;
      _moved = true;
      HapticFeedback.selectionClick();
    }
    final angle = touchAngle(details.localPosition, _size);
    var delta = angle - _lastAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _lastAngle = angle;
    _turn += delta;
    final fraction = (_turn / (2 * math.pi)).clamp(0.0, 1.0);
    // The player keeps the flags in order and a second apart.
    widget.player.moveEdge(edge, _window.timeAtFraction(fraction));
  }

  void _gripEnd() {
    final edge = _held;
    if (edge == null) return;
    if (!_moved) widget.player.focus(edge);
    _held = null;
    _moved = false;
  }

  /// The take being recorded as a time on its ring, for the line that
  /// shows where the recording is.
  _TakeTime? _takeTime;

  @override
  Widget build(BuildContext context) {
    final recorded = widget.recordingTime;
    if (recorded == null) return _dial(context);
    // While recording, the ring grows to the next round length when the
    // take reaches the end of the turn.
    return ValueListenableBuilder<Duration>(
      valueListenable: recorded,
      builder: (context, _, _) => _dial(context),
    );
  }

  Widget _dial(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = widget.player;
    final recording = widget.recordingTime != null;
    final take = widget.takeLevels;
    if (take != _takeTime?.levels) {
      _takeTime = take == null ? null : _TakeTime(take);
    }
    final takeTime = _takeTime;
    _reduce = MediaQuery.disableAnimationsOf(context);
    final ready = player.status == PlayerStatus.ready;
    final duration = player.duration;
    final position = player.position;
    final decimal = l10n.localeName == 'en' ? '.' : ',';
    final window = _window;
    final peaks = player.peaks;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        // The middle is smaller than on the other tabs: the times take a
        // band outside the ring.
        final geometry = PlayerDialGeometry(_size);
        final hubFraction = _size.isEmpty
            ? DialGeometry.hubFraction
            : geometry.hub / geometry.radius;
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
                    label: theme.textTheme.bodySmall!.copyWith(
                      fontSize: LowEndType.small,
                      height: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            // The wave fills in as the file is read (RF-PLY-15); a track
            // with none (too long for a web page) has none.
            if (!recording && ready && peaks != null)
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
                          color: LowEndColors.of(context).stepFill,
                          passage: loopOn ? (stretch.$1!, stretch.$2!) : null,
                          passageColor: LowEndColors.of(context).activeFill,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!recording && ready)
              RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _PassageArc(
                      window,
                      player.loopStart,
                      player.loopEnd,
                      _position,
                      loopOn || !player.hasLoop
                          ? LowEndColors.of(context).activeFill
                          : theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            // The take as it is recorded, and where the recording is.
            if (take != null && takeTime != null) ...[
              RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: RingWave(
                      peaks: take,
                      window: window,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
              RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _PlayheadPainter(
                      position: takeTime,
                      window: window,
                      color: theme.colorScheme.onSurface,
                      outline: theme.colorScheme.surface,
                    ),
                  ),
                ),
              ),
            ],
            if (!recording && ready)
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
            // A and B as grips on the ring, to drag round the whole track.
            if (ready && widget.recordingTime == null)
              RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _GripPainter(
                      window: window,
                      start: player.loopStart,
                      end: player.loopEnd,
                      active: player.activeEdge,
                      colors: FlagColors.of(theme),
                    ),
                  ),
                ),
              ),
            // The ring, as a slider for screen readers; a touch on it moves
            // the listening point. The middle is a button above it.
            if (widget.recordingTime == null)
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
                onDecrease: ready
                    ? () => _seekBy(-PlayerDial.readerStep)
                    : null,
                // The way to choose a passage without dragging (RF-PLY-16).
                customSemanticsActions: ready
                    ? {
                        CustomSemanticsAction(
                          label: l10n.playerMarkStart,
                        ): () =>
                            player.mark(LoopEdge.start),
                        CustomSemanticsAction(label: l10n.playerMarkEnd): () =>
                            player.mark(LoopEdge.end),
                      }
                    : null,
                // A grip is dragged at once; elsewhere this does not take
                // part, so that a swipe changes section and a touch seeks.
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  gestures: {
                    FlagDrag: GestureRecognizerFactoryWithHandlers<FlagDrag>(
                      () => FlagDrag(flagAt: _gripAt),
                      (drag) => drag
                        ..onDown = _gripDown
                        ..onUpdate = _gripMove
                        ..onEnd = ((_) => _gripEnd())
                        ..onCancel = _gripEnd,
                    ),
                  },
                  child: GestureDetector(
                    key: const Key('playerRing'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTapUp: ready
                        ? (details) => _tap(details.localPosition)
                        : null,
                  ),
                ),
              ),
            Center(
              child: FractionallySizedBox(
                widthFactor: hubFraction,
                heightFactor: hubFraction,
                // Keep the corners of the hub square available for seeking.
                child: ClipOval(
                  child: widget.recordingTime != null
                      ? Center(
                          child: ValueListenableBuilder<Duration>(
                            valueListenable: widget.recordingTime!,
                            builder: (context, time, _) => Text(
                              clockText(time),
                              style: theme.textTheme.displaySmall,
                            ),
                          ),
                        )
                      : _Hub(
                          player: widget.player,
                          seconds: _seconds,
                          decimal: decimal,
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

/// How wide the title and artist are, of the middle's diameter (RF-PLY-19).
const _marqueeFraction = 0.8;

/// The middle of the dial: the button that plays and pauses, or asks for a
/// track.
class _Hub extends StatelessWidget {
  const _Hub({
    required this.player,
    required this.seconds,
    required this.decimal,
  });

  final PlayerController player;
  final ValueListenable<int> seconds;
  final String decimal;

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
          Text(
            '/ ${clockText(player.duration, decimalSeparator: decimal)}',
            style: muted,
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

/// The ring and the times of the track round it: a whole ring, off, until a
/// track is open; then a tick at round times outside the ring, clear of the
/// wave, with the time on the longer ones (RF-PLY-03).
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.window,
    required this.fill,
    required this.edge,
    required this.tick,
    required this.label,
  });

  final RingWindow window;
  final Color fill;
  final Color edge;
  final Color tick;
  final TextStyle label;

  /// The lengths of the ticks, from the ring outwards, and the room between
  /// a long tick and its time.
  static const _long = 7.0;
  static const _short = 4.0;
  static const _room = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final dial = PlayerDialGeometry(size);
    dial.paintSegment(
      canvas,
      startAngle: 0,
      sweep: 2 * math.pi,
      color: fill,
      border: edge,
    );
    final length = window.length;
    if (length <= Duration.zero) return;
    final scale = TimeScale.of(length);
    final from = dial.ringOuter + DialGeometry.edgeWidth;
    void line(Duration at, double long, double width) {
      final a = window.angleOf(window.from + at);
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        dial.center + dir * from,
        dial.center + dir * (from + long),
        Paint()
          ..color = tick
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final at in scale.ticks(length)) {
      line(at, _short, 1.2);
    }
    for (final at in scale.labels(length)) {
      line(at, _long, 2);
      if (!dial.labelled) continue;
      final text = TextPainter(
        text: TextSpan(text: clockText(window.from + at), style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      final centre = labelCentre(
        dial.center,
        from + _long + _room,
        window.angleOf(window.from + at),
        text.size,
      );
      text.paint(canvas, centre - Offset(text.width, text.height) / 2);
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.window != window ||
      old.fill != fill ||
      old.edge != edge ||
      old.tick != tick ||
      old.label != label;
}

/// The selected passage stays visible even for a track without peaks.
class _PassageArc extends CustomPainter {
  _PassageArc(this.window, this.start, this.end, this.position, this.color)
    : super(repaint: position);
  final RingWindow window;
  final Duration? start;
  final Duration? end;
  final ValueListenable<Duration> position;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final a = start;
    if (a == null || window.length <= Duration.zero) return;
    final dial = PlayerDialGeometry(size);
    final from = window.angleOf(a);
    final sweep = math.max(0.0, window.angleOf(end ?? position.value) - from);
    final radius = dial.ringOuter - 3;
    final pen = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: dial.center, radius: radius),
      from - math.pi / 2,
      sweep,
      false,
      pen,
    );
    for (final angle in [from, if (end != null) from + sweep]) {
      final dir = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        dial.center + dir * (radius - 6),
        dial.center + dir * (radius + 2),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_PassageArc old) =>
      old.start != start ||
      old.end != end ||
      old.window != window ||
      old.color != color ||
      old.position != position;
}

/// The round lengths the ring takes while recording: a turn is the first
/// of them longer than the take.
const recordingTurns = [
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 20),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(minutes: 60),
];

/// How long a whole turn of the ring is for a take [recorded] long so far.
Duration recordingTurn(Duration recorded) {
  for (final turn in recordingTurns) {
    if (recorded < turn) return turn;
  }
  const half = Duration(minutes: 30);
  return half * (recorded.inMicroseconds ~/ half.inMicroseconds + 1);
}

/// The end of the take being recorded, as a time: grows as [levels] does.
class _TakeTime implements ValueListenable<Duration> {
  _TakeTime(this.levels);

  final TrackPeaks levels;

  @override
  Duration get value => TrackPeaks.frame * levels.length;

  @override
  void addListener(VoidCallback listener) => levels.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => levels.removeListener(listener);
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
    final dial = PlayerDialGeometry(size);
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

/// The radius of a grip on a ring of [dial].
double gripRadius(DialGeometry dial) =>
    (dial.ringWidth * 0.24).clamp(10.0, 16.0);

/// A and B on the ring: a round grip with the letter, solid for the flag the
/// strip's arrows move, hollow for the other, as on the strip (RF-PLY-08).
class _GripPainter extends CustomPainter {
  _GripPainter({
    required this.window,
    required this.start,
    required this.end,
    required this.active,
    required this.colors,
  });

  final RingWindow window;
  final Duration? start;
  final Duration? end;
  final LoopEdge active;
  final FlagColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (window.length <= Duration.zero) return;
    final dial = PlayerDialGeometry(size);
    final r = gripRadius(dial);
    for (final (edge, time, letter) in [
      (LoopEdge.start, start, 'A'),
      (LoopEdge.end, end, 'B'),
    ]) {
      if (time == null) continue;
      final angle = window.angleOf(time);
      final centre =
          dial.center +
          Offset(math.sin(angle), -math.cos(angle)) * (dial.ringOuter - r);
      final solid = edge == active || end == null;
      canvas.drawCircle(centre, r + 2, Paint()..color = colors.surface);
      canvas.drawCircle(
        centre,
        r,
        solid
            ? (Paint()..color = colors.primary)
            : (Paint()..color = colors.surface),
      );
      canvas.drawCircle(
        centre,
        r,
        Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final text = TextPainter(
        text: TextSpan(
          text: letter,
          style: (colors.style ?? const TextStyle()).copyWith(
            color: solid ? colors.onPrimary : colors.primary,
            fontWeight: FontWeight.w700,
            fontSize: r * 1.2,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, centre - Offset(text.width, text.height) / 2);
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_GripPainter old) =>
      old.window != window ||
      old.start != start ||
      old.end != end ||
      old.active != active ||
      old.colors != colors;
}
