import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import 'clock_text.dart';
import 'player_controller.dart';

/// How far apart the ticks of the ring are: a minute, ten seconds for a
/// track of under two minutes, five minutes for one of over twenty
/// (RF-PLY-03).
Duration tickInterval(Duration duration) {
  if (duration < const Duration(minutes: 2)) {
    return const Duration(seconds: 10);
  }
  if (duration > const Duration(minutes: 20)) {
    return const Duration(minutes: 5);
  }
  return const Duration(minutes: 1);
}

/// The times of the ticks, every [tickInterval] after the start, which is
/// the top of the ring and needs none.
List<Duration> tickTimes(Duration duration) {
  final step = tickInterval(duration);
  return [for (var t = step; t < duration; t += step) t];
}

/// Where [position] sits on the ring: 0 is the top, clockwise, a whole turn
/// the whole [duration].
double ringAngle(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  final turn = position.inMicroseconds / duration.inMicroseconds;
  return turn.clamp(0.0, 1.0) * 2 * math.pi;
}

/// The time at [angle] (0 at the top, clockwise): the other way round of
/// [ringAngle].
Duration timeAtAngle(double angle, Duration duration) {
  final turn = (angle % (2 * math.pi)) / (2 * math.pi);
  return Duration(microseconds: (duration.inMicroseconds * turn).round());
}

/// The angle of a touch at [offset] on a dial of [size].
double touchAngle(Offset offset, Size size) {
  final d = offset - DialGeometry(size).center;
  return math.atan2(d.dx, -d.dy) % (2 * math.pi);
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

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_sync);
    _sync();
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

  void _seekBy(Duration by) {
    final player = widget.player;
    player.seek(player.position + by);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = widget.player;
    final ready = player.status == PlayerStatus.ready;
    final duration = player.duration;
    final position = player.position;
    final decimal = l10n.localeName == 'en' ? '.' : ',';
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
        final size = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Drawn again only when the track changes.
            RepaintBoundary(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _RingPainter(
                    duration: ready ? duration : Duration.zero,
                    fill: theme.colorScheme.outlineVariant,
                    edge: theme.colorScheme.outline,
                    tick: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (ready)
              RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _PointPainter(
                      position: _position,
                      duration: duration,
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
              child: GestureDetector(
                key: const Key('playerRing'),
                behavior: HitTestBehavior.opaque,
                // The slider above says it all to a screen reader; a plain
                // "tap" on it would do nothing.
                excludeFromSemantics: true,
                onTapUp: ready
                    ? (details) {
                        final g = DialGeometry(size);
                        // The middle is the button's.
                        if ((details.localPosition - g.center).distance <
                            g.hub) {
                          return;
                        }
                        player.seek(
                          timeAtAngle(
                            touchAngle(details.localPosition, size),
                            duration,
                          ),
                        );
                      }
                    : null,
              ),
            ),
            Center(
              child: FractionallySizedBox(
                widthFactor: DialGeometry.hubFraction,
                heightFactor: DialGeometry.hubFraction,
                child: _Hub(
                  player: widget.player,
                  seconds: _seconds,
                  decimal: decimal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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

/// The ring and its ticks: a whole ring, off, until a track is open.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.duration,
    required this.fill,
    required this.edge,
    required this.tick,
  });

  final Duration duration;
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
    if (duration <= Duration.zero) return;
    final paint = Paint()
      ..color = tick
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final time in tickTimes(duration)) {
      final a = ringAngle(time, duration);
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        dial.center + dir * (dial.ringInner + dial.ringWidth * 0.12),
        dial.center + dir * (dial.ringInner + dial.ringWidth * 0.38),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.duration != duration ||
      old.fill != fill ||
      old.edge != edge ||
      old.tick != tick;
}

/// The point where the track is listened to.
class _PointPainter extends CustomPainter {
  _PointPainter({
    required this.position,
    required this.duration,
    required this.color,
    required this.outline,
  }) : super(repaint: position);

  final ValueListenable<Duration> position;
  final Duration duration;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final dial = DialGeometry(size);
    final at = dial.ringPoint(ringAngle(position.value, duration));
    final radius = dial.ringWidth * 0.3;
    canvas.drawCircle(at, radius + 2, Paint()..color = outline);
    canvas.drawCircle(at, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointPainter old) =>
      old.duration != duration ||
      old.color != color ||
      old.outline != outline ||
      old.position != position;
}
