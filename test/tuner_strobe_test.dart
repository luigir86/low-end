import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/app/theme.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';

Future<FakeMicInput> _open(
  WidgetTester tester, {
  AppSettings? settings,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reducedMotion);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final mic = FakeMicInput();
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: SilentToneOutput(),
      micInput: mic,
      settings: settings ?? AppSettings(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Tuner'));
  await tester.pumpAndSettle();
  return mic;
}

Future<void> _play(WidgetTester tester, FakeMicInput mic, double cents) async {
  final hz = 440 * math.pow(2, cents / 1200);
  for (var chunk = 0; chunk < 8; chunk++) {
    mic.add(
      Float64List.fromList([
        for (var i = chunk * 1600; i < (chunk + 1) * 1600; i++)
          0.3 * math.sin(2 * math.pi * hz * i / 16000),
      ]),
    );
    await tester.pump();
  }
}

// Read the actual painter supplied by the widget, including intermediate
// transition frames, rather than testing a duplicate of the colour rules.
dynamic _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const Key('tunerStrobe'))).painter!;

LowEndColors _colors(WidgetTester tester) =>
    LowEndColors.of(tester.element(find.byKey(const Key('tunerStrobe'))));

void _expectBands(WidgetTester tester, Color color) {
  expect(_painter(tester).segments, color);
  expect(_painter(tester).innerSegments, color);
}

void main() {
  testWidgets('both bands follow pitch with a short colour transition', (
    tester,
  ) async {
    final mic = await _open(tester);
    final colors = _colors(tester);
    _expectBands(tester, colors.strobeIdle);

    await _play(tester, mic, 30);
    // The new verdict starts at the old colour, then fades to red.
    _expectBands(tester, colors.strobeIdle);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painter(tester).segments, isNot(colors.strobeIdle));
    expect(_painter(tester).segments, isNot(colors.off));
    await tester.pump(Durations.short4);
    _expectBands(tester, colors.off);

    for (final cents in [-30.0, -10.0, 10.0, -2.0, 2.0]) {
      await _play(tester, mic, cents);
      await tester.pump(Durations.short4);
      _expectBands(
        tester,
        cents.abs() > 15
            ? colors.off
            : cents.abs() > 5
            ? colors.close
            : colors.inTune,
      );
    }

    // Losing the sound keeps the note visible but greys and stops the rings.
    for (var i = 0; i < 12; i++) {
      mic.add(Float64List(1600));
      await tester.pump();
    }
    await tester.pump(Durations.short4);
    expect(find.text('Holding the last note'), findsOneWidget);
    _expectBands(tester, colors.strobeIdle);
    final phase = _painter(tester).phase.value;
    await tester.pump(const Duration(seconds: 1));
    expect(_painter(tester).phase.value, phase);

    await _play(tester, mic, 10);
    await tester.pump(Durations.short4);
    _expectBands(tester, colors.close);
    await tester.tap(find.byKey(const Key('tunerHub')));
    await tester.pumpAndSettle();
    _expectBands(tester, colors.strobeIdle);
  });

  testWidgets(
    'reduced motion applies colours immediately and follows tolerance',
    (tester) async {
      final settings = AppSettings();
      final mic = await _open(tester, settings: settings, reducedMotion: true);
      final colors = _colors(tester);
      await _play(tester, mic, 7);
      _expectBands(tester, colors.close);
      expect(_painter(tester).stillCents, closeTo(7, 0.5));
      settings.setInTuneCents(10);
      await tester.pump();
      _expectBands(tester, colors.inTune);
      settings.setInTuneCents(2);
      await tester.pump();
      _expectBands(tester, colors.close);
      final phase = _painter(tester).phase.value;
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).phase.value, phase);
    },
  );
}
