import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:low_end/audio/just_audio_track_output.dart';
import 'package:low_end/audio/track_output.dart';

/// The browser's player as just_audio_web is: a list it has seen once is
/// kept by its address, with the tracks it had then.
class _BrowserLikePlatform extends JustAudioPlatform {
  final players = <String, _BrowserLikePlayer>{};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      players[request.id] = _newPlayer(request.id);

  _BrowserLikePlayer _newPlayer(String id) => _BrowserLikePlayer(id);

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await players.remove(request.id)?.events.close();
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    for (final player in players.values) {
      await player.events.close();
    }
    players.clear();
    return DisposeAllPlayersResponse();
  }
}

class _BrowserLikePlayer extends AudioPlayerPlatform {
  _BrowserLikePlayer(super.id);

  final events = StreamController<PlaybackEventMessage>.broadcast();
  final _seen = <String, String>{};

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => const Stream.empty();

  /// The length of a track is in its address: `test:27` lasts 27 seconds.
  Duration? lengthOf(String uri, UriAudioSourceMessage source) =>
      Duration(seconds: int.parse(uri.split(':').last));

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    final list = request.audioSourceMessage as ConcatenatingAudioSourceMessage;
    final first = list.children.first as UriAudioSourceMessage;
    final uri = _seen.putIfAbsent(list.id, () => first.uri);
    final duration = lengthOf(uri, first);
    events.add(
      PlaybackEventMessage(
        processingState: ProcessingStateMessage.ready,
        updateTime: DateTime.now(),
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: duration,
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ),
    );
    return LoadResponse(duration: duration);
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async =>
      DisposeResponse();
}

/// The value of AndroidExtractorOptions.flagMp3EnableIndexSeeking.
const _indexSeeking = 1 << 2;

/// ExoPlayer with an MP3 that has no Xing or VBRI frame and no length in its
/// ID3 tag (`bare:131`): with the index seeking of Mp3Extractor it tells no
/// length until the end of the file (media3 1.4.1, computeSeeker).
class _ExoLikePlatform extends _BrowserLikePlatform {
  final loads = <int>[];

  @override
  _BrowserLikePlayer _newPlayer(String id) => _ExoLikePlayer(id, loads);
}

class _ExoLikePlayer extends _BrowserLikePlayer {
  _ExoLikePlayer(super.id, this.loads);

  /// The MP3 flags of every load, in order.
  final List<int> loads;

  @override
  Duration? lengthOf(String uri, UriAudioSourceMessage source) {
    final flags =
        (source as ProgressiveAudioSourceMessage)
            .options
            ?.androidExtractorOptions
            ?.mp3Flags ??
        0;
    loads.add(flags);
    if (uri.startsWith('bare:') && flags & _indexSeeking != 0) return null;
    return super.lengthOf(uri, source);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    JustAudioPlatform.instance = _BrowserLikePlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => null,
        );
  });

  TrackRef track(int seconds) => TrackRef(uri: 'test:$seconds', name: 'x');

  test('in a browser, the second track gets its own length', () async {
    final output = JustAudioTrackOutput(freshPlayerPerTrack: true);
    addTearDown(output.close);
    expect(await output.open(track(27)), const Duration(seconds: 27));
    expect(await output.open(track(363)), const Duration(seconds: 363));
    expect(await output.open(track(27)), const Duration(seconds: 27));
  });

  test('without a fresh player the fake shows the bug', () async {
    // The fake keeps the first track as just_audio_web 0.4.16 does: the
    // test above means something only while this one fails the same way.
    final output = JustAudioTrackOutput(freshPlayerPerTrack: false);
    addTearDown(output.close);
    await output.open(track(27));
    expect(await output.open(track(363)), const Duration(seconds: 27));
  });

  group('on Android', () {
    late _ExoLikePlatform platform;
    setUp(() => JustAudioPlatform.instance = platform = _ExoLikePlatform());

    test('an MP3 with no length header opens without the index', () async {
      final output = JustAudioTrackOutput(
        useClipLoop: true,
        freshPlayerPerTrack: false,
      );
      addTearDown(output.close);
      final bare = TrackRef(uri: 'bare:131', name: 'symphony.mp3');
      expect(await output.open(bare), const Duration(seconds: 131));
      expect(platform.loads, [_indexSeeking, 0]);
    });

    test('an MP3 with a length header keeps the index', () async {
      final output = JustAudioTrackOutput(
        useClipLoop: true,
        freshPlayerPerTrack: false,
      );
      addTearDown(output.close);
      expect(await output.open(track(363)), const Duration(seconds: 363));
      expect(platform.loads, [_indexSeeking]);
    });
  });
}
