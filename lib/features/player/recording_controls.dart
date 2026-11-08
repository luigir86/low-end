import 'package:flutter/material.dart';

import '../../audio/recorded_track.dart';
import '../../audio/system_track_files.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import 'clock_text.dart';
import 'player_controller.dart';
import 'recording_controller.dart';

Future<bool> confirmReplace(BuildContext context, TrackRef? track) async {
  if (track is! RecordedTrack || track.saved) return true;
  final strings = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.takeReplaceQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.takeKeep),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.takeReplace),
            ),
          ],
        ),
      ) ??
      false;
}

/// The track row while recording: the red dot and the time, Stop and
/// Discard (RF-PLY-20). The recording itself is [RecordingController].
class RecordingRow extends StatefulWidget {
  const RecordingRow({required this.recording, super.key});
  final RecordingController recording;
  @override
  State<RecordingRow> createState() => _RecordingRowState();
}

class _RecordingRowState extends State<RecordingRow>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
    vsync: this,
    duration: Durations.extralong1,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    widget.recording.addListener(syncPulse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPulse();
  }

  void syncPulse() {
    if (!mounted) return;
    final on = widget.recording.status == RecordingStatus.recording;
    if (on && !MediaQuery.disableAnimationsOf(context)) {
      if (!pulse.isAnimating) pulse.repeat(min: .4, max: 1, reverse: true);
    } else {
      pulse.stop();
      pulse.value = 1;
    }
  }

  @override
  void dispose() {
    widget.recording.removeListener(syncPulse);
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final recording = widget.recording;
    return ListenableBuilder(
      listenable: recording,
      builder: (context, _) {
        final started = recording.status == RecordingStatus.recording;
        final ending = recording.status == RecordingStatus.finishing;
        return Row(
          children: [
            if (started)
              FadeTransition(
                opacity: pulse,
                child: Icon(
                  Icons.circle,
                  color: Theme.of(context).colorScheme.error,
                  size: 16,
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: started
                  ? ValueListenableBuilder<Duration>(
                      valueListenable: recording.elapsed,
                      builder: (context, time, _) => Text(clockText(time)),
                    )
                  : Text(
                      strings.takeStarting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            FilledButton(
              key: const Key('takeStop'),
              onPressed: started ? recording.finish : null,
              child: Text(strings.takeStop),
            ),
            const SizedBox(width: 4),
            TextButton(
              key: const Key('takeDiscard'),
              onPressed: ending ? null : () => recording.finish(discard: true),
              child: Text(strings.takeDiscard),
            ),
          ],
        );
      },
    );
  }
}

class TakeActions extends StatefulWidget {
  const TakeActions({
    required this.take,
    required this.source,
    required this.player,
    required this.record,
    super.key,
  });
  final RecordedTrack take;
  final PlayerController player;
  final Widget record;
  final Widget Function(String label) source;
  @override
  State<TakeActions> createState() => _TakeActionsState();
}

class _TakeActionsState extends State<TakeActions> {
  bool busy = false;
  Future<void> export(bool share) async {
    final take = widget.take;
    final strings = AppLocalizations.of(context);
    setState(() => busy = true);
    String? message;
    try {
      if (share) {
        if (!await shareRecording(take)) message = strings.takeShareUnavailable;
      } else if (await saveRecording(take)) {
        take.saved = true;
      }
    } catch (e) {
      message = strings.takeError;
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: IgnorePointer(
            ignoring: busy,
            child: widget.source(
              widget.take.saved ? strings.takeSaved : strings.takeTemporary,
            ),
          ),
        ),
        if (widget.take.saved)
          IgnorePointer(ignoring: busy, child: widget.record)
        else
          IconButton.outlined(
            onPressed: busy ? null : () => export(false),
            icon: const Icon(Icons.save_outlined),
            tooltip: strings.takeSave,
          ),
        IconButton.outlined(
          onPressed: busy ? null : () => export(true),
          icon: const Icon(Icons.share_outlined),
          tooltip: strings.takeShare,
        ),
        IconButton.outlined(
          tooltip: widget.take.saved ? strings.takeRemove : strings.takeDelete,
          icon: const Icon(Icons.delete_outline),
          onPressed: busy
              ? null
              : () => widget.player.removeRecording(widget.take),
        ),
      ],
    );
  }
}
