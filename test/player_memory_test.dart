// The Player comes back as it was left (RF-PLY-13): the settings keep the
// track, its speed and passage; the app puts them back without asking the
// system for anything until the tab is reached, and opens the file at the
// first play.

import 'dart:convert';

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
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/player/player_controller.dart';
import 'package:low_end/features/player/player_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _song = TrackRef(uri: 'content://song', name: 'Blue Bossa.mp3', size: 99);

const _setup = PlayerSetup(
  track: _song,
  duration: Duration(minutes: 5),
  speed: 80,
  loopStart: Duration(seconds: 60),
  loopEnd: Duration(seconds: 90),
  looping: true,
  title: 'Blue Bossa (Dorham)',
  artist: 'Kenny Dorham',
);

class _Open {
  _Open(this.scope, this.output, this.files, this.settings);

  final AudioScope scope;
  final SilentTrackOutput output;
  final FakeTrackFiles files;
  final AppSettings settings;
}

Future<_Open> _open(
  WidgetTester tester,
  AppSettings settings, {
  FakeTrackFiles? files,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final output = SilentTrackOutput();
  final fake = files ?? FakeTrackFiles(next: _song);
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: SilentToneOutput(),
      clickOutput: SilentClickOutput(),
      micInput: FakeMicInput(),
      trackOutput: output,
      trackFiles: fake,
      screenAwake: FakeScreenAwake(),
      settings: settings,
    ),
  );
  await tester.pumpAndSettle();
  return _Open(
    AudioScope.of(tester.element(find.byType(HomeShell))),
    output,
    fake,
    settings,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'seen_guide': true}));

  group('the settings keep the Player', () {
    test('its track, speed and passage for the next launch', () async {
      final settings = await AppSettings.load();
      expect(settings.player, isNull);
      settings.rememberPlayer(_setup);
      await Future<void>.delayed(Duration.zero);

      final again = (await AppSettings.load()).player!;
      expect(again.toJson(), _setup.toJson());
      final prefs = await SharedPreferences.getInstance();
      final json = jsonDecode(prefs.getString('player')!) as Map;
      expect(json['uri'], 'content://song');
      expect(json['speed'], 80);
    });

    test('and forget them when there is no track', () async {
      final settings = await AppSettings.load();
      settings.rememberPlayer(_setup);
      await Future<void>.delayed(Duration.zero);
      settings.rememberPlayer(null);
      await Future<void>.delayed(Duration.zero);
      expect(settings.player, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('player'), isFalse);
      expect((await AppSettings.load()).player, isNull);
    });

    test('and do not hurt the launch when it is unreadable', () async {
      for (final bad in <Object>[
        'not json {',
        '[1, 2]',
        '{"uri": "x"}',
        '{"uri": 4, "name": "a", "duration": 1000}',
        42,
        true,
      ]) {
        SharedPreferences.setMockInitialValues({'player': bad});
        final settings = await AppSettings.load();
        expect(settings.player, isNull, reason: '$bad');
      }
    });

    test('and write again only a change', () async {
      final settings = await AppSettings.load();
      settings.rememberPlayer(_setup);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      // Changed behind its back: a setup that did not change is not written.
      await prefs.setString('player', 'marker');
      settings.rememberPlayer(_setup);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('player'), 'marker');
    });
  });

  group('the app puts the Player back', () {
    testWidgets('on its tab, with the track, the passage and the speed, '
        'looking at the file but not opening it', (tester) async {
      final app = await _open(
        tester,
        AppSettings()
          ..rememberSection(AppSection.player)
          ..rememberPlayer(_setup),
      );
      final player = app.scope.player;
      expect(player.status, PlayerStatus.ready);
      expect(find.text('Blue Bossa (Dorham)'), findsWidgets);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('A 1:00.00'), findsOneWidget);
      expect(find.text('B 1:30.00'), findsOneWidget);
      expect(player.looping, isTrue);
      // Looked at, once, because the tab is on screen; not opened.
      expect(app.files.canReadAsked, [_song]);
      expect(app.output.openCount, 0);
    });

    testWidgets('on another tab it does not even look at the file until the '
        'tab is reached', (tester) async {
      final app = await _open(
        tester,
        AppSettings()
          ..rememberSection(AppSection.metronome)
          ..rememberPlayer(_setup),
      );
      expect(app.files.canReadAsked, isEmpty);
      expect(app.files.peaksAsked, isEmpty);
      expect(app.output.openCount, 0);

      app.scope.navigation.open(AppSection.player);
      await tester.pumpAndSettle();
      expect(app.files.canReadAsked, [_song]);
      expect(app.files.peaksAsked, [_song]);
      // Away and back: it is not looked at again.
      app.scope.navigation.open(AppSection.metronome);
      await tester.pumpAndSettle();
      app.scope.navigation.open(AppSection.player);
      await tester.pumpAndSettle();
      expect(app.files.canReadAsked, [_song]);
      expect(app.output.openCount, 0);
    });

    testWidgets('and opens the file at the first play, from A', (tester) async {
      final app = await _open(
        tester,
        AppSettings()
          ..rememberSection(AppSection.player)
          ..rememberPlayer(_setup),
      );
      await tester.tap(find.byKey(const Key('playerHub')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.output.openCount, 1);
      expect(app.output.opened, _song);
      expect(app.output.playing, isTrue);
      expect(app.output.speed, 0.8);
      expect(app.output.loop, (
        const Duration(seconds: 60),
        const Duration(seconds: 90),
      ));
      expect(app.scope.player.position, const Duration(seconds: 60));
    });

    testWidgets('a file that is gone is said, and forgotten', (tester) async {
      final files = FakeTrackFiles(next: _song)..readable = false;
      final settings = AppSettings()
        ..rememberSection(AppSection.player)
        ..rememberPlayer(_setup);
      final app = await _open(tester, settings, files: files);
      expect(find.text('The file is no longer available.'), findsOneWidget);
      expect(find.text('Choose a track'), findsWidgets);
      expect(app.scope.player.status, PlayerStatus.empty);
      expect(settings.player, isNull);
      expect(files.released, [_song]);
      expect(app.output.openCount, 0);
    });

    testWidgets('and keeps what changes: a new track, the speed, the '
        'passage', (tester) async {
      final settings = AppSettings()..rememberSection(AppSection.player);
      final app = await _open(tester, settings);
      expect(settings.player, isNull);

      await app.scope.player.pick();
      await tester.pumpAndSettle();
      expect(settings.player!.track, _song);
      expect(settings.player!.speed, 100);
      expect(settings.player!.loopStart, isNull);

      app.scope.player.setSpeed(70);
      await app.scope.player.setLoop(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );
      await tester.pumpAndSettle();
      expect(settings.player!.speed, 70);
      expect(settings.player!.loopStart, const Duration(seconds: 10));
      expect(settings.player!.loopEnd, const Duration(seconds: 20));
      expect(settings.player!.looping, isTrue);
      expect(settings.player!.duration, const Duration(minutes: 6));
    });

    testWidgets('and does not forget it while another track opens', (
      tester,
    ) async {
      final settings = AppSettings()
        ..rememberSection(AppSection.player)
        ..rememberPlayer(_setup);
      final app = await _open(tester, settings);
      app.files.next = const TrackRef(uri: 'content://b', name: 'Other.wav');
      await app.scope.player.pick();
      await tester.pumpAndSettle();
      expect(settings.player!.track.uri, 'content://b');
    });
  });
}
