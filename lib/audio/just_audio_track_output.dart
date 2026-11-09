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
  /// With [useClipLoop] the loop is a clip of the track repeated by the
  /// system player (gapless on Android). Without it the whole track plays
  /// and a timer jumps back at the end of the stretch: in a browser the clip
  /// would be checked only every 250 ms or so (just_audio_web).
  JustAudioTrackOutput({
    this.useClipLoop = !kIsWeb,
    this.freshPlayerPerTrack = kIsWeb,
  });

  final bool useClipLoop;

  /// With [freshPlayerPerTrack] the browser's player is let go before
  /// another track is opened, and the next load makes a new one.
  /// just_audio_web keeps the player of the first track under the address
  /// of just_audio's list, which never changes: without this a second track
  /// would get the length and the sound of the first.
  final bool freshPlayerPerTrack;

  /// True once a track has been given to the player.
  var _hasTrack = false;

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _state;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;
  final _events = StreamController<TrackEvent>.broadcast();

  /// The track and the player change together: a late event of the one
  /// closed is ignored.
  var _generation = 0;
  var _speed = 1.0;

  /// The stretch that repeats, in the whole track.
  (Duration, Duration)? _loop;

  /// Where the clip begins in the whole track (the player counts from it).
  var _clipStart = Duration.zero;
  var _clipLooping = false;
  var _playing = false;
  Timer? _loopWatch;

  /// How far before the end of the stretch the timer jumps back: the timer
  /// ticks every 16 ms, and the jump itself takes a moment.
  static const _loopLead = Duration(milliseconds: 15);

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
        final loop = _loop;
        if (loop != null && !useClipLoop) {
          // A loop up to the very end of the track.
          ended = false;
          unawaited(player.seek(loop.$1));
          return;
        }
        unawaited(_finish(player));
      } else {
        ended = false;
      }
    });
    if (!kIsWeb) _listenForInterruptions(generation);
    return player;
  }

  Future<void> _finish(AudioPlayer player) async {
    _playing = false;
    _watchLoop();
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
    _loop = null;
    _clipStart = Duration.zero;
    _playing = false;
    _watchLoop();
    try {
      if (_clipLooping) {
        _clipLooping = false;
        await player.setLoopMode(LoopMode.off);
      }
      if (freshPlayerPerTrack && _hasTrack) await player.stop();
      _hasTrack = true;
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
    _playing = true;
    _watchLoop();
    if (player != null) unawaited(player.play());
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _watchLoop();
    await _player?.pause();
  }

  @override
  Duration get position {
    final player = _player;
    return player == null ? Duration.zero : _clipStart + player.position;
  }

  @override
  Future<void> seek(Duration position) async {
    final inside = position - _clipStart;
    await _player?.seek(inside.isNegative ? Duration.zero : inside);
  }

  @override
  Future<void> setLoop(Duration? start, Duration? end) async {
    final loop = start != null && end != null ? (start, end) : null;
    _loop = loop;
    final player = _player;
    if (player == null) return;
    if (useClipLoop) {
      // The clip reloads the source and the player counts from its start:
      // the controller always seeks to where it wants to be afterwards.
      await player.setClip(start: loop?.$1, end: loop?.$2);
      _clipStart = loop?.$1 ?? Duration.zero;
      _clipLooping = loop != null;
      await player.setLoopMode(loop == null ? LoopMode.off : LoopMode.one);
    } else {
      _watchLoop();
    }
  }

  /// Without clips, a timer ticks while a loop plays and jumps back to its
  /// start at its end.
  void _watchLoop() {
    final loop = _loop;
    final watching = !useClipLoop && loop != null && _playing;
    if (!watching) {
      _loopWatch?.cancel();
      _loopWatch = null;
      return;
    }
    _loopWatch ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final stretch = _loop;
      final player = _player;
      if (stretch == null || player == null) return;
      if (player.position >= stretch.$2 - _loopLead) {
        unawaited(player.seek(stretch.$1));
      }
    });
  }

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
    _loop = null;
    _loopWatch?.cancel();
    _loopWatch = null;
    await _state?.cancel();
    await _interruptions?.cancel();
    final player = _player;
    _player = null;
    await player?.dispose();
    await _events.close();
  }
}
