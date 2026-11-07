import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../app/app_navigation.dart';
import '../../audio/audio_scope.dart';
import '../../audio/recorded_track.dart';
import '../../audio/system_track_files.dart';
import '../../audio/track_output.dart';
import '../../l10n/app_localizations.dart';
import 'clock_text.dart';
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

class RecordingRow extends StatefulWidget {
  const RecordingRow({
    required this.player,
    required this.elapsed,
    required this.onDone,
    super.key,
  });
  final PlayerController player;
  final ValueNotifier<Duration> elapsed;
  final VoidCallback onDone;
  @override
  State<RecordingRow> createState() => _RecordingRowState();
}

class _RecordingRowState extends State<RecordingRow>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final recorder = AudioRecorder();
  final clock = Stopwatch();
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    value: 1,
  );
  AppNavigation? navigation;
  late final Future<void> startup;
  Future<void>? finishing;
  Timer? timer;
  bool started = false;
  bool ending = false;
  late String name;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startup = Future.microtask(start);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AudioScope.of(context).navigation;
    if (navigation != next) {
      navigation?.removeListener(checkVisible);
      navigation = next..addListener(checkVisible);
    }
    syncPulse();
  }

  void syncPulse() {
    if (started && !ending && !MediaQuery.disableAnimationsOf(context)) {
      if (!pulse.isAnimating) pulse.repeat(min: .4, max: 1, reverse: true);
    } else {
      pulse.stop();
      pulse.value = 1;
    }
  }

  void checkVisible() {
    if (navigation?.section != AppSection.player || navigation!.covered) {
      finish();
    }
  }

  Future<void> start() async {
    if (!mounted || ending) return;
    final strings = AppLocalizations.of(context);
    try {
      await widget.player.stop();
      if (!mounted || ending) return;
      if (!await recorder.hasPermission()) {
        if (mounted && !ending) {
          fail(
            kIsWeb
                ? strings.micPermissionDeniedWeb
                : strings.micPermissionDenied,
          );
        }
        return;
      }
      if (!mounted || ending) return;
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      name =
          '${strings.takeRecording} ${stamp.replaceFirst('T', ' ')}.${kIsWeb ? 'wav' : 'm4a'}';
      final path = await recordingPath(name);
      if (!mounted || ending) return;
      await recorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
          numChannels: 1,
        ),
        path: path,
      );
      started = true;
      if (!mounted || ending) return;
      clock.start();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        widget.elapsed.value = clock.elapsed;
      });
      syncPulse();
      setState(() {});
    } catch (_) {
      if (mounted && !ending) fail(strings.takeError);
    }
  }

  void fail(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    widget.onDone();
  }

  void finish({bool discard = false}) {
    if (ending) return;
    ending = true;
    if (discard && !started) {
      widget.onDone();
      return;
    }
    timer?.cancel();
    clock.stop();
    syncPulse();
    setState(() {});
    finishing = complete(discard);
  }

  Future<void> complete(bool discard) async {
    final strings = AppLocalizations.of(context);
    try {
      await startup;
      if (started) {
        if (discard || !mounted) {
          await recorder.cancel();
        } else {
          final path = await recorder.stop();
          if (path == null) throw StateError('Missing recording');
          final take = await recordedTrack(path, name);
          if (mounted) {
            await widget.player.open(take);
          } else {
            await systemTrackFiles().release(take);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.takeError)));
      }
    } finally {
      if (mounted) widget.onDone();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      finish();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    navigation?.removeListener(checkVisible);
    timer?.cancel();
    pulse.dispose();
    unawaited(releaseRecorder());
    super.dispose();
  }

  Future<void> releaseRecorder() async {
    try {
      await startup;
      if (finishing != null) {
        await finishing;
      } else if (started) {
        await recorder.cancel();
      }
    } finally {
      await recorder.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Row(
      children: [
        if (started)
          FadeTransition(
            opacity: pulse,
            child: const Icon(Icons.circle, color: Colors.red, size: 16),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: started
              ? ValueListenableBuilder<Duration>(
                  valueListenable: widget.elapsed,
                  builder: (context, time, _) => Text(clockText(time)),
                )
              : Text(
                  strings.takeStarting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        FilledButton(
          onPressed: started && !ending ? finish : null,
          child: Text(strings.takeStop),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: ending ? null : () => finish(discard: true),
          child: Text(strings.takeDiscard),
        ),
      ],
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
