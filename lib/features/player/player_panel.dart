import 'package:flutter/material.dart';

import '../../audio/audio_scope.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import '../../widgets/choice_menu.dart';
import '../../widgets/number_sheet.dart';
import '../../widgets/row_controls.dart';
import '../../widgets/step_button.dart';
import 'clock_text.dart';
import 'player_controller.dart';
import 'player_dial.dart';

/// The Player: plays a track of the person's own, chosen with the system's
/// file chooser. The ring of the dial is the clock of the track and the
/// middle plays and pauses; the field under it names the track and opens
/// the chooser again. Under it the speed, and the loop: the ends A and B, set
/// where the track is heard or moved by tenths of a second.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  /// Marks the field that names the track, for tests.
  static const trackFieldKey = Key('playerTrack');

  /// Mark the speed field, the loop switch and the two buttons that mark
  /// the ends, for tests.
  static const speedFieldKey = Key('playerSpeed');
  static const loopSwitchKey = Key('playerLoop');
  static const markStartKey = Key('playerMarkStart');
  static const markEndKey = Key('playerMarkEnd');
  static const stepBackKey = Key('playerStepBack');
  static const stepForwardKey = Key('playerStepForward');

  /// The speeds offered in the sheet, in percent.
  static const speedShortcuts = [50, 60, 70, 75, 80, 90, 100, 110, 125];

  @override
  Widget build(BuildContext context) {
    final player = AudioScope.of(context).player;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final problem = switch (player.problem) {
          TrackProblem.unreadable => l10n.playerUnreadable,
          TrackProblem.missing => l10n.playerMissing,
          null => null,
        };
        final ready = player.status == PlayerStatus.ready;
        return DialLayout(
          dial: PlayerDial(player: player),
          header: _LoopRow(player: player),
          upper: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: LabeledField(
                      key: trackFieldKey,
                      label: l10n.playerTrack,
                      value: player.title ?? l10n.playerChoose,
                      // The chooser, at once: a menu comes with more than one
                      // way to get a track.
                      onTap: player.pick,
                    ),
                  ),
                  const SizedBox(width: rowGap),
                  Expanded(
                    flex: 2,
                    child: LabeledField(
                      key: speedFieldKey,
                      label: l10n.playerSpeed,
                      value: '${player.speed}%',
                      onTap: ready ? () => _askSpeed(context, player) : null,
                    ),
                  ),
                ],
              ),
              if (problem != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    problem,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
          lower: _MarkRow(player: player),
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

/// A time with its tenth, in the player's language ("1:12,3").
String _tenths(Duration time, AppLocalizations l10n) => clockText(
  time,
  tenths: true,
  decimalSeparator: l10n.localeName == 'en' ? '.' : ',',
);

/// The first row: which end the − and + move ("A 1:12,3" or "B 1:31,0"; a
/// dash while not marked), and the switch that repeats the stretch.
class _LoopRow extends StatelessWidget {
  const _LoopRow({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = player.status == PlayerStatus.ready;
    Widget label(String letter, Duration? at) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(at == null ? '$letter –' : '$letter ${_tenths(at, l10n)}'),
    );
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<LoopEdge>(
            showSelectedIcon: true,
            segments: [
              ButtonSegment(
                value: LoopEdge.start,
                label: label('A', player.loopStart),
                tooltip: l10n.playerLoopStart,
              ),
              ButtonSegment(
                value: LoopEdge.end,
                label: label('B', player.loopEnd),
                tooltip: l10n.playerLoopEnd,
              ),
            ],
            selected: {player.edge},
            // Always on: choosing an end changes nothing without a track,
            // and a dimmed choice would be too faint to read.
            onSelectionChanged: (chosen) => player.selectEdge(chosen.first),
          ),
        ),
        const SizedBox(width: rowGap),
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
      ],
    );
  }
}

/// The third row: set A and set B where the track is heard, and the − and +
/// that move the end chosen above by a tenth of a second (held: faster, then
/// by a second).
class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = player.status == PlayerStatus.ready;
    final edge = player.edge;
    final marked = edge == LoopEdge.start
        ? player.loopStart != null
        : player.loopEnd != null;
    Duration size(int unit) =>
        unit == 1 ? PlayerController.fineStep : PlayerController.coarseStep;
    return Row(
      children: [
        Expanded(
          child: _MarkButton(
            key: PlayerPanel.markStartKey,
            text: l10n.playerMarkStart,
            onPressed: ready ? () => player.mark(LoopEdge.start) : null,
          ),
        ),
        const SizedBox(width: rowGap),
        Expanded(
          child: _MarkButton(
            key: PlayerPanel.markEndKey,
            text: l10n.playerMarkEnd,
            onPressed: ready ? () => player.mark(LoopEdge.end) : null,
          ),
        ),
        const SizedBox(width: rowGap),
        StepButton(
          key: PlayerPanel.stepBackKey,
          icon: Icons.remove,
          tooltip: edge == LoopEdge.start
              ? l10n.playerStartEarlier
              : l10n.playerEndEarlier,
          onStep: ready && marked
              ? () => player.nudge(edge, -PlayerController.fineStep)
              : null,
          onHold: (unit) => player.nudge(edge, -size(unit)),
        ),
        const SizedBox(width: rowGap),
        StepButton(
          key: PlayerPanel.stepForwardKey,
          icon: Icons.add,
          tooltip: edge == LoopEdge.start
              ? l10n.playerStartLater
              : l10n.playerEndLater,
          onStep: ready && marked
              ? () => player.nudge(edge, PlayerController.fineStep)
              : null,
          onHold: (unit) => player.nudge(edge, size(unit)),
        ),
      ],
    );
  }
}

/// A button of the row as wide as the room it is given.
class _MarkButton extends StatelessWidget {
  const _MarkButton({super.key, required this.text, required this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => RowButton(
      onPressed: onPressed,
      label: SizedBox(
        // Less the button's own padding.
        width: box.maxWidth.isFinite
            ? (box.maxWidth - rowButtonInset).clamp(0, double.infinity)
            : null,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: rowButtonStyle(context)),
        ),
      ),
    ),
  );
}
