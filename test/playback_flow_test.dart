// How the sound is started, paused and kept going across the app: each
// section's dial, the pause for the tuner, the countdown, the background
// notification and the lock on the gestures.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/background_audio.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/screen_awake.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _harmonyTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byTooltip('Harmony'),
);
final _playerTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byTooltip('Player'),
);
final _playerTabItem = find.ancestor(
  of: find.byTooltip('Player'),
  matching: find.byType(NavigationDestination),
);
final _metronomeTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byTooltip('Metronome'),
);

/// A [BackgroundAudio] that remembers what the notification shows.
class _RecordingAudio implements BackgroundAudio {
  var state = MediaState.off;
  var title = '';
  var shown = 0;
  final input = StreamController<MediaCommand>.broadcast();

  @override
  Stream<MediaCommand> get commands => input.stream;

  @override
  Future<void> show(
    MediaState state, {
    required String title,
    String text = '',
  }) async {
    this.state = state;
    this.title = title;
    shown++;
  }
}

/// Everything a test wants to look at once the app is open.
class _App {
  _App(
    this.tester,
    this.scope,
    this.tone,
    this.click,
    this.mic,
    this.audio,
    this.track,
  );

  final WidgetTester tester;
  final AudioScope scope;
  final SilentToneOutput tone;
  final SilentClickOutput click;
  final FakeMicInput mic;
  final _RecordingAudio audio;
  final SilentTrackOutput track;

  /// Lets the sound changes (and the animations) run.
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
}

Future<_App> _open(
  WidgetTester tester, {
  Size size = const Size(1080, 2400),
  AppSettings? settings,
  PianoOutput? piano,
  SilentClickOutput? click,
  SilentTrackOutput? track,
  // These tests start from the metronome; the first launch opens on
  // Harmony (see memory_test.dart).
  AppSection opensOn = AppSection.metronome,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final tone = SilentToneOutput();
  final clickOut = click ?? SilentClickOutput();
  final mic = FakeMicInput();
  final audio = _RecordingAudio();
  final trackOut = track ?? SilentTrackOutput();
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: tone,
      clickOutput: clickOut,
      pianoOutput: piano,
      micInput: mic,
      trackOutput: trackOut,
      trackFiles: FakeTrackFiles(),
      backgroundAudio: audio,
      screenAwake: FakeScreenAwake(),
      settings: (settings ?? AppSettings())..rememberSection(opensOn),
    ),
  );
  await tester.pumpAndSettle();
  final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
  return _App(tester, scope, tone, clickOut, mic, audio, trackOut);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'seen_guide': true}));

  group('each dial starts and stops its own sound', () {
    testWidgets('the metronome and the harmony do not start each other', (
      tester,
    ) async {
      final app = await _open(tester);

      await tester.tap(find.text('Tap to start'));
      await app.settle();
      expect(app.click.bar, isNotNull);
      expect(app.tone.frequencies, isEmpty);

      // Going to the harmony starts nothing and stops nothing.
      await tester.tap(_harmonyTab);
      await app.settle();
      expect(app.click.bar, isNotNull);
      expect(app.tone.frequencies, isEmpty);

      await tester.tap(find.bySemanticsLabel(RegExp('^Play(?!er)')).last);
      await app.settle();
      expect(app.tone.frequencies, isNotEmpty);
      expect(app.click.bar, isNotNull);

      // Stopping the harmony leaves the click.
      await tester.tap(find.bySemanticsLabel(RegExp('^Stop the harmony')));
      await app.settle();
      expect(app.tone.frequencies, isEmpty);
      expect(app.click.bar, isNotNull);

      // And the other way round.
      await tester.tap(find.bySemanticsLabel(RegExp('^Play(?!er)')).last);
      await app.settle();
      await tester.tap(_metronomeTab);
      await app.settle();
      await tester.tap(find.bySemanticsLabel(RegExp('^Stop the metronome')));
      await app.settle();
      expect(app.click.bar, isNull);
      expect(app.tone.frequencies, isNotEmpty);
    });

    testWidgets('the tabs only navigate, also the one already open', (
      tester,
    ) async {
      final app = await _open(tester);
      await tester.tap(_metronomeTab);
      await app.settle();
      await tester.tap(_harmonyTab);
      await app.settle();
      await tester.tap(_harmonyTab);
      await app.settle();
      await tester.longPress(_harmonyTab);
      await app.settle();
      expect(app.scope.navigation.section, AppSection.drone);
      expect(app.scope.drone.isPlaying, isFalse);
      expect(app.scope.metronome.isPlaying, isFalse);
      expect(app.click.bar, isNull);
      expect(app.tone.frequencies, isEmpty);
    });
  });

  testWidgets('between two beats the metronome runs no frames', (tester) async {
    final app = await _open(tester);
    await app.scope.metronome.start();
    // The beat is lit, then the ring waits for the next one: no frame is
    // asked for in between (a slow test machine may be past it already).
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final beat = app.scope.metronome.beat;
    expect(beat, isNotNull);
    if (app.scope.metronome.beat == beat) {
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    await app.scope.metronome.stop();
    await app.settle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('coming to the harmony gets the piano ready, silently', (
    tester,
  ) async {
    final piano = SilentPianoOutput();
    final app = await _open(tester, piano: piano);
    expect(piano.prepared, isNull);
    await tester.tap(_harmonyTab);
    await app.settle();
    // What a touch would play, the first time: the giro di Do in A, its four
    // chords (A F#m D E7) each with its root in the bass.
    expect(piano.prepared, hasLength(4));
    expect(
      [for (final chord in piano.prepared!) chord.first % 12],
      [9, 6, 2, 4],
    );
    expect(piano.chords, isNull);
    expect(app.scope.drone.isPlaying, isFalse);
  });

  testWidgets('the piano waits for the sections to stop sliding', (
    tester,
  ) async {
    final piano = SilentPianoOutput();
    final app = await _open(tester, piano: piano);
    // The finger past the middle, still down: the harmony is the section,
    // but reading the piano would hold the slide up in a browser.
    final width = tester.getSize(find.byType(PageView)).width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(Offset(-width * 0.1, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(app.scope.navigation.section, AppSection.drone);
    expect(piano.prepared, isNull);
    await gesture.up();
    await app.settle();
    expect(piano.prepared, hasLength(4));
  });

  group('the tuner pauses what plays', () {
    testWidgets('with nothing playing, it listens and says nothing', (
      tester,
    ) async {
      final app = await _open(tester);
      await tester.tap(find.byTooltip('Tuner'));
      await app.settle();
      expect(app.mic.isCapturing, isTrue);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Resume'), findsNothing);
    });

    for (final (name, metronome, drone) in [
      ('the metronome alone', true, false),
      ('the harmony alone', false, true),
    ]) {
      testWidgets('$name: entering stops nothing, a touch pauses it and '
          'Resume brings back only that', (tester) async {
        final app = await _open(tester);
        if (metronome) await app.scope.metronome.start();
        if (drone) await app.scope.drone.start();
        await app.settle();

        await tester.tap(find.byTooltip('Tuner'));
        await app.settle();
        expect(app.scope.metronome.isPlaying, metronome);
        expect(app.scope.drone.isPlaying, drone);
        expect(app.mic.isCapturing, isFalse);
        expect(find.text('Paused while you tune'), findsNothing);

        await tester.tap(find.byKey(const Key('tunerHub')));
        await app.settle();
        expect(app.scope.metronome.isPlaying, isFalse);
        expect(app.scope.drone.isPlaying, isFalse);
        expect(app.mic.isCapturing, isTrue);
        expect(find.text('Paused while you tune'), findsOneWidget);
        // A pause for the tuner is not a pause from the notification.
        expect(app.audio.state, MediaState.off);

        await tester.tap(find.text('Resume'));
        await app.settle();
        expect(app.scope.metronome.isPlaying, metronome);
        expect(app.scope.drone.isPlaying, drone);
        expect(app.audio.state, MediaState.playing);
      });
    }
  });

  group('the countdown to the other one\'s bar line', () {
    testWidgets('the metronome\'s dial counts the beats, then the tempo', (
      tester,
    ) async {
      final app = await _open(
        tester,
        click: SilentClickOutput()..delay = const Duration(seconds: 3),
      );
      expect(find.text('80'), findsOneWidget);
      await tester.tap(find.text('Tap to start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.scope.metronome.waitLeft, isNotNull);
      // Three seconds at 80 make four beats of 0.75 s (RF-ARM-15).
      expect(app.scope.metronome.beatsLeft, 4);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('80'), findsNothing);

      await app.scope.metronome.stop();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('4'), findsNothing);
      expect(find.text('80'), findsOneWidget);
    });

    testWidgets('the harmony\'s dial counts too, with the chord to come', (
      tester,
    ) async {
      final app = await _open(
        tester,
        piano: SilentPianoOutput()..delay = const Duration(seconds: 2),
      );
      await tester.tap(_harmonyTab);
      await app.settle();
      await app.scope.drone.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.scope.drone.waitLeft, isNotNull);
      // Two seconds at 80 are three beats to go.
      expect(app.scope.drone.beatsLeft, 3);
      expect(find.text('3'), findsOneWidget);

      // The tuner pausing it ends the countdown.
      await tester.tap(find.byTooltip('Tuner'));
      await app.settle();
      await tester.tap(find.byKey(const Key('tunerHub')));
      await app.settle();
      expect(app.scope.drone.waitLeft, isNull);
      expect(app.scope.drone.isPlaying, isFalse);
    });
  });

  group('the notification', () {
    testWidgets('stop takes it away, and a later play does nothing', (
      tester,
    ) async {
      final app = await _open(tester);
      await app.scope.metronome.start();
      await app.scope.drone.start();
      await app.settle();
      expect(app.audio.state, MediaState.playing);

      app.audio.input.add(MediaCommand.stop);
      await app.settle();
      expect(app.scope.metronome.isPlaying, isFalse);
      expect(app.scope.drone.isPlaying, isFalse);
      expect(app.audio.state, MediaState.off);

      app.audio.input.add(MediaCommand.play);
      await app.settle();
      expect(app.scope.metronome.isPlaying, isFalse);
      expect(app.scope.drone.isPlaying, isFalse);
      expect(app.audio.state, MediaState.off);
    });

    testWidgets('stop after a pause also takes it away', (tester) async {
      final app = await _open(tester);
      await app.scope.metronome.start();
      await app.settle();
      app.audio.input.add(MediaCommand.pause);
      await app.settle();
      expect(app.audio.state, MediaState.paused);
      app.audio.input.add(MediaCommand.stop);
      await app.settle();
      expect(app.audio.state, MediaState.off);
      app.audio.input.add(MediaCommand.play);
      await app.settle();
      expect(app.scope.metronome.isPlaying, isFalse);
    });

    testWidgets('pause or play with nothing to pause change nothing', (
      tester,
    ) async {
      final app = await _open(tester);
      app.audio.input.add(MediaCommand.pause);
      await app.settle();
      app.audio.input.add(MediaCommand.play);
      await app.settle();
      expect(app.audio.shown, 0);
      expect(app.scope.metronome.isPlaying, isFalse);
      expect(app.scope.drone.isPlaying, isFalse);
    });

    testWidgets('starting again by hand forgets the pause', (tester) async {
      final app = await _open(tester);
      await app.scope.metronome.start();
      await app.settle();
      app.audio.input.add(MediaCommand.pause);
      await app.settle();
      // The drone is started from the app; then play must not bring the
      // metronome back behind the player's back.
      await app.scope.drone.start();
      await app.settle();
      expect(app.audio.state, MediaState.playing);
      app.audio.input.add(MediaCommand.play);
      await app.settle();
      expect(app.scope.metronome.isPlaying, isFalse);
      expect(app.scope.drone.isPlaying, isTrue);
    });

    testWidgets('the title follows the notes of the settings', (tester) async {
      final settings = AppSettings();
      final app = await _open(tester, settings: settings);
      await app.scope.drone.start();
      await app.settle();
      expect(app.audio.title, 'Harmony A');
      settings.setNaming(NoteNaming.solfege);
      await app.settle();
      expect(app.audio.title, 'Harmony La');
    });

    test(
      'off Android the real notification does nothing and never throws',
      () async {
        final audio = MediaNotificationAudio();
        await audio.show(MediaState.playing, title: 'Metronome 80 BPM');
        await audio.show(MediaState.paused, title: 'Metronome 80 BPM');
        await audio.show(MediaState.off, title: '');
        expect(audio.commands, isA<Stream<MediaCommand>>());
      },
    );
  });

  group('the lock on the gestures', () {
    testWidgets('stops the swipe between sections, in portrait', (
      tester,
    ) async {
      final settings = AppSettings()..setGesturesLocked(true);
      final app = await _open(tester, settings: settings);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await app.settle();
      expect(app.scope.navigation.section, AppSection.metronome);

      settings.setGesturesLocked(false);
      await app.settle();
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await app.settle();
      expect(app.scope.navigation.section, AppSection.drone);
    });

    testWidgets('leaves the tabs, the dials and the sound alone', (
      tester,
    ) async {
      final settings = AppSettings()..setGesturesLocked(true);
      final app = await _open(tester, settings: settings);
      await tester.tap(find.text('Tap to start'));
      await app.settle();
      expect(app.click.bar, isNotNull);

      await tester.tap(_harmonyTab);
      await app.settle();
      expect(app.scope.navigation.section, AppSection.drone);
      await tester.tap(find.bySemanticsLabel(RegExp('^Play(?!er)')).last);
      await app.settle();
      expect(app.tone.frequencies, isNotEmpty);

      // The pause for the tuner is not a gesture.
      await tester.tap(find.byTooltip('Tuner'));
      await app.settle();
      await tester.tap(find.byKey(const Key('tunerHub')));
      await app.settle();
      expect(app.click.bar, isNull);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('stops the vertical flick in landscape, not the rail', (
      tester,
    ) async {
      final settings = AppSettings()..setGesturesLocked(true);
      final app = await _open(
        tester,
        size: const Size(2400, 1080),
        settings: settings,
      );
      Future<void> flick() async {
        await tester.timedDrag(
          find.byKey(const Key('tabRail')),
          const Offset(0, -200),
          const Duration(milliseconds: 150),
        );
        await app.settle();
      }

      await flick();
      expect(app.scope.navigation.section, AppSection.metronome);
      // The same flick works once unlocked.
      settings.setGesturesLocked(false);
      await app.settle();
      await flick();
      expect(app.scope.navigation.section, AppSection.drone);
      settings.setGesturesLocked(true);
      await app.settle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('tabRail')),
          matching: find.text('Tuner'),
        ),
      );
      await app.settle();
      expect(app.scope.navigation.section, AppSection.tuner);
    });

    testWidgets('no hint about swiping while it is locked', (tester) async {
      final settings = await AppSettings.load();
      settings.setGesturesLocked(true);
      await _open(tester, size: const Size(2400, 1080), settings: settings);
      expect(find.textContaining('Swipe up or down'), findsNothing);
      expect(settings.seenSwipeHint, isFalse);
    });

    testWidgets('the switch in the settings sets and clears it', (
      tester,
    ) async {
      final settings = AppSettings();
      final app = await _open(tester, settings: settings);
      await tester.tap(find.byTooltip('Settings'));
      await app.settle();
      await tester.scrollUntilVisible(find.text('Lock the gestures'), 200);
      await app.settle();
      await tester.tap(find.text('Lock the gestures'));
      await app.settle();
      expect(settings.gesturesLocked, isTrue);
      await tester.tap(find.text('Lock the gestures'));
      await app.settle();
      expect(settings.gesturesLocked, isFalse);
    });
  });
  // RF-PLY-04, RF-PLY-05: the Player plays alone.
  group('the Player plays alone', () {
    const song = TrackRef(uri: 'content://song', name: 'Blue Bossa.mp3');

    Future<_App> openWithTrack(WidgetTester tester) async {
      final app = await _open(tester);
      await app.scope.player.open(song);
      await app.settle();
      return app;
    }

    testWidgets('entering its tab stops nothing; its dial pauses the metronome '
        'and Harmony, and Resume brings them back', (tester) async {
      final app = await openWithTrack(tester);
      await app.scope.metronome.start();
      await app.scope.drone.start();
      await app.settle();

      await tester.tap(_playerTab);
      await app.settle();
      expect(app.scope.metronome.isPlaying, isTrue);
      expect(app.scope.drone.isPlaying, isTrue);
      expect(find.text('Paused while you listen'), findsNothing);

      await tester.tap(find.byKey(const Key('playerHub')));
      await app.settle();
      expect(app.scope.player.isPlaying, isTrue);
      expect(app.track.playing, isTrue);
      expect(app.scope.metronome.isPlaying, isFalse);
      expect(app.scope.drone.isPlaying, isFalse);
      expect(find.text('Paused while you listen'), findsOneWidget);
      // Its notification names the track and the Player.
      expect(app.audio.state, MediaState.playing);
      expect(app.audio.title, 'Blue Bossa');

      // Resume plays the two again, and the Player gives way.
      await tester.tap(find.text('Resume'));
      await app.settle();
      expect(app.scope.metronome.isPlaying, isTrue);
      expect(app.scope.drone.isPlaying, isTrue);
      expect(app.scope.player.isPlaying, isFalse);
      expect(app.track.playing, isFalse);
    });

    for (final (name, start) in [
      ('the metronome', (_App a) => a.scope.metronome.start()),
      ('the harmony', (_App a) => a.scope.drone.start()),
    ]) {
      testWidgets('starting $name pauses it, with no notice', (tester) async {
        final app = await openWithTrack(tester);
        await app.scope.player.start();
        await app.settle();
        expect(app.track.playing, isTrue);

        await start(app);
        await app.settle();
        expect(app.scope.player.isPlaying, isFalse);
        expect(app.track.playing, isFalse);
        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets('the tuner listening pauses it, and Resume plays it again', (
      tester,
    ) async {
      final app = await openWithTrack(tester);
      await app.scope.player.start();
      await tester.tap(find.byTooltip('Tuner'));
      await app.settle();
      // Entering the tuner stops nothing.
      expect(app.scope.player.isPlaying, isTrue);
      expect(app.mic.isCapturing, isFalse);

      await tester.tap(find.byKey(const Key('tunerHub')));
      await app.settle();
      expect(app.scope.player.isPlaying, isFalse);
      expect(app.mic.isCapturing, isTrue);
      expect(find.text('Paused while you tune'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await app.settle();
      expect(app.scope.player.isPlaying, isTrue);
    });

    testWidgets('a call pauses it with a notice, and Resume plays it', (
      tester,
    ) async {
      final app = await openWithTrack(tester);
      await app.scope.player.start();
      await app.settle();

      app.track.interrupt();
      await app.settle();
      expect(app.scope.player.isPlaying, isFalse);
      expect(find.text('Paused: the sound was interrupted'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await app.settle();
      expect(app.scope.player.isPlaying, isTrue);
    });

    testWidgets('the notification pauses it and plays it again', (
      tester,
    ) async {
      final app = await openWithTrack(tester);
      await app.scope.player.start();
      await app.settle();
      app.audio.input.add(MediaCommand.pause);
      await app.settle();
      expect(app.scope.player.isPlaying, isFalse);
      expect(app.audio.state, MediaState.paused);
      app.audio.input.add(MediaCommand.play);
      await app.settle();
      expect(app.scope.player.isPlaying, isTrue);
      expect(app.audio.state, MediaState.playing);
    });

    testWidgets('its tab has a dot while it plays', (tester) async {
      final app = await openWithTrack(tester);
      expect(
        find.descendant(of: _playerTabItem, matching: find.byType(Badge)),
        findsOneWidget,
      );
      Badge badge() => tester.widget<Badge>(
        find.descendant(of: _playerTabItem, matching: find.byType(Badge)),
      );
      expect(badge().isLabelVisible, isFalse);
      await app.scope.player.start();
      await app.settle();
      expect(badge().isLabelVisible, isTrue);
    });
  });
}
