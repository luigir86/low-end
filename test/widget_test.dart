import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/widgets/section_icons.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/background_audio.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/screen_awake.dart';
import 'package:low_end/audio/audio_route.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/widgets/dial.dart';
import 'package:low_end/widgets/style_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Harmony and Metronome tabs: their names are not written anywhere
/// else on the screen.
final _harmonyTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text('Harmony'),
);
final _metronomeTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text('Metronome'),
);

/// The test window is 800 x 600, a landscape one: these tests are about the
/// bottom bar and the horizontal swipe, so they open a phone held upright.
void _portrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

/// A tab's name on the rail, the same word as the tab on screen.
Finder _railTab(String name) => find.descendant(
  of: find.byKey(const Key('tabRail')),
  matching: find.text(name),
);

/// Settings that open the app on the metronome, as these tests start there
/// (the first launch opens on Harmony: see memory_test.dart).
AppSettings _onMetronome() =>
    AppSettings()..rememberSection(AppSection.metronome);

void main() {
  testWidgets('shows the three main sections and switches between them', (
    tester,
  ) async {
    _portrait(tester);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tuner'), findsOneWidget);
    expect(_harmonyTab, findsOneWidget);
    expect(_metronomeTab, findsOneWidget);
    expect(find.text('Library'), findsNothing);

    expect(find.text('Tap to start'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('TAP'), findsOneWidget);
  });

  testWidgets('the ring follows the time signature at once, also stopped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();

    // The ring is the metronome's own painter (the one with a time
    // signature).
    dynamic painter() => tester
        .renderObjectList<RenderCustomPaint>(find.byType(CustomPaint))
        .map((r) => r.painter)
        .where((p) => p != null && p.toString().contains('_RingPainter'))
        .single;

    final before = painter();
    expect(before.signature.label, '4/4');
    await tester.tap(find.text('4/4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6/8').last);
    await tester.pumpAndSettle();
    // Not playing, and yet the ring is drawn again, in six.
    final after = painter();
    expect(after.signature.label, '6/8');
    expect(after.shouldRepaint(before), isTrue);
  });

  testWidgets('swiping moves between the sections', (tester) async {
    _portrait(tester);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    expect(scope.navigation.section, AppSection.metronome);

    // Swipe on the empty top of the page, away from the dial.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(scope.navigation.section, AppSection.drone);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(scope.navigation.section, AppSection.player);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(scope.navigation.section, AppSection.tuner);
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(scope.navigation.section, AppSection.player);
  });

  group('in landscape', () {
    Future<AudioScope> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(2400, 1080);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          micInput: FakeMicInput(),
          settings: _onMetronome(),
        ),
      );
      await tester.pumpAndSettle();
      return AudioScope.of(tester.element(find.byType(HomeShell)));
    }

    testWidgets('the tabs are a column on the left, settings top right', (
      tester,
    ) async {
      await open(tester);
      expect(find.byType(NavigationBar), findsNothing);
      final metronome = tester.getRect(_railTab('Metronome'));
      final harmony = tester.getRect(_railTab('Harmony'));
      final tuner = tester.getRect(_railTab('Tuner'));
      expect(metronome.left, lessThan(80));
      expect(harmony.top, greaterThan(metronome.bottom));
      expect(tuner.top, greaterThan(harmony.bottom));
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final gear = tester.getRect(find.byIcon(Icons.settings_outlined));
      expect(gear.right, greaterThan(size.width - 60));
      expect(gear.top, lessThan(16));
      // The dial is beside the rail, the rows to its right.
      final dial = tester.getRect(find.byKey(DialLayout.dialKey).first);
      expect(dial.left, lessThan(150));
      expect(dial.height, greaterThan(300));
      expect(tester.getRect(find.text('TAP')).left, greaterThan(dial.right));
    });

    testWidgets('a vertical swipe on the dial or the rail changes section', (
      tester,
    ) async {
      final scope = await open(tester);
      final dial = tester.getCenter(find.byKey(DialLayout.dialKey).first);
      await tester.dragFrom(dial, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(scope.navigation.section, AppSection.drone);
      await tester.dragFrom(
        tester.getCenter(_railTab('Harmony')),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(scope.navigation.section, AppSection.player);
      // Down goes back; past the first or last, nothing happens.
      await tester.dragFrom(
        tester.getCenter(_railTab('Harmony')),
        const Offset(0, 150),
      );
      await tester.pumpAndSettle();
      expect(scope.navigation.section, AppSection.drone);
    });

    testWidgets('not on the rows, nor from the edge of the screen', (
      tester,
    ) async {
      final scope = await open(tester);
      // The status bar and the home gesture: the system's strips.
      tester.view.viewPadding = const FakeViewPadding(top: 80, bottom: 80);
      tester.view.systemGestureInsets = const FakeViewPadding(
        top: 80,
        bottom: 80,
      );
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetSystemGestureInsets);
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getCenter(find.text('TAP')),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(scope.navigation.section, AppSection.metronome);
      final dial = tester.getCenter(find.byKey(DialLayout.dialKey).first);
      await tester.dragFrom(Offset(dial.dx, 8), const Offset(0, 150));
      await tester.pumpAndSettle();
      await tester.dragFrom(Offset(dial.dx, 8), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(scope.navigation.section, AppSection.metronome);
    });

    testWidgets('a tap on the rail goes to the section', (tester) async {
      final scope = await open(tester);
      await tester.tap(_railTab('Tuner'));
      await tester.pumpAndSettle();
      expect(scope.navigation.section, AppSection.tuner);
    });
  });

  testWidgets('drone and metronome play together, pause on the tuner with a '
      'notice, and start again only when asked', (tester) async {
    _portrait(tester);
    final tone = SilentToneOutput();
    final click = SilentClickOutput();
    final mic = FakeMicInput();
    final awake = FakeScreenAwake();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: tone,
        clickOutput: click,
        micInput: mic,
        screenAwake: awake,
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    expect(awake.on, isFalse);

    await tester.tap(_harmonyTab);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tone.frequencies.single, closeTo(220, 0.01));

    await tester.tap(_metronomeTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tap to start'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(click.bar, isNotNull);
    // The screen stays on while they play.
    expect(awake.on, isTrue);

    // Coming to the tuner changes nothing: a swipe too far must not stop
    // the band. The tuner waits, and says what a touch will do.
    await tester.tap(find.text('Tuner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tone.frequencies.single, closeTo(220, 0.01));
    expect(click.bar, isNotNull);
    expect(mic.isCapturing, isFalse);
    expect(find.text('Listening pauses what is playing'), findsOneWidget);
    expect(find.text('Paused while you tune'), findsNothing);

    // A touch on the middle pauses both, so the microphone hears only the
    // bass, and says so.
    await tester.tap(find.byKey(const Key('tunerHub')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tone.frequencies, isEmpty);
    expect(click.bar, isNull);
    expect(mic.isCapturing, isTrue);
    expect(find.text('Paused while you tune'), findsOneWidget);
    // Listening keeps the screen on too.
    expect(awake.on, isTrue);

    // Leaving it, nothing starts by itself: a swipe too far must not bring
    // the click back unasked.
    await tester.tap(_harmonyTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tone.frequencies, isEmpty);
    expect(click.bar, isNull);
    expect(mic.isCapturing, isFalse);
    expect(awake.on, isFalse);

    // Resume, on the notice, plays both again.
    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tone.frequencies.single, closeTo(220, 0.01));
    expect(click.bar, isNotNull);
  });

  testWidgets('a page opened over the tuner does not pause the sound again', (
    tester,
  ) async {
    final click = SilentClickOutput();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: click,
        micInput: FakeMicInput(),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    scope.navigation.open(AppSection.tuner);
    await tester.pump(const Duration(milliseconds: 300));
    // Played again from the tuner, on purpose (with headphones, say).
    await scope.metronome.start();
    scope.navigation.setCovered(true);
    await tester.pump(const Duration(milliseconds: 300));
    scope.navigation.setCovered(false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(scope.metronome.isPlaying, isTrue);
    expect(click.bar, isNotNull);
    await scope.metronome.stop();
  });

  testWidgets('unplugging the headphones stops the sound, with Resume', (
    tester,
  ) async {
    final click = SilentClickOutput();
    final tone = SilentToneOutput();
    final route = FakeAudioRoute();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: tone,
        clickOutput: click,
        micInput: FakeMicInput(),
        audioRoute: route,
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    await scope.metronome.start();
    await tester.pump(const Duration(milliseconds: 300));
    expect(click.bar, isNotNull);

    // In a rehearsal room, the click must not jump to the speaker.
    route.unplug();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scope.metronome.isPlaying, isFalse);
    expect(click.bar, isNull);
    expect(find.text('Paused: headphones unplugged'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scope.metronome.isPlaying, isTrue);
    await scope.metronome.stop();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('unplugged, the notification stays paused to play again', (
    tester,
  ) async {
    final route = FakeAudioRoute();
    final audio = _RecordingAudio();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        audioRoute: route,
        backgroundAudio: audio,
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    await scope.metronome.start();
    await tester.pump(const Duration(milliseconds: 300));
    expect(audio.state, MediaState.playing);

    // As a music player does: paused, with its play button, not gone.
    route.unplug();
    await tester.pump();
    expect(scope.metronome.isPlaying, isFalse);
    expect(audio.state, MediaState.paused);

    audio.input.add(MediaCommand.play);
    await tester.pump();
    expect(scope.metronome.isPlaying, isTrue);
    expect(audio.state, MediaState.playing);
    await scope.metronome.stop();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('unplugging with nothing playing says nothing', (tester) async {
    final route = FakeAudioRoute();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        audioRoute: route,
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    route.unplug();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paused: headphones unplugged'), findsNothing);
  });

  testWidgets('sound cut by the browser shows as paused, with Resume', (
    tester,
  ) async {
    final click = SilentClickOutput();
    final route = FakeAudioRoute();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: click,
        micInput: FakeMicInput(),
        audioRoute: route,
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));

    // Nothing plays: nothing to say.
    route.interrupt();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paused: the sound was interrupted'), findsNothing);

    await scope.metronome.start();
    await tester.pump(const Duration(milliseconds: 300));
    expect(click.bar, isNotNull);

    // A call on the iPhone: the app must not look as if it played on.
    route.interrupt();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scope.metronome.isPlaying, isFalse);
    expect(click.bar, isNull);
    expect(find.text('Paused: the sound was interrupted'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scope.metronome.isPlaying, isTrue);
    await scope.metronome.stop();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('with the microphone refused, a button opens the settings', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('low_end/app_settings'),
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('low_end/app_settings'),
        null,
      ),
    );
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(allowed: false),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    expect(calls, ['open']);
  });

  testWidgets(
    'the metronome starts and stops from the ring, with − + and TAP',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final click = SilentClickOutput();
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          clickOutput: click,
          micInput: FakeMicInput(),
          settings: _onMetronome(),
        ),
      );
      await tester.pumpAndSettle();

      final faster = find.widgetWithIcon(OutlinedButton, Icons.add);
      final slower = find.widgetWithIcon(OutlinedButton, Icons.remove);
      await tester.tap(faster);
      await tester.tap(faster);
      await tester.tap(slower);
      await tester.pump();
      expect(find.text('81'), findsOneWidget);

      await tester.tap(find.text('Tap to start'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(click.bar, isNotNull);
      expect(find.text('Tap to start'), findsNothing);

      // The tempo maths of TAP are checked in metronome_controller_test.dart
      // (a widget test's fake clock does not move a real Stopwatch).
      await tester.tap(find.text('TAP'));
      await tester.pump();

      // Touching the ring again stops it.
      await tester.tap(find.bySemanticsLabel('Stop the metronome'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(click.bar, isNull);
    },
  );

  testWidgets('touching the middle of the drone dial stops and restarts it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final tone = SilentToneOutput();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: tone,
        micInput: FakeMicInput(),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_harmonyTab);
    await tester.pumpAndSettle();
    await tester.tap(find.text('D'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tone.frequencies, isNotEmpty);

    await tester.tap(find.bySemanticsLabel(RegExp('^Stop the harmony')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tone.frequencies, isEmpty);

    // Again: the last note plays again.
    await tester.tap(find.bySemanticsLabel(RegExp('^Play D')).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tone.frequencies.single, closeTo(146.83, 0.01));
  });

  testWidgets('settings change the language, note names and reference A', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final output = SilentToneOutput();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: output,
        micInput: FakeMicInput(),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('languageMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italiano'));
    await tester.pumpAndSettle();
    expect(find.text('Impostazioni'), findsOneWidget);
    expect(find.text('La di riferimento'), findsOneWidget);

    await tester.tap(find.byKey(const Key('noteNamesMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C D E'));
    await tester.pumpAndSettle();
    // The reference A is further down the page now.
    await tester.scrollUntilVisible(find.text('440 Hz'), 100);
    await tester.tap(find.text('440 Hz'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('442 Hz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('442 Hz').last);
    await tester.pumpAndSettle();

    // The app is in Italian now, so the back button says "Indietro".
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Armonia'),
      ),
    );
    await tester.pumpAndSettle();
    // Italian app, but letter names as chosen; the drone follows 442 Hz.
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(output.frequencies.single, closeTo(221, 0.01));
    expect(find.text('Solo la nota'), findsWidgets);
  });

  testWidgets('the About dialog shows the licence and the package notices', (
    tester,
  ) async {
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('About Low End'), 100);
    await tester.ensureVisible(find.text('About Low End'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Low End'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Free and open-source software, released under the MIT License.',
      ),
      findsOneWidget,
    );
    expect(find.text('View licenses'), findsOneWidget);
  });

  testWidgets('the notification says what plays and follows the tempo', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        backgroundAudio: audio,
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));

    await scope.metronome.start();
    await tester.pump();
    expect(audio.state, MediaState.playing);
    // What plays and at what tempo is the title; the app's name sits under.
    expect(audio.title, 'Metronome 80 BPM · 4/4');
    expect(audio.text, 'Low End');
    scope.metronome.setBpm(100);
    await tester.pump();
    expect(audio.title, 'Metronome 100 BPM · 4/4');
    await scope.drone.start();
    await tester.pump();
    expect(audio.title, 'Metronome 100 BPM · 4/4');
    expect(audio.text, 'Harmony A');

    await scope.metronome.stop();
    await tester.pump();
    expect(audio.title, 'Harmony A');
    expect(audio.text, 'Low End');
    await scope.drone.stop();
    await tester.pump();
    expect(audio.state, MediaState.off);
  });

  testWidgets('play on the notification starts again what pause stopped', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        backgroundAudio: audio,
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));

    await scope.metronome.start();
    await scope.drone.start();
    await tester.pump();
    expect(audio.state, MediaState.playing);

    // The drone is stopped first, with the metronome still sounding: that
    // must not count as a restart and forget the pause.
    audio.input.add(MediaCommand.pause);
    await tester.pump();
    expect(scope.metronome.isPlaying, isFalse);
    expect(scope.drone.isPlaying, isFalse);
    expect(audio.state, MediaState.paused);

    audio.input.add(MediaCommand.play);
    await tester.pump();
    expect(scope.metronome.isPlaying, isTrue);
    expect(scope.drone.isPlaying, isTrue);
    expect(audio.state, MediaState.playing);

    // Only the metronome: the same.
    await scope.drone.stop();
    audio.input.add(MediaCommand.pause);
    await tester.pump();
    expect(audio.state, MediaState.paused);
    audio.input.add(MediaCommand.play);
    await tester.pump();
    expect(scope.metronome.isPlaying, isTrue);
    expect(scope.drone.isPlaying, isFalse);
    expect(audio.state, MediaState.playing);
  });

  testWidgets('the theme can be forced, and the screen kept on or not', (
    tester,
  ) async {
    final settings = _onMetronome();
    final awake = FakeScreenAwake();
    final click = SilentClickOutput();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: click,
        micInput: FakeMicInput(),
        settings: settings,
        screenAwake: awake,
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    brightness() => Theme.of(tester.element(find.byType(HomeShell))).brightness;

    // The test window is light, but the app is always dark.
    expect(brightness(), Brightness.dark);

    // The screen stays on while it plays, unless the player says no.
    await scope.metronome.start();
    await tester.pump();
    expect(awake.on, isTrue);
    settings.setKeepScreenOn(false);
    await tester.pump();
    expect(awake.on, isFalse);
    settings.setKeepScreenOn(true);
    await tester.pump();
    expect(awake.on, isTrue);
    await scope.metronome.stop();
    await tester.pump();
    expect(awake.on, isFalse);
  });

  testWidgets('the settings page has no theme, and changes the screen option', (
    tester,
  ) async {
    final settings = _onMetronome();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsNothing);
    await tester.tap(find.text('Keep the screen on'));
    await tester.pumpAndSettle();
    expect(settings.keepScreenOn, isFalse);
  });

  testWidgets('the guide opens by itself once, and from the settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.seenGuide, isFalse);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gestures and shortcuts'), findsOneWidget);
    expect(settings.seenGuide, isTrue);
    // One page, five tips, closed by Got it.
    expect(find.byType(ListTile), findsNWidgets(5));
    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Gestures and shortcuts'), findsNothing);

    // Remembered: the next launch does not show it again.
    expect((await AppSettings.load()).seenGuide, isTrue);

    // And it can be read again from the settings.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Gestures and shortcuts'), 100);
    await tester.ensureVisible(find.text('Gestures and shortcuts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gestures and shortcuts'));
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets(
    'the tabs and the time signature are named, the tuner is a tuning fork',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          micInput: FakeMicInput(),
          settings: _onMetronome(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Metronome'), findsOneWidget);
      expect(find.text('Harmony'), findsOneWidget);
      // The time signature field is named on its border and for screen readers.
      final semantics = tester.ensureSemantics();
      expect(find.text('Time signature'), findsOneWidget);
      expect(find.bySemanticsLabel('Time signature'), findsOneWidget);
      semantics.dispose();
      // The tuner tab is a tuning fork.
      expect(
        find.byWidgetPredicate(
          (w) => w is SectionIcon && w.glyph == SectionGlyph.tuningFork,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the style menu sets the style, the held tone and opens the legend',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final piano = SilentPianoOutput();
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          pianoOutput: piano,
          micInput: FakeMicInput(),
          settings: _onMetronome(),
        ),
      );
      await tester.pumpAndSettle();
      final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
      await tester.tap(_harmonyTab);
      await tester.pumpAndSettle();
      scope.drone.setVoicing(DroneVoicing.chord);
      await tester.pumpAndSettle();

      // The button shows the style playing, and says it.
      expect(find.byTooltip('Style: Chord on every beat'), findsOneWidget);
      await tester.tap(find.byKey(const Key('styleButton')));
      await tester.pumpAndSettle();
      // The piano's four styles under the metronome's tempo, then the tone.
      expect(
        find.textContaining('Follows the metronome: ♩ = '),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is StyleIcon && w.glyph == StyleGlyph.footprints,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Arpeggio'));
      await tester.pumpAndSettle();
      expect(scope.drone.style, DroneStyle.arpeggio);
      expect(find.byTooltip('Style: Arpeggio'), findsOneWidget);

      await tester.tap(find.byKey(const Key('styleButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Walking bass'));
      await tester.pumpAndSettle();
      expect(scope.drone.style, DroneStyle.walking);
      // The footprints are now on the button.
      expect(
        find.descendant(
          of: find.byKey(const Key('styleButton')),
          matching: find.byWidgetPredicate(
            (w) => w is StyleIcon && w.glyph == StyleGlyph.footprints,
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('styleButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Held tone'));
      await tester.pumpAndSettle();
      expect(scope.drone.continuous, isTrue);
      expect(find.byTooltip('Style: Held tone'), findsOneWidget);

      // A piano style again: the piano is back.
      await tester.tap(find.byKey(const Key('styleButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chord every bar'));
      await tester.pumpAndSettle();
      expect(scope.drone.continuous, isFalse);
      expect(scope.drone.style, DroneStyle.held);

      // The legend is the last line.
      await tester.tap(find.byKey(const Key('styleButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Legend and degrees'));
      await tester.pumpAndSettle();
      expect(find.text('Legend'), findsOneWidget);
      expect(scope.drone.style, DroneStyle.held);
    },
  );

  testWidgets('touching the tempo opens the keyboard to type it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: _onMetronome(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Type the tempo'), findsOneWidget);
    // The keyboard waits for the number to be touched, which selects it all.
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.selection.start, 0);
    expect(field.controller!.selection.end, field.controller!.text.length);
    await tester.enterText(find.byType(TextField), '132');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(scope.metronome.bpm, 132);
    expect(find.text('Type the tempo'), findsNothing);

    // Too fast is brought back to the limit, and a preset sets it at once.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '999');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(scope.metronome.bpm, MetronomeController.maxBpm);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 BPM'));
    await tester.pumpAndSettle();
    expect(scope.metronome.bpm, 60);

    // Closing the sheet leaves it as it was.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '90');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(scope.metronome.bpm, 60);
  });
}

/// A [BackgroundAudio] that remembers what the notification shows.
class _RecordingAudio implements BackgroundAudio {
  var state = MediaState.off;
  var title = '';
  var text = '';
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
    this.text = text;
  }
}
