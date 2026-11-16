// The real app on a real Android (an emulator in CI, or a phone): its real
// sound engine, microphone, recorder, Player and Android code, which the
// tests in test/ replace with silent twins. It checks that each section
// starts its sound with no error, as after an update of Flutter or of a
// package, and leaves what the ear judges (timing, Bluetooth, calls) to the
// checks on the phone.
//
//   flutter test integration_test/app_test.dart -d <device>
//
// The microphone must be allowed: in CI the job `device` allows it while
// the app installs (.github/workflows/ci.yml); on a phone, allow it once in
// the app.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/features/player/player_controller.dart';
import 'package:low_end/features/player/player_panel.dart';
import 'package:low_end/features/player/recording_controller.dart';
import 'package:low_end/features/tuner/tuner_controller.dart';
import 'package:low_end/main.dart' as app;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/material_ui_finders.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('each section starts its sound on a real Android', (
    tester,
  ) async {
    // English, the guide already seen, from the metronome.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('language', 'en');
    await prefs.setBool('seen_guide', true);
    await prefs.setBool('seen_swipe_hint', true);

    await app.main();
    await _until(
      tester,
      'the app on screen',
      () => _tab('Player').evaluate().isNotEmpty,
    );
    final scope = AudioScope.of(tester.element(find.byType(NavigationBar)));

    // Metronome.
    await _open(tester, 'Metronome');
    await tester.tap(find.text('Tap to start'));
    await _until(
      tester,
      'the metronome playing',
      () => scope.metronome.isPlaying,
    );
    await _wait(tester, const Duration(seconds: 2));
    expect(scope.metronome.audioFailed, isFalse, reason: 'the click failed');
    await tester.tap(find.bySemanticsLabel(RegExp('^Stop the metronome')));
    await _until(
      tester,
      'the metronome stopped',
      () => !scope.metronome.isPlaying,
    );

    // Harmony: the piano's recordings load, then it sounds.
    await _open(tester, 'Harmony');
    await tester.tap(find.bySemanticsLabel(RegExp('^Play(?!er)')).last);
    await _until(
      tester,
      'the harmony sounding',
      () => scope.drone.isPlaying && !scope.drone.isStarting,
      timeout: const Duration(seconds: 30),
    );
    await _wait(tester, const Duration(seconds: 2));
    expect(scope.drone.audioFailed, isFalse, reason: 'the piano failed');
    await tester.tap(find.bySemanticsLabel(RegExp('^Stop the harmony')));
    await _until(tester, 'the harmony stopped', () => !scope.drone.isPlaying);

    // Tuner: the microphone opens (the emulator's hears nothing).
    await _open(tester, 'Tuner');
    if (!scope.tuner.isListening) {
      await tester.tap(find.byKey(const Key('tunerHub')));
    }
    await _until(
      tester,
      'the tuner listening',
      () =>
          scope.tuner.status == TunerStatus.listening ||
          scope.tuner.status == TunerStatus.permissionDenied ||
          scope.tuner.status == TunerStatus.failed,
    );
    expect(scope.tuner.status, TunerStatus.listening);

    // Player: a take recorded with REC opens and plays.
    await _open(tester, 'Player');
    await tester.tap(find.byKey(PlayerPanel.recordKey));
    await _until(
      tester,
      'the take recording',
      () => scope.recording.status == RecordingStatus.recording,
    );
    await _wait(tester, const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('takeStop')));
    await _until(
      tester,
      'the take in the Player',
      () => scope.player.status == PlayerStatus.ready,
      timeout: const Duration(seconds: 30),
    );
    expect(scope.player.duration, greaterThan(const Duration(seconds: 1)));
    await tester.tap(find.tooltip('Play'));
    await _until(tester, 'the take playing', () => scope.player.isPlaying);
    await _wait(tester, const Duration(seconds: 1));
    expect(scope.player.isPlaying, isTrue);
  });
}

Finder _tab(String name) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.tooltip(name),
);

Future<void> _open(WidgetTester tester, String section) async {
  await tester.tap(_tab(section));
  await _wait(tester, const Duration(seconds: 1));
}

/// Real time goes by on screen: the sound engine works in it.
Future<void> _wait(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> _until(
  WidgetTester tester,
  String what,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      fail('Waited ${timeout.inSeconds} s for $what');
    }
    await _wait(tester, const Duration(milliseconds: 200));
  }
}
