import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'track_output.dart';

/// [TrackOutput] from the system's player: ExoPlayer on Android, the
/// browser's audio element in a web page. It reads the file a piece at a
/// time, so a track of any length plays at once and takes no memory.
///
/// The player is made at the first [open], never before (RNF-AVV-01).
class JustAudioTrackOutput implements TrackOutput {
  JustAudioTrackOutput();

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _state;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;
  final _events = StreamController<TrackEvent>.broadcast();

  /// The track and the player change together: a late event of the one
  /// closed is ignored.
  var _generation = 0;
  var _speed = 1.0;

  AudioPlayer _create() {
    final player = AudioPlayer(
      // Headphones pulled out are AudioRoute's business, and two pauses
      // racing leave the notification in the wrong state. A call or another
      // player is told by [_interruptions] below.
      handleInterruptions: false,
    );
    final generation = ++_generation;
    var ended = false;
    _state = player.playerStateStream.listen((state) {
      if (generation != _generation) return;
      // At its end just_audio stays "playing": stop and go back to the
      // start, once.
      if (state.processingState == ProcessingState.completed) {
        if (ended) return;
        ended = true;
        unawaited(_finish(player));
      } else {
        ended = false;
      }
    });
    if (!kIsWeb) _listenForInterruptions(generation);
    return player;
  }

  Future<void> _finish(AudioPlayer player) async {
    await player.pause();
    await player.seek(Duration.zero);
    _events.add(TrackEvent.ended);
  }

  Future<void> _listenForInterruptions(int generation) async {
    final session = await AudioSession.instance;
    if (generation != _generation) return;
    _interruptions = session.interruptionEventStream.listen((event) {
      if (event.begin && event.type != AudioInterruptionType.duck) {
        _events.add(TrackEvent.interrupted);
      }
    });
  }

  @override
  Future<Duration> open(TrackRef track, {Duration at = Duration.zero}) async {
    final player = _player ??= _create();
    final Duration? duration;
    try {
      duration = await player.setAudioSource(
        ProgressiveAudioSource(
          Uri.parse(track.uri),
          options: const ProgressiveAudioSourceOptions(
            androidExtractorOptions: AndroidExtractorOptions(
              // MP3s of variable bitrate: without an index, seeking is off
              // by up to 1% of the length (3.6 s in 6 minutes).
              mp3Flags: AndroidExtractorOptions.flagMp3EnableIndexSeeking,
            ),
          ),
        ),
        initialPosition: at,
      );
    } on PlayerInterruptedException {
      // Another open began before this one ended: the controller drops the
      // late answer.
      rethrow;
    } on PlayerException catch (error) {
      throw TrackOpenException(_problemOf(error), error);
    } on Object catch (error) {
      throw TrackOpenException(TrackProblem.unreadable, error);
    }
    if (duration == null || duration <= Duration.zero) {
      throw TrackOpenException(TrackProblem.unreadable, 'no duration');
    }
    if (_speed != 1.0) await player.setSpeed(_speed);
    return duration;
  }

  /// 2005 and 2006 are Android's file not found and no permission, 2 the
  /// browser's network error for a blob that is gone: the file is missing.
  /// The rest is a file the system cannot play.
  static TrackProblem _problemOf(PlayerException error) => switch (error.code) {
    2005 || 2006 || 2 => TrackProblem.missing,
    _ => TrackProblem.unreadable,
  };

  @override
  Future<void> play() async {
    // The future of play() ends only when the playing stops: awaiting it
    // would hold the controller.
    final player = _player;
    if (player != null) unawaited(player.play());
  }

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Duration get position => _player?.position ?? Duration.zero;

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player?.setSpeed(speed);
  }

  @override
  Stream<TrackEvent> get events => _events.stream;

  @override
  Future<void> close() async {
    _generation++;
    await _state?.cancel();
    await _interruptions?.cancel();
    final player = _player;
    _player = null;
    await player?.dispose();
    await _events.close();
  }
}
