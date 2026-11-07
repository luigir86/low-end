import 'package:flutter/material.dart';

import '../../audio/audio_scope.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import '../../widgets/choice_menu.dart';
import '../../widgets/number_sheet.dart';
import '../../widgets/row_controls.dart';
import '../../widgets/step_button.dart';
import 'player_controller.dart';
import 'player_dial.dart';

/// The Player: plays a track of the person's own, chosen with the system's
/// file chooser. The ring of the dial is the clock of the track and the
/// middle plays and pauses; the passage that repeats is chosen with the flags
/// A and B of the dial's corners. Under the dial: a line that says the next
/// step, the loop switch with the arrows that move the active flag and the
/// speed, and the field that names the track (it opens the chooser again).
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  /// Marks the field that names the track, for tests.
  static const trackFieldKey = Key('playerTrack');

  /// Mark the speed field, the loop switch, the line of messages and the
  /// arrows that move the active flag, for tests.
  static const speedFieldKey = Key('playerSpeed');
  static const loopSwitchKey = Key('playerLoop');
  static const messageKey = Key('playerMessage');
  static const earlierKey = Key('playerEarlier');
  static const laterKey = Key('playerLater');

  /// The speeds offered in the sheet, in percent.
  static const speedShortcuts = [50, 60, 70, 75, 80, 90, 100, 110, 125];

  @override
  Widget build(BuildContext context) {
    final player = AudioScope.of(context).player;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        return DialLayout(
          dial: PlayerDial(player: player),
          header: _MessageRow(player: player),
          upper: _ControlRow(player: player),
          lower: LabeledField(
            key: trackFieldKey,
            label: l10n.playerTrack,
            value: player.title ?? l10n.playerChoose,
            // The chooser, at once: a menu comes with more than one way to
            // get a track.
            onTap: player.pick,
          ),
        );
      },
    );
  }

  static Future<void> _askSpeed(
    BuildContext context,
    PlayerController player,
  ) async {
    final l10n = AppLocalizations.of(context);
    final percent = await showNumberSheet(
      context,
      title: l10n.playerSpeedTitle,
      unit: '%',
      current: player.speed,
      min: PlayerController.minSpeed,
      max: PlayerController.maxSpeed,
      shortcuts: [
        for (final p in speedShortcuts) Choice(value: p, title: '$p%'),
      ],
    );
    if (percent != null) player.setSpeed(percent);
  }
}

/// The first row, under the dial: a word on what is wrong with the file, or
/// else how to choose the passage that repeats and, once there is one, how to
/// adjust it (RF-PLY-18). Nothing without a track.
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.player});

  final PlayerController player;

  /// What to do next to choose the passage (RF-PLY-18).
  String _step(AppLocalizations l10n) {
    final armed = player.armed;
    if (armed != null) {
      return armed == LoopEdge.start
          ? l10n.playerHintPlaceStart
          : l10n.playerHintPlaceEnd;
    }
    final a = player.loopStart != null, b = player.loopEnd != null;
    if (a && b) return l10n.playerHintTune;
    if (a) return l10n.playerHintNeedEnd;
    if (b) return l10n.playerHintNeedStart;
    return l10n.playerHintFlags;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problem = switch (player.problem) {
      TrackProblem.unreadable => l10n.playerUnreadable,
      TrackProblem.missing => l10n.playerMissing,
      null => null,
    };
    final ready = player.status == PlayerStatus.ready;
    final String? text = problem ?? (ready ? _step(l10n) : null);
    if (text == null) return const SizedBox.shrink();
    return Semantics(
      // A fault is announced; the hint is not, it must not speak at every
      // change.
      liveRegion: problem != null,
      child: Text(
        text,
        key: PlayerPanel.messageKey,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: problem != null
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The second row: the switch that repeats the passage, the arrows that move
/// the active flag a hundredth of a second (held, faster, then a tenth), and
/// the speed (RF-PLY-10, RF-PLY-12).
class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ready = player.status == PlayerStatus.ready;
    final edge = player.activeEdge;
    final start = edge == LoopEdge.start;
    final placed = ready && (start ? player.loopStart : player.loopEnd) != null;
    final letter = Text(
      start ? 'A' : 'B',
      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    Duration size(int unit) =>
        unit == 1 ? PlayerController.fineStep : PlayerController.coarseStep;
    return Row(
      children: [
        Semantics(
          toggled: player.looping,
          // At least a finger wide: an icon alone is narrower.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: kMinInteractiveDimension,
            ),
            child: RowButton(
              key: PlayerPanel.loopSwitchKey,
              tooltip: l10n.playerLoop,
              // Coloured while the loop repeats.
              filled: player.looping,
              onPressed: ready && player.hasLoop
                  ? () => player.setLooping(!player.looping)
                  : null,
              label: Icon(player.looping ? Icons.repeat_on : Icons.repeat),
            ),
          ),
        ),
        const SizedBox(width: rowGap),
        StepButton(
          key: PlayerPanel.earlierKey,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [const Icon(Icons.chevron_left), letter],
          ),
          tooltip: start ? l10n.playerStartEarlier : l10n.playerEndEarlier,
          onStep: placed
              ? () => player.nudge(edge, -PlayerController.fineStep)
              : null,
          onHold: (unit) => player.nudge(edge, -size(unit)),
        ),
        const SizedBox(width: rowGap),
        StepButton(
          key: PlayerPanel.laterKey,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [letter, const Icon(Icons.chevron_right)],
          ),
          tooltip: start ? l10n.playerStartLater : l10n.playerEndLater,
          onStep: placed
              ? () => player.nudge(edge, PlayerController.fineStep)
              : null,
          onHold: (unit) => player.nudge(edge, size(unit)),
        ),
        const SizedBox(width: rowGap),
        Expanded(
          child: LabeledField(
            key: PlayerPanel.speedFieldKey,
            label: l10n.playerSpeed,
            value: '${player.speed}%',
            onTap: ready ? () => PlayerPanel._askSpeed(context, player) : null,
          ),
        ),
      ],
    );
  }
}
