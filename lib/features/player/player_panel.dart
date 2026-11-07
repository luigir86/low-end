import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../audio/audio_scope.dart';
import '../../audio/recorded_track.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import '../../widgets/choice_menu.dart';
import '../../widgets/number_sheet.dart';
import '../../widgets/row_controls.dart';
import 'player_controller.dart';
import 'passage_strip.dart';
import 'player_dial.dart';
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

  /// The speeds offered in the sheet, in percent.
  static const speedShortcuts = [50, 60, 70, 75, 80, 90, 100, 110, 125];

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();

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

class _PlayerPanelState extends State<PlayerPanel>
    with AutomaticKeepAliveClientMixin {
  bool recording = false;
  final elapsed = ValueNotifier<Duration>(Duration.zero);

  @override
  bool get wantKeepAlive => recording;

  void setRecording(bool value) {
    elapsed.value = Duration.zero;
    setState(() => recording = value);
    updateKeepAlive();
  }

  @override
  void dispose() {
    elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final player = AudioScope.of(context).player;
    final strings = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        Widget source(String label) => LabeledField(
          key: PlayerPanel.trackFieldKey,
          label: label,
          value: player.title ?? strings.playerChoose,
          onTap: () async {
            if (player.track is RecordedTrack &&
                !await confirmReplace(context, player.track)) {
              return;
            }
            await player.pick();
          },
        );
        final rec = Tooltip(
          message: strings.takeRecord,
          child: OutlinedButton.icon(
            onPressed: () => setRecording(true),
            icon: const Icon(Icons.circle, color: Colors.red, size: 14),
            label: const Text('REC'),
          ),
        );
        final track = player.track;
        return DialLayout(
          dial: PlayerDial(
            player: player,
            recordingTime: recording ? elapsed : null,
          ),
          header: IgnorePointer(
            ignoring: recording,
            child: ExcludeSemantics(
              excluding: recording,
              child: _FirstRow(player: player),
            ),
          ),
          upper: AbsorbPointer(
            absorbing: recording,
            child: ExcludeSemantics(
              excluding: recording,
              child: _ControlRow(player: player),
            ),
          ),
          lower: recording
              ? RecordingRow(
                  player: player,
                  elapsed: elapsed,
                  onDone: () => setRecording(false),
                )
              : track is RecordedTrack
              ? TakeActions(
                  key: ValueKey(track.uri),
                  take: track,
                  player: player,
                  source: source,
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
          ? Row(
              key: const ValueKey('strip'),
              children: [
                Expanded(child: PassageStrip(player: player)),
                if (player.loopStart != null || player.loopEnd != null)
                  IconButton(
                    tooltip: AppLocalizations.of(context).playerNewPassage,
                    icon: const Icon(Icons.restart_alt),
                    onPressed: player.clearPassage,
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
                // Change fill and contrasting ink together: a light accent
                // must not briefly keep the inactive white label.
                animationDuration: Duration.zero,
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
