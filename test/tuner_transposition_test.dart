import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/actions/app_actions.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/pitch.dart';
import 'package:low_end/audio/pitch_detector.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/player/player_controller.dart';
import 'package:low_end/features/tuner/tuner_controller.dart';
import 'package:low_end/features/tuner/tuner_panel.dart';
import 'package:low_end/features/tuner/tuner_tuning.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chunk number [chunk] of a continuous sine, as the microphone would send it.
Float64List _sine(double hz, {int chunk = 0}) => Float64List.fromList([
  for (var i = chunk * 1600; i < (chunk + 1) * 1600; i++)
    0.3 * math.sin(2 * math.pi * hz * i / 16000),
]);

Future<FakeMicInput> _openTuner(
  WidgetTester tester,
  AppSettings settings,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final mic = FakeMicInput();
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: SilentToneOutput(),
      micInput: mic,
      settings: settings,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Tuner'));
  await tester.pumpAndSettle();
  return mic;
}

Future<void> _play(WidgetTester tester, FakeMicInput mic, double hz) async {
  for (var i = 0; i < 5; i++) {
    mic.add(_sine(hz, chunk: i));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  test('a transposing instrument reads its written note', () {
    // The concert B♭ is a C for a B♭ clarinet, the concert E♭ for an alto
    // sax, the concert F for a horn.
    expect(Transposition.bFlat.written(const Note(10, 4)), const Note(0, 5));
    expect(Transposition.eFlat.written(const Note(3, 4)), const Note(0, 5));
    expect(Transposition.f.written(const Note(5, 4)), const Note(0, 5));
    expect(Transposition.c.written(const Note(9, 4)), const Note(9, 4));
  });

  test('the transposition is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await AppSettings.load();
    expect(first.transposition, Transposition.c);
    first.setTransposition(Transposition.eFlat);
    await Future<void>.delayed(Duration.zero);
    expect((await AppSettings.load()).transposition, Transposition.eFlat);
    SharedPreferences.setMockInitialValues({'tuner_transposition': 'g'});
    expect((await AppSettings.load()).transposition, Transposition.c);
  });

  test(
    'an assistant sets the transposition and reads the written note',
    () async {
      final settings = AppSettings();
      final actions = AppActions(
        drone: DroneController(SilentToneOutput()),
        metronome: MetronomeController(SilentClickOutput()),
        tuner: TunerController(FakeMicInput()),
        player: PlayerController(SilentTrackOutput(), FakeTrackFiles()),
        navigation: AppNavigation(),
        settings: settings,
      );
      final result = await actions.call('settings_set', {
        'transposition': 'bFlat',
      });
      expect(result['ok'], isTrue);
      expect(settings.transposition, Transposition.bFlat);
      expect(
        ((result['state']! as Map)['settings'] as Map)['transposition'],
        'bFlat',
      );
      expect(
        (await actions.call('settings_set', {'transposition': 'g'}))['ok'],
        isFalse,
      );
    },
  );

  test('the bass listens up to 700 Hz, everything else up to 2800', () {
    expect(TunerTuning.bass.highestHz, PitchDetector.bassMaxFrequency);
    for (final t in TunerTuning.values.where((t) => t != TunerTuning.bass)) {
      expect(t.highestHz, PitchDetector.maxHighFrequency, reason: '$t');
    }
  });

  test('the cents scale runs from 50 flat to 50 sharp, clamped', () {
    expect(centsOnScale(-50), 0);
    expect(centsOnScale(0), 0.5);
    expect(centsOnScale(25), 0.75);
    expect(centsOnScale(-80), 0);
    expect(centsOnScale(80), 1);
  });

  test('close and far off differ by their arrows, not only by colour', () {
    expect(verdictIcon(2, 5), Icons.check_circle);
    expect(verdictIcon(-5, 5), Icons.check_circle);
    expect(verdictIcon(-9, 5), Icons.arrow_downward);
    expect(verdictIcon(12, 5), Icons.arrow_upward);
    expect(verdictIcon(-32, 5), Icons.keyboard_double_arrow_down);
    expect(verdictIcon(32, 5), Icons.keyboard_double_arrow_up);
    // A wide in-tune zone moves the limit of "close" with it.
    expect(verdictIcon(-8, 10), Icons.check_circle);
    expect(verdictIcon(15, 10), Icons.arrow_upward);
  });

  testWidgets('a B♭ instrument sees its written note', (tester) async {
    final settings = AppSettings()..setTransposition(Transposition.bFlat);
    final mic = await _openTuner(tester, settings);
    expect(find.text('Chromatic · B♭'), findsOneWidget);
    // A concert A4 is a written B4.
    await _play(tester, mic, 440);
    expect(find.text('B4'), findsWidgets);
    expect(find.text('in B♭'), findsOneWidget);
    expect(find.text('In tune'), findsOneWidget);
  });

  testWidgets('a violin high note is heard, but not with the bass chosen', (
    tester,
  ) async {
    final settings = AppSettings();
    final mic = await _openTuner(tester, settings);
    // A6, high on the E string.
    await _play(tester, mic, 1760);
    expect(find.text('A6'), findsWidgets);
    expect(find.text('In tune'), findsOneWidget);

    settings.setTunerInstrument(TunerTuning.bass);
    await tester.pump(const Duration(seconds: 3));
    for (var i = 5; i < 60; i++) {
      mic.add(_sine(1760, chunk: i));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('A6'), findsNothing);
  });
}
