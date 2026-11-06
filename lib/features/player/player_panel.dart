import 'package:flutter/material.dart';

import '../../audio/audio_scope.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dial.dart';
import '../../widgets/row_controls.dart';
import 'player_dial.dart';

/// The Player: plays a track of the person's own, chosen with the system's
/// file chooser. The ring of the dial is the clock of the track and the
/// middle plays and pauses; the field under it names the track and opens
/// the chooser again.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  /// Marks the field that names the track, for tests.
  static const trackFieldKey = Key('playerTrack');

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
        return DialLayout(
          dial: PlayerDial(player: player),
          upper: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledField(
                key: trackFieldKey,
                label: l10n.playerTrack,
                value: player.title ?? l10n.playerChoose,
                // The chooser, at once: a menu comes with more than one
                // way to get a track.
                onTap: player.pick,
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
          lower: const SizedBox.shrink(),
        );
      },
    );
  }
}
