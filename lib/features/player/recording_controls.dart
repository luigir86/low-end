import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../audio/recorded_track.dart';
import '../../audio/system_track_files.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import 'player_controller.dart';

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

Future<void> recordForPlayer(
  BuildContext context,
  PlayerController player,
) async {
  if (!await confirmReplace(context, player.track) || !context.mounted) return;
  await player.stop();
  if (!context.mounted) return;
  final take = await showDialog<RecordedTrack>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _RecordingDialog(),
  );
  if (take != null) {
    await player.open(take);
    if (player.track == take && player.status == PlayerStatus.ready) {
      await player.setLoop(Duration.zero, player.duration);
    }
  }
}

class _RecordingDialog extends StatefulWidget {
  const _RecordingDialog();
  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog>
    with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  Future<void>? startup;
  final elapsed = Stopwatch();
  Timer? timer;
  String? error;
  late String name;
  bool stopping = false;
  bool backgrounded = false;
  bool cancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    startup ??= start();
  }

  Future<void> start() async {
    final strings = AppLocalizations.of(context);
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          setState(
            () => error = kIsWeb
                ? strings.micPermissionDeniedWeb
                : strings.micPermissionDenied,
          );
        }
        return;
      }
      if (!mounted || backgrounded || cancelled) return;
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      name =
          '${strings.takeRecording} ${stamp.replaceFirst('T', ' ')}.${kIsWeb ? 'wav' : 'm4a'}';
      final path = await recordingPath(name);
      if (!mounted || backgrounded || cancelled) return;
      await recorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      elapsed.start();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = strings.takeError);
    }
  }

  Future<void> finish() async {
    if (stopping) return;
    setState(() => stopping = true);
    await startup;
    if (!mounted) return;
    final strings = AppLocalizations.of(context);
    try {
      if (!elapsed.isRunning || error != null) {
        Navigator.pop(context);
        return;
      }
      elapsed.stop();
      timer?.cancel();
      final path = await recorder.stop();
      if (path == null) throw StateError('No recording');
      final track = await recordedTrack(path, name);
      if (mounted) Navigator.pop(context, track);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = strings.takeError;
          stopping = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission prompts can make the app inactive while it is starting.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      backgrounded = true;
      unawaited(finish());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    unawaited((startup ?? Future<void>.value()).whenComplete(recorder.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final seconds = elapsed.elapsed.inSeconds;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(strings.takeRecording),
        content: Text(
          error ??
              (elapsed.isRunning || stopping
                  ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
                  : strings.takeStarting),
        ),
        actions: [
          if (!elapsed.isRunning && !stopping && error == null)
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(context);
              },
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          FilledButton.icon(
            onPressed: stopping || (!elapsed.isRunning && error == null)
                ? null
                : finish,
            icon: Icon(error == null ? Icons.stop : Icons.close),
            label: Text(
              error == null
                  ? strings.takeStop
                  : MaterialLocalizations.of(context).closeButtonLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class TakeActions extends StatefulWidget {
  const TakeActions({required this.take, required this.source, super.key});
  final RecordedTrack take;
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
          child: widget.source(
            widget.take.saved ? strings.takeSaved : strings.takeTemporary,
          ),
        ),
        IconButton(
          onPressed: busy ? null : () => export(false),
          icon: const Icon(Icons.save_outlined),
          tooltip: strings.takeSave,
        ),
        IconButton(
          onPressed: busy ? null : () => export(true),
          icon: const Icon(Icons.share_outlined),
          tooltip: strings.takeShare,
        ),
      ],
    );
  }
}
