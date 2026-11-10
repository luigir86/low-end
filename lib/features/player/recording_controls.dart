import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/notice.dart';
import '../../audio/recorded_track.dart';
import '../../audio/system_track_files.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/row_controls.dart';
import 'clock_text.dart';
import 'player_controller.dart';
import 'recording_controller.dart';
import 'take_name.dart';

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
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: recording,
      builder: (context, _) {
        final started = recording.status == RecordingStatus.recording;
        final ending = recording.status == RecordingStatus.finishing;
        // The same slots as the track row: the field, then the buttons,
        // REC's place taken by Stop.
        return Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: strings.takeRecording,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                ),
                child: Row(
                  children: [
                    if (started) ...[
                      FadeTransition(
                        opacity: pulse,
                        child: Icon(
                          Icons.circle,
                          color: theme.colorScheme.error,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: started
                          ? ValueListenableBuilder<Duration>(
                              valueListenable: recording.elapsed,
                              builder: (context, time, _) => Text(
                                clockText(time),
                                style: theme.textTheme.bodyLarge,
                              ),
                            )
                          : Text(
                              strings.takeStarting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: rowGap),
            Tooltip(
              message: strings.takeStop,
              excludeFromSemantics: true,
              child: Semantics(
                label: strings.takeStop,
                child: FilledButton(
                  key: const Key('takeStop'),
                  onPressed: started ? recording.finish : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    padding: const EdgeInsets.symmetric(
                      horizontal: rowButtonInset / 2,
                      vertical: rowButtonPadding,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Icon(Icons.stop, size: 24),
                ),
              ),
            ),
            const SizedBox(width: rowGap),
            RowButton(
              key: const Key('takeDiscard'),
              tooltip: strings.takeDiscard,
              onPressed: ending ? null : () => recording.finish(discard: true),
              label: const Icon(Icons.close, size: 24),
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

  /// Asks for the take's name (Take1_9_nov_2026 to start with), then
  /// shares it (straight to WhatsApp if chosen) or saves it.
  Future<void> export(bool share) async {
    final take = widget.take;
    final strings = AppLocalizations.of(context);
    setState(() => busy = true);
    final whatsApp = share && await canShareToWhatsApp();
    if (!mounted) return;
    final choice = await showDialog<TakeExport>(
      context: context,
      builder: (context) =>
          TakeNameDialog(take: take, share: share, whatsApp: whatsApp),
    );
    if (!mounted) return;
    if (choice == null) {
      setState(() => busy = false);
      return;
    }
    widget.player.renameTake(choice.name);
    String? message;
    try {
      if (share) {
        if (!await shareRecording(take, whatsApp: choice.whatsApp)) {
          message = strings.takeShareUnavailable;
        }
      } else if (await saveRecording(take)) {
        take.saved = true;
      }
    } catch (e) {
      message = strings.takeError;
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (message != null) {
      NoticeHost.of(context).show(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final saved = widget.take.saved;
    return Row(
      children: [
        Expanded(
          child: IgnorePointer(
            ignoring: busy,
            child: widget.source(
              saved ? strings.takeSaved : strings.takeTemporary,
            ),
          ),
        ),
        const SizedBox(width: rowGap),
        IgnorePointer(ignoring: busy, child: widget.record),
        const SizedBox(width: rowGap),
        RowButton(
          tooltip: strings.takeSave,
          onPressed: busy || saved ? null : () => export(false),
          label: const Icon(Icons.save_outlined, size: 24),
        ),
        const SizedBox(width: rowGap),
        RowButton(
          tooltip: strings.takeShare,
          onPressed: busy ? null : () => export(true),
          label: const Icon(Icons.share_outlined, size: 24),
        ),
      ],
    );
  }
}

/// The track row for a few seconds after a take not saved was discarded
/// with the X: what happened, and Undo, in the row itself rather than in a
/// notice over the controls. A touch on the field lets the take go now.
class DiscardedRow extends StatelessWidget {
  const DiscardedRow({required this.player, super.key});
  final PlayerController player;

  static const undoKey = Key('takeUndo');

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: LabeledField(
              label: strings.takeRecording,
              value: strings.takeDeleted,
              onTap: player.dismissUndo,
            ),
          ),
        ),
        const SizedBox(width: rowGap),
        RowButton(
          key: undoKey,
          filled: true,
          onPressed: player.undoDiscard,
          label: Text(strings.takeUndo),
        ),
      ],
    );
  }
}

/// What [TakeNameDialog] answers: the take's new name, and whether it goes
/// straight to WhatsApp.
typedef TakeExport = ({String name, bool whatsApp});

/// The take's name, ready to be changed, before it is shared or saved.
/// Sharing offers WhatsApp first when it is on the phone, and the other
/// apps through the system's share window.
class TakeNameDialog extends StatefulWidget {
  const TakeNameDialog({
    required this.take,
    required this.share,
    this.whatsApp = false,
    super.key,
  });
  final RecordedTrack take;
  final bool share;
  final bool whatsApp;

  static const nameKey = Key('takeName');
  static const whatsAppKey = Key('takeWhatsApp');
  static const confirmKey = Key('takeExport');

  @override
  State<TakeNameDialog> createState() => _TakeNameDialogState();
}

class _TakeNameDialogState extends State<TakeNameDialog> {
  // The whole name is selected: typing replaces it.
  late final name = TextEditingController(text: widget.take.fileName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.take.fileName.length,
    );

  @override
  void initState() {
    super.initState();
    name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  String get clean => cleanTakeName(name.text);

  void done({bool whatsApp = false}) {
    if (clean.isEmpty) return;
    Navigator.pop<TakeExport>(context, (name: clean, whatsApp: whatsApp));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final ready = clean.isNotEmpty;
    final extension = widget.take.extension;
    final whatsApp = widget.share && widget.whatsApp;
    return AlertDialog(
      title: Text(widget.share ? strings.takeShare : strings.takeSave),
      content: TextField(
        key: TakeNameDialog.nameKey,
        controller: name,
        autofocus: true,
        maxLength: maxTakeNameLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: strings.takeNameLabel,
          suffixText: extension.isEmpty ? null : '.$extension',
          counterText: '',
        ),
        onSubmitted: (_) => done(whatsApp: whatsApp),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        if (whatsApp) ...[
          TextButton(
            key: TakeNameDialog.confirmKey,
            onPressed: ready ? done : null,
            child: Text(strings.takeShareOther),
          ),
          FilledButton(
            key: TakeNameDialog.whatsAppKey,
            onPressed: ready ? () => done(whatsApp: true) : null,
            child: Text(strings.takeShareWhatsApp),
          ),
        ] else
          FilledButton(
            key: TakeNameDialog.confirmKey,
            onPressed: ready ? done : null,
            child: Text(widget.share ? strings.takeShare : strings.takeSave),
          ),
      ],
    );
  }
}
