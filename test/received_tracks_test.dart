// "Open with Low End": an audio file tapped or shared in another app (a
// track a teacher sent on WhatsApp) opens in the Player.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/screen_awake.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/system_track_files.dart';
import 'package:low_end/audio/take_recorder.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sent = TrackRef(
  uri: 'file:///data/received/1/Scala di Do lenta.m4a',
  name: 'Scala di Do lenta.m4a',
  size: 1000,
);

void main() {
  testWidgets('a file from another app opens in the Player, on screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'seen_guide': true});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final received = StreamController<TrackRef>();
    addTearDown(received.close);
    final mic = FakeTakeRecorder();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        trackOutput: SilentTrackOutput(),
        trackFiles: FakeTrackFiles(),
        takeRecorder: mic,
        receivedTracks: received.stream,
        screenAwake: FakeScreenAwake(),
        settings: AppSettings()..rememberSection(AppSection.metronome),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    expect(scope.navigation.section, AppSection.metronome);

    received.add(_sent);
    await tester.pumpAndSettle();
    expect(scope.navigation.section, AppSection.player);
    expect(scope.player.track, _sent);
    expect(scope.player.title, 'Scala di Do lenta');
    expect(scope.player.isPlaying, isFalse);
  });

  testWidgets('a file from another app that cannot be taken is said at the '
      'top of the Player, and the next one still opens', (tester) async {
    SharedPreferences.setMockInitialValues({'seen_guide': true});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final received = StreamController<TrackRef>();
    addTearDown(received.close);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        trackOutput: SilentTrackOutput(),
        trackFiles: FakeTrackFiles(),
        receivedTracks: received.stream,
        screenAwake: FakeScreenAwake(),
        settings: AppSettings()..rememberSection(AppSection.metronome),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));

    received.addError(const ReceivedTrackFailed());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(scope.navigation.section, AppSection.player);
    expect(find.text("This file can't be opened."), findsOneWidget);
    final notice = tester.getCenter(find.text("This file can't be opened."));
    expect(notice.dy, lessThan(2400 / 2.625 / 2));
    expect(scope.player.track, isNull);

    received.add(_sent);
    await tester.pumpAndSettle();
    expect(scope.player.track, _sent);
  });

  group('the channel from Android (ReceivedTracks.kt)', () {
    const channel = MethodChannel('low_end/received_tracks');
    const codec = StandardMethodCodec();
    final waitingTrack = {
      'uri': 'file:///data/received/a/Lezione 3.mp3',
      'name': 'Lezione 3.mp3',
      'size': 1000,
    };

    testWidgets('files that came before the Player listened come first, '
        'then each new one', (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final asked = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        asked.add(call.method);
        return [
          waitingTrack,
          {'name': 'no uri'},
        ];
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final tracks = <TrackRef>[];
      final subscription = receivedTracks(android: true).listen(tracks.add);
      addTearDown(subscription.cancel);
      await tester.pump();
      expect(asked, ['ready']);
      expect(tracks, [
        const TrackRef(
          uri: 'file:///data/received/a/Lezione 3.mp3',
          name: 'Lezione 3.mp3',
          size: 1000,
        ),
      ]);
      expect(tracks.single.size, 1000);

      // Android calls "open" for a file that comes while the app runs.
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(
          const MethodCall('open', {
            'uri': 'file:///data/received/b/Scala.m4a',
            'name': 'Scala.m4a',
            'size': 20,
          }),
        ),
        (_) {},
      );
      await tester.pump();
      expect(tracks.map((track) => track.name), ['Lezione 3.mp3', 'Scala.m4a']);
    });

    testWidgets('an Android that does not answer leaves the Player as it is', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'x'),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final tracks = <TrackRef>[];
      final subscription = receivedTracks(android: true).listen(tracks.add);
      addTearDown(subscription.cancel);
      await tester.pump();
      expect(tracks, isEmpty);
    });

    testWidgets('a file Android could not take comes as an error', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        return [
          {'failed': true},
          waitingTrack,
        ];
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final tracks = <TrackRef>[];
      final errors = <Object>[];
      final subscription = receivedTracks(android: true)
          .listen(tracks.add, onError: errors.add);
      addTearDown(subscription.cancel);
      await tester.pump();
      expect(errors, [isA<ReceivedTrackFailed>()]);
      expect(tracks.map((track) => track.name), ['Lezione 3.mp3']);

      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('open', {'failed': true})),
        (_) {},
      );
      await tester.pump();
      expect(errors, hasLength(2));
    });

    test('off Android nothing is asked', () async {
      expect(await receivedTracks(android: false).isEmpty, isTrue);
    });
  });
}
