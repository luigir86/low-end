import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_navigation.dart';
import '../../audio/take_recorder.dart';
import 'player_controller.dart';
import 'track_peaks.dart';

/// Where a recording is (RF-PLY-20).
enum RecordingStatus {
  /// Not recording.
  idle,

  /// Asking for the microphone and opening it.
  starting,

  /// The microphone records.
  recording,

  /// Stopping, then opening the take in the Player.
  finishing,
}

/// Why a recording did not start or could not be kept.
enum RecordingProblem { permissionDenied, failed }

/// The Player's recording: REC starts it, Stop opens the take in the Player
/// over the track being studied (which comes back when the take is removed,
/// see [PlayerController.removeRecording]), Discard throws it away.
///
/// It records only with the Player on screen: leaving the tab, opening the
/// settings or sending the app to the background stops it and keeps the
/// take, like Stop. The Player is paused while it records, and playing it
/// stops the recording.
class RecordingController extends ChangeNotifier {
  RecordingController(this._recorder, {required this.player, this.navigation}) {
    navigation?.addListener(_checkVisible);
    player.addListener(_checkPlayer);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  final TakeRecorder _recorder;
  final PlayerController player;
  final AppNavigation? navigation;
  late final AppLifecycleListener _lifecycle;

  var _status = RecordingStatus.idle;
  final _clock = Stopwatch();
  final _elapsed = ValueNotifier<Duration>(Duration.zero);
  final _problems = StreamController<RecordingProblem>.broadcast();
  Timer? _tick;
  Timer? _sampler;
  var _sampling = false;
  TrackPeaks? _levels;
  Future<void>? _startup;
  var _started = false;
  var _ending = false;
  var _disposed = false;

  RecordingStatus get status => _status;

  /// True from REC until the take is kept or thrown away.
  bool get active => _status != RecordingStatus.idle;

  /// How long the take is so far, updated every second.
  ValueListenable<Duration> get elapsed => _elapsed;

  /// How often the microphone's loudness is read for the wave.
  static const sampleEvery = Duration(milliseconds: 100);

  /// The loudness of the take so far, drawn in the ring while it records;
  /// null before the microphone records and once the take is kept or thrown
  /// away.
  TrackPeaks? get levels => _levels;

  /// A recording that did not start (no microphone allowed, microphone
  /// busy) or a take that could not be kept; the screen says it.
  Stream<RecordingProblem> get problems => _problems.stream;

  /// Starts recording a take; its file is called [label] and the time.
  /// Pauses the Player first. Does nothing if a recording is under way.
  Future<void> start({String label = 'Low End'}) {
    if (active || _disposed) return Future.value();
    _status = RecordingStatus.starting;
    _started = _ending = false;
    _elapsed.value = Duration.zero;
    notifyListeners();
    return _startup = _start(label);
  }

  Future<void> _start(String label) async {
    try {
      await player.stop();
      if (_ending || _disposed) return;
      if (!await _recorder.requestPermission()) {
        if (!_ending && !_disposed) _fail(RecordingProblem.permissionDenied);
        return;
      }
      if (_ending || _disposed) return;
      final stamp = DateTime.now()
          .toIso8601String()
          .split('.')
          .first
          .replaceAll(':', '-')
          .replaceFirst('T', ' ');
      await _recorder.start('$label $stamp.${_recorder.extension}');
      _started = true;
      if (_ending || _disposed) return;
      _status = RecordingStatus.recording;
      _clock
        ..reset()
        ..start();
      _tick = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _elapsed.value = _clock.elapsed,
      );
      _levels = TrackPeaks(fullScale: true);
      _sampler = Timer.periodic(sampleEvery, (_) => _sample());
      notifyListeners();
    } catch (error) {
      debugPrint('The recording could not start: $error');
      if (!_ending && !_disposed) _fail(RecordingProblem.failed);
    }
  }

  /// Reads how loud the microphone is and adds it to [levels] up to the
  /// time on the clock, so that the wave keeps pace with it.
  Future<void> _sample() async {
    final levels = _levels;
    if (_sampling || levels == null) return;
    _sampling = true;
    try {
      final level = await _recorder.level();
      if (levels != _levels || _status != RecordingStatus.recording) return;
      final frames =
          _clock.elapsed.inMicroseconds ~/ TrackPeaks.frame.inMicroseconds -
          levels.length;
      if (frames <= 0) return;
      final peak = (level.clamp(0.0, 1.0) * TrackPeaks.maxValue).round();
      levels.add(Uint16List(frames)..fillRange(0, frames, peak));
    } catch (error) {
      // No reading this time: the wave waits for the next one.
    } finally {
      _sampling = false;
    }
  }

  void _fail(RecordingProblem problem) {
    _problems.add(problem);
    _reset();
  }

  /// Stops the recording. The take opens in the Player, ready to be heard
  /// from its start; with [discard] it is thrown away and the Player stays
  /// as it was.
  Future<void> finish({bool discard = false}) async {
    if (!active || _ending) return;
    _ending = true;
    _status = RecordingStatus.finishing;
    _tick?.cancel();
    _sampler?.cancel();
    _clock.stop();
    notifyListeners();
    try {
      await _startup;
      if (_started) {
        if (discard || _disposed) {
          await _recorder.cancel();
        } else {
          await player.open(await _recorder.stop());
        }
      }
    } catch (error) {
      debugPrint('The take could not be kept: $error');
      if (!_disposed) _problems.add(RecordingProblem.failed);
    } finally {
      if (!_disposed) _reset();
    }
  }

  void _reset() {
    _tick?.cancel();
    _sampler?.cancel();
    _levels = null;
    _clock
      ..stop()
      ..reset();
    _status = RecordingStatus.idle;
    _started = _ending = false;
    _startup = null;
    notifyListeners();
  }

  void _checkVisible() {
    final nav = navigation!;
    if (nav.section != AppSection.player || nav.covered) unawaited(finish());
  }

  void _checkPlayer() {
    if (_status == RecordingStatus.recording && player.isPlaying) {
      unawaited(finish());
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(finish());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    navigation?.removeListener(_checkVisible);
    player.removeListener(_checkPlayer);
    _lifecycle.dispose();
    _tick?.cancel();
    _sampler?.cancel();
    final startup = _startup;
    unawaited(() async {
      try {
        await startup;
        if (_started) await _recorder.cancel();
      } catch (_) {
      } finally {
        await _recorder.dispose();
      }
    }());
    _elapsed.dispose();
    _problems.close();
    super.dispose();
  }
}
