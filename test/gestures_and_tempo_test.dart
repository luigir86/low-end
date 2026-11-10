import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/metronome/metronome_screen.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/features/tuner/tuner_reading.dart';
import 'package:low_end/widgets/flip_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('tempo marks', () {
    test('name the tempo in Italian', () {
      expect(tempoMark(TimeSignature.fourFour, 35), 'Grave');
      expect(tempoMark(TimeSignature.fourFour, 50), 'Largo');
      expect(tempoMark(TimeSignature.fourFour, 70), 'Adagio');
      expect(tempoMark(TimeSignature.fourFour, 80), 'Andante');
      expect(tempoMark(TimeSignature.fourFour, 110), 'Moderato');
      expect(tempoMark(TimeSignature.fourFour, 130), 'Allegro');
      expect(tempoMark(TimeSignature.fourFour, 170), 'Vivace');
      expect(tempoMark(TimeSignature.fourFour, 190), 'Presto');
      expect(tempoMark(TimeSignature.fourFour, 250), 'Prestissimo');
    });

    test('count in quarters whatever the beat is', () {
      // 6/8 counts the dotted quarter: 80 of them are 120 quarters.
      final compound = TimeSignature.all.firstWhere((s) => s.label == '6/8');
      expect(tempoMark(compound, 80), 'Allegro');
      // 7/8 counts the eighth: 160 of them are 80 quarters.
      final eighths = TimeSignature.all.firstWhere((s) => s.label == '7/8');
      expect(tempoMark(eighths, 160), 'Andante');
    });

    test('replace BPM in the caption', () {
      expect(tempoUnitCaption(TimeSignature.fourFour, 80), '♩ Andante');
    });
  });

  group('the in-tune zone', () {
    test('is 5 cents wide unless chosen otherwise', () {
      // 8 cents sharp of A4.
      const hz = 440 * 1.00463;
      expect(TunerReading.of(hz).inTune, isFalse);
      expect(TunerReading.of(hz, tolerance: 10).inTune, isTrue);
      expect(TunerReading.of(440 * 1.001, tolerance: 2).inTune, isTrue);
      expect(TunerReading.of(440 * 1.003, tolerance: 2).inTune, isFalse);
    });

    test('is remembered, and a stray saved value falls back to 5', () async {
      SharedPreferences.setMockInitialValues({});
      var settings = await AppSettings.load();
      expect(settings.inTuneCents, 5);
      settings.setInTuneCents(2);
      await Future<void>.delayed(Duration.zero);
      settings = await AppSettings.load();
      expect(settings.inTuneCents, 2);
      SharedPreferences.setMockInitialValues({'in_tune_cents': 7.0});
      expect((await AppSettings.load()).inTuneCents, 5);
    });

    test('the lock on the gestures is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      var settings = await AppSettings.load();
      expect(settings.gesturesLocked, isFalse);
      settings.setGesturesLocked(true);
      await Future<void>.delayed(Duration.zero);
      settings = await AppSettings.load();
      expect(settings.gesturesLocked, isTrue);
    });
  });

  group('the vertical flick', () {
    Future<List<int>> pump(WidgetTester tester, {bool locked = false}) async {
      final flips = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SectionFlip(
            onFlip: locked ? null : flips.add,
            child: const Center(
              child: FlipDetector(
                child: SizedBox(
                  key: Key('pad'),
                  width: 200,
                  height: 200,
                  child: ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ),
      );
      return flips;
    }

    testWidgets('needs a deliberate, quick swipe', (tester) async {
      final flips = await pump(tester);
      final box = find.byKey(const Key('pad'));
      // Too short.
      await tester.timedDrag(
        box,
        const Offset(0, -50),
        const Duration(milliseconds: 100),
      );
      expect(flips, isEmpty);
      // Far enough and quick: up is the next section.
      await tester.timedDrag(
        box,
        const Offset(0, -100),
        const Duration(milliseconds: 150),
      );
      expect(flips, [1]);
      await tester.timedDrag(
        box,
        const Offset(0, 100),
        const Duration(milliseconds: 150),
      );
      expect(flips, [1, -1]);
    });

    testWidgets('ignores a slow drag', (tester) async {
      final flips = await pump(tester);
      await tester.timedDrag(
        find.byKey(const Key('pad')),
        const Offset(0, -120),
        const Duration(seconds: 2),
      );
      expect(flips, isEmpty);
    });

    testWidgets('does nothing when the gestures are locked', (tester) async {
      final flips = await pump(tester, locked: true);
      await tester.timedDrag(
        find.byKey(const Key('pad')),
        const Offset(0, -120),
        const Duration(milliseconds: 150),
      );
      expect(flips, isEmpty);
    });
  });

  group('first sideways launch', () {
    testWidgets('says once how to swipe, when the guide was seen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'seen_guide': true});
      final settings = await AppSettings.load();
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          micInput: FakeMicInput(),
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();
      // The test window is wider than tall.
      expect(find.textContaining('Swipe up or down'), findsOneWidget);
      expect(settings.seenSwipeHint, isTrue);
    });

    testWidgets('not over the guide of the very first launch', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await AppSettings.load();
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          micInput: FakeMicInput(),
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();
      // Nothing over the guide; the hint comes once it is closed.
      expect(find.byKey(const Key('notice')), findsNothing);
      expect(settings.seenSwipeHint, isFalse);
      await tester.ensureVisible(find.text('Got it'));
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Swipe up or down'), findsOneWidget);
      expect(settings.seenSwipeHint, isTrue);
    });
  });

  testWidgets('the drone has no octave to choose, nor a speaker warning', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LowEndApp(toneOutput: SilentToneOutput(), micInput: FakeMicInput()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byTooltip('Harmony'),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    scope.drone.setVoicing(DroneVoicing.chord);
    await tester.tap(find.byKey(const Key('styleButton')));
    await tester.pumpAndSettle();
    expect(find.text('Octave of the root'), findsNothing);
    expect(find.textContaining('faint on the phone'), findsNothing);
    expect(find.text('Chord position'), findsNothing);
    expect(scope.drone.octave, 3);
  });
}
