// "Open with Low End": an audio file tapped or shared in another app (a
// track a teacher sent on WhatsApp) opens in the Player.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/screen_awake.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
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
}
