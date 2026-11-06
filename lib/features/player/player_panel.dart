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
/// middle plays and pauses; the passage that repeats is drawn and adjusted on
/// the ring itself. Under the dial: a line of messages, the field that names
/// the track (it opens the chooser again) with the speed, and the ends A and B
/// of the passage with the loop switch between them, each end moved by a
/// hundredth of a second at a touch.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  /// Marks the field that names the track, for tests.
  static const trackFieldKey = Key('playerTrack');

  /// Mark the speed field, the loop switch, the line of messages and the
  /// − and + of each end, for tests.
  static const speedFieldKey = Key('playerSpeed');
  static const loopSwitchKey = Key('playerLoop');
  static const messageKey = Key('playerMessage');
  static const startEarlierKey = Key('playerStartEarlier');
  static const startLaterKey = Key('playerStartLater');
  static const endEarlierKey = Key('playerEndEarlier');
  static const endLaterKey = Key('playerEndLater');

  /// The speeds offered in the sheet, in percent.
  static const speedShortcuts = [50, 60, 70, 75, 80, 90, 100, 110, 125];

  @override
  Widget build(BuildContext context) {
    final player = AudioScope.of(context).player;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final ready = player.status == PlayerStatus.ready;
        return DialLayout(
          dial: PlayerDial(player: player),
          header: _MessageRow(player: player),
          upper: Row(
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
          lower: _PassageRow(player: player),
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

/// A time with its hundredth, in the player's language ("1:12,34").
String _hundredths(Duration time, AppLocalizations l10n) => clockText(
  time,
  hundredths: true,
  decimalSeparator: l10n.localeName == 'en' ? '.' : ',',
);

/// The first row, under the dial: a word on what is wrong with the file, or
/// else how to choose the passage that repeats and, once there is one, how to
/// adjust it (RF-PLY-18). Nothing without a track.
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.player});

  final PlayerController player;

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
    final String? text =
        problem ??
        (ready
            ? (player.hasLoop ? l10n.playerHintGrips : l10n.playerHintDraw)
            : null);
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

/// The third row: the start A with its − and +, the switch that repeats the
/// passage, and the end B with its − and + (RF-PLY-10, RF-PLY-12). A touch
/// moves an end by a hundredth of a second; held, faster, then by a tenth.
class _PassageRow extends StatelessWidget {
  const _PassageRow({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = player.status == PlayerStatus.ready;
    return Row(
      children: [
        Expanded(
          child: _EdgeGroup(
            player: player,
            edge: LoopEdge.start,
            letter: 'A',
            time: player.loopStart,
            name: (t) => l10n.playerStartAt(t),
            unmarked: l10n.playerStartUnmarked,
            earlier: l10n.playerStartEarlier,
            later: l10n.playerStartLater,
            earlierKey: PlayerPanel.startEarlierKey,
            laterKey: PlayerPanel.startLaterKey,
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
        const SizedBox(width: rowGap),
        Expanded(
          child: _EdgeGroup(
            player: player,
            edge: LoopEdge.end,
            letter: 'B',
            time: player.loopEnd,
            name: (t) => l10n.playerEndAt(t),
            unmarked: l10n.playerEndUnmarked,
            earlier: l10n.playerEndEarlier,
            later: l10n.playerEndLater,
            earlierKey: PlayerPanel.endEarlierKey,
            laterKey: PlayerPanel.endLaterKey,
          ),
        ),
      ],
    );
  }
}

/// One end of the passage: its time ("A 1:12,34", "A –" while not marked),
/// and under it the − and + that move it.
class _EdgeGroup extends StatelessWidget {
  const _EdgeGroup({
    required this.player,
    required this.edge,
    required this.letter,
    required this.time,
    required this.name,
    required this.unmarked,
    required this.earlier,
    required this.later,
    required this.earlierKey,
    required this.laterKey,
  });

  final PlayerController player;
  final LoopEdge edge;
  final String letter;
  final Duration? time;

  /// What a screen reader says for a time, and while there is none.
  final String Function(String time) name;
  final String unmarked;
  final String earlier;
  final String later;
  final Key earlierKey;
  final Key laterKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final at = time;
    final ready = player.status == PlayerStatus.ready;
    final marked = ready && at != null;
    Duration size(int unit) =>
        unit == 1 ? PlayerController.fineStep : PlayerController.coarseStep;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: at == null ? unmarked : name(_hundredths(at, l10n)),
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              at == null ? '$letter –' : '$letter ${_hundredths(at, l10n)}',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StepButton(
              key: earlierKey,
              icon: Icons.remove,
              tooltip: earlier,
              onStep: marked
                  ? () => player.nudge(edge, -PlayerController.fineStep)
                  : null,
              onHold: (unit) => player.nudge(edge, -size(unit)),
            ),
            const SizedBox(width: rowGap),
            StepButton(
              key: laterKey,
              icon: Icons.add,
              tooltip: later,
              onStep: marked
                  ? () => player.nudge(edge, PlayerController.fineStep)
                  : null,
              onHold: (unit) => player.nudge(edge, size(unit)),
            ),
          ],
        ),
      ],
    );
  }
}
