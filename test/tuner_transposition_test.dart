import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
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
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
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
  await tester.tap(find.text('Tuner'));
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

  test('the cents thumb shrinks the further off the note is', () {
    expect(centsThumbRadius(0, 5), 10);
    expect(centsThumbRadius(-5, 5), 10);
    expect(centsThumbRadius(20, 5), lessThan(10));
    expect(centsThumbRadius(20, 5), greaterThan(centsThumbRadius(40, 5)));
    expect(centsThumbRadius(-50, 5), 5);
    expect(centsThumbRadius(80, 5), 5);
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
