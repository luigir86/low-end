import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../audio/audio_scope.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import '../../widgets/choice_menu.dart';
import '../../widgets/number_sheet.dart';
import '../../widgets/row_controls.dart';
import 'player_controller.dart';
import 'passage_strip.dart';
import 'player_dial.dart';

/// The full-track dial and three fixed rows: waveform, transport, track.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  /// Marks the field that names the track, for tests.
  static const trackFieldKey = Key('playerTrack');

  /// Keys for the speed, loop control and file error.
  static const speedFieldKey = Key('playerSpeed');
  static const loopSwitchKey = Key('playerLoop');
  static const messageKey = Key('playerMessage');

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
          header: _FirstRow(player: player),
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
          ? Row(
              key: const ValueKey('strip'),
              children: [
                Expanded(child: PassageStrip(player: player)),
                if (player.loopStart != null || player.loopEnd != null)
                  PopupMenuButton<VoidCallback>(
                    onSelected: (action) => action(),
                    itemBuilder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return [
                        for (final (edge, earlier, later) in [
                          (
                            LoopEdge.start,
                            l10n.playerStartEarlier,
                            l10n.playerStartLater,
                          ),
                          (
                            LoopEdge.end,
                            l10n.playerEndEarlier,
                            l10n.playerEndLater,
                          ),
                        ])
                          if ((edge == LoopEdge.start
                                  ? player.loopStart
                                  : player.loopEnd) !=
                              null)
                            for (final (text, step) in [
                              (earlier, -PlayerController.fineStep),
                              (later, PlayerController.fineStep),
                            ])
                              PopupMenuItem(
                                value: () => player.nudge(edge, step),
                                child: Text(text),
                              ),
                        PopupMenuItem(
                          value: player.clearPassage,
                          child: Text(l10n.playerNewPassage),
                        ),
                      ];
                    },
                  ),
              ],
            )
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ready = player.status == PlayerStatus.ready;
    final active = player.looping;
    final pending = player.loopStart != null && !player.hasLoop;
    final label = active
        ? l10n.playerLoopActive
        : player.hasLoop
        ? l10n.playerResumeLoop
        : pending
        ? l10n.playerCaptureEnd
        : l10n.playerCaptureStart;
    final colors = LowEndColors.of(context);
    final enabled = ready && player.duration >= PlayerController.minLoop;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            toggled: player.hasLoop ? active : null,
            child: OutlinedButton(
              key: PlayerPanel.loopSwitchKey,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 52),
                backgroundColor: active
                    ? colors.activeFill
                    : theme.colorScheme.surface,
                foregroundColor: active
                    ? colors.onActiveFill
                    : theme.colorScheme.onSurface,
                side: BorderSide(
                  color: active || pending
                      ? colors.activeFill
                      : theme.colorScheme.outline,
                ),
              ),
              onPressed: enabled ? player.captureOrToggle : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.repeat, size: 18),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
            ),
          ),
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
