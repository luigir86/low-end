import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audio/sound_section.dart';
import '../../audio/track_files.dart';
import '../../audio/track_output.dart';

/// Where the Player stands with its track.
enum PlayerStatus {
  /// No track is open.
  empty,

  /// A track was chosen and the system is getting it ready.
  opening,

  /// The track is open and can play.
  ready,
}

/// The Player: plays one track of the person's own, chosen with the system's
/// file chooser. The sound and the files are outside, behind
/// [TrackOutput] and [TrackFiles], so that it is tested without a phone.
///
/// It plays alone: the app pauses the metronome and Harmony when it starts,
/// and stops it when either of them starts (see low_end_app.dart).
class PlayerController extends ChangeNotifier implements SoundSection {
  PlayerController(this._output, this._files) {
    _events = _output.events.listen(_onEvent);
  }

  final TrackOutput _output;
  final TrackFiles _files;
  late final StreamSubscription<TrackEvent> _events;
  final _interruptions = StreamController<void>.broadcast();

  TrackRef? _track;
  Duration _duration = Duration.zero;
  var _status = PlayerStatus.empty;
  var _playing = false;
  TrackProblem? _problem;
  var _disposed = false;

  /// Counts the tracks opened: what an earlier one answers late is ignored.
  var _generation = 0;

  /// The track chosen, until it is replaced or fails.
  TrackRef? get track => _track;

  PlayerStatus get status => _status;

  /// How long the track is; zero until it is [PlayerStatus.ready].
  Duration get duration => _duration;

  /// True as soon as a start is asked, also while the track is still being
  /// got ready.
  @override
  bool get isPlaying => _playing;

  /// Why the last track could not be opened; null once another is chosen.
  TrackProblem? get problem => _problem;

  /// What stands for the track on screen and in the notification: the name
  /// of the file, without its extension.
  String? get title => _track?.baseName;

  /// Where the track is, in the whole track. Read when needed (a screen
  /// asks every frame while it plays): the controller does not notify as it
  /// goes.
  Duration get position {
    if (_status != PlayerStatus.ready) return Duration.zero;
    final at = _output.position;
    return at > _duration ? _duration : at;
  }

  /// A call, or another player, took the sound: the app pauses the Player
  /// like the other sections (see PauseReason.interrupted).
  Stream<void> get interruptions => _interruptions.stream;

  /// The system's file chooser, then the track chosen opens. The chooser is
  /// the first thing asked: in a web page it works only inside the touch.
  Future<void> pick() async {
    final picked = await _files.pick();
    if (picked == null || _disposed) return;
    await open(picked);
  }

  /// Opens [track], ready to play from its start; the one before is let go.
  /// A problem leaves the Player empty and says why in [problem].
  Future<void> open(TrackRef track) async {
    final generation = ++_generation;
    final old = _track;
    if (_playing) {
      _playing = false;
      unawaited(_output.pause());
    }
    if (old != null && old.uri != track.uri) unawaited(_files.release(old));
    _track = track;
    _duration = Duration.zero;
    _status = PlayerStatus.opening;
    _problem = null;
    notifyListeners();
    try {
      final duration = await _output.open(track);
      if (generation != _generation || _disposed) return;
      _duration = duration;
      _status = PlayerStatus.ready;
      // A start asked while the track opened plays as soon as it is ready.
      if (_playing) await _output.play();
    } on TrackOpenException catch (error) {
      if (generation != _generation || _disposed) return;
      _fail(error.problem);
    } on Object catch (error) {
      debugPrint('The track could not be opened: $error');
      if (generation != _generation || _disposed) return;
      _fail(TrackProblem.unreadable);
    }
    if (!_disposed) notifyListeners();
  }

  void _fail(TrackProblem problem) {
    final failed = _track;
    if (failed != null) unawaited(_files.release(failed));
    _track = null;
    _duration = Duration.zero;
    _status = PlayerStatus.empty;
    _playing = false;
    _problem = problem;
  }

  /// Plays the track from where it is. Without a track it does nothing: the
  /// screen opens the chooser instead.
  @override
  Future<void> start() async {
    if (_track == null || _playing) return;
    _playing = true;
    notifyListeners();
    if (_status == PlayerStatus.ready) await _output.play();
  }

  /// Pauses; the position stays.
  @override
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
    await _output.pause();
  }

  Future<void> toggle() => _playing ? stop() : start();

  /// Moves the listening point to [to], within the track.
  Future<void> seek(Duration to) async {
    if (_status != PlayerStatus.ready) return;
    final clamped = to.isNegative
        ? Duration.zero
        : (to > _duration ? _duration : to);
    await _output.seek(clamped);
    if (!_disposed) notifyListeners();
  }

  /// Clears the message about the last track.
  void clearProblem() {
    if (_problem == null) return;
    _problem = null;
    notifyListeners();
  }

  void _onEvent(TrackEvent event) {
    switch (event) {
      case TrackEvent.ended:
        // The output stopped by itself and went back to the start.
        _playing = false;
        notifyListeners();
      case TrackEvent.interrupted:
        _interruptions.add(null);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _events.cancel();
    _interruptions.close();
    final track = _track;
    if (track != null) unawaited(_files.release(track));
    unawaited(_output.close());
    super.dispose();
  }
}
