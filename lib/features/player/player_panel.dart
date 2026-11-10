import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/notice.dart';
import '../../audio/audio_scope.dart';
import '../../audio/recorded_track.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/choice_menu.dart';
import '../../widgets/dial.dart';
import '../../widgets/row_controls.dart';
import 'clock_text.dart';
import 'passage_strip.dart';
import 'player_controller.dart';
import 'player_dial.dart';
import 'recording_controller.dart';
import 'recording_controls.dart';

/// The full-track dial and three fixed rows: waveform, transport, track.
class PlayerPanel extends StatefulWidget {
  const PlayerPanel({super.key});

  /// Marks the field that names the track, for tests.
  static const trackFieldKey = Key('playerTrack');

  /// Keys for the speed, loop control and file error.
  static const speedFieldKey = Key('playerSpeed');
  static const loopSwitchKey = Key('playerLoop');
  static const messageKey = Key('playerMessage');
  static const recordKey = Key('playerRecord');
  static const newPassageKey = Key('playerNewPassage');

  /// The speeds offered in the menu, in percent: the usual steps of study,
  /// from half speed up, a little faster at the end.
  static const speedChoices = [50, 60, 70, 75, 80, 85, 90, 100, 110, 125];

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel>
    with AutomaticKeepAliveClientMixin {
  RecordingController? _recording;
  StreamSubscription<RecordingProblem>? _problems;
  bool _keepAlive = false;

  /// Kept alive while recording, so that sliding away finishes the take
  /// instead of losing the panel under it.
  @override
  bool get wantKeepAlive => _keepAlive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AudioScope.of(context).recording;
    if (next == _recording) return;
    _recording?.removeListener(_syncKeepAlive);
    _problems?.cancel();
    _recording = next..addListener(_syncKeepAlive);
    _problems = next.problems.listen(_showProblem);
  }

  void _syncKeepAlive() {
    final active = _recording!.active;
    if (active == _keepAlive) return;
    _keepAlive = active;
    updateKeepAlive();
  }

  void _showProblem(RecordingProblem problem) {
    if (!mounted) return;
    final strings = AppLocalizations.of(context);
    NoticeHost.of(context).show(switch (problem) {
      RecordingProblem.permissionDenied =>
        kIsWeb ? strings.micPermissionDeniedWeb : strings.micPermissionDenied,
      RecordingProblem.failed => strings.takeError,
    });
  }

  @override
  void dispose() {
    _recording?.removeListener(_syncKeepAlive);
    _problems?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final player = AudioScope.of(context).player;
    final recorder = _recording!;
    final strings = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([player, recorder]),
      builder: (context, _) {
        final recording = recorder.active;
        Widget source(String label, {String? value}) => LabeledField(
          key: PlayerPanel.trackFieldKey,
          label: label,
          value: value ?? player.title ?? strings.playerChoose,
          onTap: () async {
            if (player.track is RecordedTrack &&
                !await confirmReplace(context, player.track)) {
              return;
            }
            await player.pick();
          },
        );
        final rec = RowButton(
          key: PlayerPanel.recordKey,
          tooltip: strings.takeRecord,
          onPressed: () async {
            if (player.track is RecordedTrack &&
                !await confirmReplace(context, player.track)) {
              return;
            }
            if (!context.mounted) return;
            await recorder.start();
          },
          // A small dot in the room of a full icon: as wide as the others.
          label: SizedBox.square(
            dimension: 24,
            child: Icon(
              Icons.circle,
              color: Theme.of(context).colorScheme.error,
              size: 18,
            ),
          ),
        );
        final track = player.track;
        return DialLayout(
          dial: PlayerDial(
            player: player,
            recordingTime: recording ? recorder.elapsed : null,
            takeLevels: recorder.levels,
          ),
          header: IgnorePointer(
            ignoring: recording,
            child: ExcludeSemantics(
              excluding: recording,
              // Off while recording, and seen to be off.
              child: Opacity(
                opacity: recording ? 0.38 : 1,
                child: _FirstRow(player: player),
              ),
            ),
          ),
          upper: AbsorbPointer(
            absorbing: recording,
            child: ExcludeSemantics(
              excluding: recording,
              child: Opacity(
                opacity: recording ? 0.38 : 1,
                child: _ControlRow(player: player),
              ),
            ),
          ),
          lower: recording
              ? RecordingRow(recording: recorder)
              : track is RecordedTrack
              ? TakeActions(
                  key: ValueKey(track.uri),
                  take: track,
                  player: player,
                  source: (label) =>
                      source(label, value: clockText(player.duration)),
                  record: rec,
                )
              : Row(
                  children: [
                    Expanded(child: source(strings.playerTrack)),
                    const SizedBox(width: rowGap),
                    rec,
                  ],
                ),
        );
      },
    );
  }
}

/// Show file errors in the space normally occupied by the waveform.
class _FirstRow extends StatelessWidget {
  const _FirstRow({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final strip = player.status == PlayerStatus.ready && player.problem == null;
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Durations.medium2,
      switchInCurve: Easing.standard,
      switchOutCurve: Easing.standard,
      child: strip
          ? PassageStrip(key: const ValueKey('strip'), player: player)
          : _MessageRow(key: const ValueKey('message'), player: player),
    );
  }
}

/// An accessible file error in the waveform row.
class _MessageRow extends StatelessWidget {
  const _MessageRow({super.key, required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = switch (player.problem) {
      TrackProblem.unreadable => l10n.playerUnreadable,
      TrackProblem.missing => l10n.playerMissing,
      null => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Semantics(
      // A fault is announced; the hint is not, it must not speak at every
      // change.
      liveRegion: true,
      child: Text(
        text,
        key: PlayerPanel.messageKey,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.player});

  final PlayerController player;

  /// The short list of speeds, opened under the field.
  Future<void> _chooseSpeed(BuildContext context) async {
    final picked = await showChoiceMenu<int>(
      anchor: context,
      selected: player.speed,
      choices: [
        for (final p in PlayerPanel.speedChoices)
          Choice(value: p, title: '$p%'),
      ],
    );
    if (picked != null) player.setSpeed(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = player.status == PlayerStatus.ready;
    final active = player.looping;
    final pending = player.loopStart != null && !player.hasLoop;
    final capturing = !player.hasLoop;
    final label = active
        ? l10n.playerLoopActive
        : player.hasLoop
        ? l10n.playerResumeLoop
        : pending
        ? l10n.playerCaptureEnd
        : l10n.playerCaptureStart;
    final enabled = ready && player.duration >= PlayerController.minLoop;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Semantics(
            toggled: player.hasLoop ? active : null,
            // The same shape and height as every button of the rows: filled
            // in the accent, like TAP, while it marks a flag or the loop
            // plays; outlined when the loop is off.
            child: RowButton(
              key: PlayerPanel.loopSwitchKey,
              filled: active || capturing,
              onPressed: enabled ? player.captureOrToggle : null,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (capturing)
                    // The point it sets, with its letter, as the handle on
                    // the ring.
                    LetterBadge(pending ? 'B' : 'A')
                  else
                    const Icon(Icons.repeat, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      // One line, as tall as the field beside it; a screen
                      // reader still says it whole.
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: rowGap),
        // Always in its place, off until a point is set: a button that comes
        // and goes is harder to find. Beside the passage button, as REC is
        // beside the track, so that the strip has its whole row.
        RowButton(
          key: PlayerPanel.newPassageKey,
          tooltip: l10n.playerNewPassage,
          label: const Icon(Icons.deselect, size: 24),
          onPressed: player.loopStart != null || player.loopEnd != null
              ? player.clearPassage
              : null,
        ),
        const SizedBox(width: rowGap),
        Expanded(
          child: Builder(
            builder: (field) => LabeledField(
              key: PlayerPanel.speedFieldKey,
              label: l10n.playerSpeed,
              value: '${player.speed}%',
              fitValue: true,
              // Slowed down or sped up: the value in the accent.
              accent: player.speed != 100,
              onTap: ready ? () => _chooseSpeed(field) : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// A circle with its [letter] cut out, in the ink of the button it sits in:
/// the button says which point a touch sets, drawn like the handle that then
/// appears on the ring.
class LetterBadge extends StatelessWidget {
  const LetterBadge(this.letter, {super.key});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final ink =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    final size = MediaQuery.textScalerOf(context).scale(22);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LetterBadgePainter(
          letter: letter,
          ink: ink,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

class _LetterBadgePainter extends CustomPainter {
  _LetterBadgePainter({
    required this.letter,
    required this.ink,
    required this.style,
  });

  final String letter;
  final Color ink;
  final TextStyle? style;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final text = TextPainter(
      text: TextSpan(
        text: letter,
        style: (style ?? const TextStyle()).copyWith(
          // The letter is cut out of the circle: drawn in the clear.
          foreground: Paint()..blendMode = BlendMode.clear,
          fontWeight: FontWeight.w700,
          fontSize: radius * 1.2,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(centre, radius, Paint()..color = ink);
    text.paint(canvas, centre - Offset(text.width, text.height) / 2);
    canvas.restore();
    text.dispose();
  }

  @override
  bool shouldRepaint(_LetterBadgePainter old) =>
      old.letter != letter || old.ink != ink || old.style != style;
}
