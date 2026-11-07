import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/metronome/tempo_dial.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/widgets/dial.dart';

final _dial = find.byKey(const Key('metronomeTempoDial'));

Future<AudioScope> _open(
  WidgetTester tester, {
  bool landscape = false,
  bool locked = false,
  Size? size,
  double scale = 1,
}) async {
  tester.view.physicalSize =
      size ?? (landscape ? const Size(915, 412) : const Size(412, 915));
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final settings = AppSettings()..rememberSection(AppSection.metronome);
  settings.setGesturesLocked(locked);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('metronomeCapture'),
      child: LowEndApp(
        settings: settings,
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AudioScope.of(tester.element(find.byType(HomeShell)));
}

Offset _point(WidgetTester tester, double angle, {double? radius}) {
  final rect = tester.getRect(_dial);
  final g = TempoDialGeometry(rect.size);
  return rect.center +
      Offset(math.sin(angle), -math.cos(angle)) *
          (radius ?? (g.inner + g.outer) / 2);
}

Future<void> _turn(
  WidgetTester tester,
  double sweep, {
  double start = 0,
  double? radius,
}) async {
  final gesture = await tester.startGesture(
    _point(tester, start, radius: radius),
  );
  final count = (sweep.abs() / (math.pi / 24)).ceil();
  for (var i = 1; i <= count; i++) {
    await gesture.moveTo(
      _point(tester, start + sweep * i / count, radius: radius),
    );
    await tester.pump(Duration(milliseconds: i < count ? 5 : 0));
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  group('RF-MET-09 revision 2 geometry', () {
    for (final diameter in [160.0, 200.0, 320.0, 420.0]) {
      test('thin outer paint and separate generous hit area at $diameter', () {
        final g = TempoDialGeometry(Size.square(diameter));
        final oldInner = math.max(
          g.dial.ringInner - 4 - 40,
          g.dial.radius * 0.31,
        );
        expect(g.outer, g.dial.ringOuter);
        expect(g.outer - g.inner, lessThanOrEqualTo(20));
        expect(g.hitOuter - g.hitInner, greaterThan(g.outer - g.inner));
        expect(g.hitOuter, lessThanOrEqualTo(g.dial.radius));
        expect(g.hitInner, greaterThan(g.beatOuter));
        expect(g.hubRadius, lessThan(g.beatInner));
        expect(g.hubRadius, greaterThanOrEqualTo(oldInner));
      });
    }
  });

  testWidgets('dark margin of the outer wheel also adjusts tempo', (
    tester,
  ) async {
    final scope = await _open(tester);
    final g = TempoDialGeometry(tester.getSize(_dial));
    final radius = (g.hitInner + g.inner) / 2;
    expect(g.band.contains(g.dial.center + Offset(radius, 0)), isFalse);
    await _turn(tester, math.pi / 2, radius: radius);
    expect(scope.metronome.bpm, 110);
    expect(scope.metronome.isPlaying, isFalse);
    expect(scope.navigation.section, AppSection.metronome);
  });

  for (final label in ['1/1', '4/4', '6/8']) {
    testWidgets('beat ring remains a start-stop control in $label', (
      tester,
    ) async {
      final scope = await _open(tester);
      scope.metronome.setSignature(
        TimeSignature.all.firstWhere((s) => s.label == label),
      );
      await tester.pump();
      final g = TempoDialGeometry(tester.getSize(_dial));
      await tester.tapAt(
        _point(tester, math.pi / 4, radius: (g.beatInner + g.beatOuter) / 2),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(scope.metronome.isPlaying, isTrue);
      expect(scope.metronome.bpm, 80);
      await tester.tapAt(tester.getCenter(_dial));
      await tester.pump();
      expect(scope.metronome.isPlaying, isFalse);
      expect(scope.metronome.bpm, 80);
    });
  }

  testWidgets(
    'wheel remains painted after signature changes and repeated captures',
    (tester) async {
      final scope = await _open(tester);
      Future<void> checkPaint() async {
        final point = _point(tester, math.pi / 2 + math.pi / 96);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('metronomeCapture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixel = (point.dy.floor() * image.width + point.dx.floor()) * 4;
          expect(
            data.getUint8(pixel),
            greaterThan(130),
            reason: 'the light outer band must remain visible',
          );
          image.dispose();
        });
      }

      for (final label in ['4/4', '1/1', '6/8', '4/4']) {
        scope.metronome.setSignature(
          TimeSignature.all.firstWhere((s) => s.label == label),
        );
        await tester.pumpAndSettle();
        await checkPaint();
        await tester.pump(const Duration(milliseconds: 100));
        await checkPaint();
        await scope.metronome.start();
        await tester.pump(const Duration(milliseconds: 100));
        await checkPaint();
        await scope.metronome.stop();
        await tester.pumpAndSettle();
      }
    },
  );

  // RF-MET-09: exercise real pointer routing inside the complete app.
  testWidgets('contact, tap and small tremor do not change or start anything', (
    tester,
  ) async {
    final scope = await _open(tester);
    final start = _point(tester, 0);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    expect(scope.metronome.bpm, 80);
    await gesture.moveTo(start + const Offset(1, 0));
    await gesture.up();
    await tester.tapAt(start);
    await tester.pump();
    expect(scope.metronome.bpm, 80);
    expect(scope.metronome.isPlaying, isFalse);
  });

  for (final landscape in [false, true]) {
    testWidgets('quarter turns are relative and stay on the tab ($landscape)', (
      tester,
    ) async {
      final scope = await _open(tester, landscape: landscape);
      await _turn(tester, math.pi / 2);
      expect(scope.metronome.bpm, 110);
      expect(scope.navigation.section, AppSection.metronome);
      await _turn(tester, -math.pi / 2, start: math.pi);
      expect(scope.metronome.bpm, 80);
      expect(scope.metronome.isPlaying, isFalse);
      expect(scope.navigation.section, AppSection.metronome);
    });
  }

  testWidgets('crossing twelve and multiple turns have no discontinuity', (
    tester,
  ) async {
    final scope = await _open(tester);
    scope.metronome.setBpm(60);
    await tester.pump();
    await _turn(tester, 2 * math.pi, start: -math.pi / 4);
    expect(scope.metronome.bpm, 180);
    await _turn(tester, -2 * math.pi, start: math.pi / 4);
    expect(scope.metronome.bpm, 60);
  });

  testWidgets('clamps both bounds and reverses without recovering excess', (
    tester,
  ) async {
    final scope = await _open(tester);
    final m = scope.metronome;
    m.setBpm(245);
    await tester.pump();
    final gesture = await tester.startGesture(_point(tester, 0));
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(_point(tester, i * math.pi / 24));
    }
    expect(m.bpm, 250);
    await gesture.moveTo(_point(tester, math.pi / 2 - math.pi / 12));
    expect(m.bpm, 245);
    await gesture.up();
    m.setBpm(35);
    await tester.pump();
    await _turn(tester, -math.pi / 2);
    expect(m.bpm, MetronomeController.minBpm);
    m.setSignature(TimeSignature.all.firstWhere((s) => s.label == '7/8'));
    m.setBpm(390);
    await tester.pump();
    await _turn(tester, math.pi / 2);
    expect(m.bpm, 400);
  });

  testWidgets('leaving the band and cancellation never trigger the hub', (
    tester,
  ) async {
    final scope = await _open(tester);
    final gesture = await tester.startGesture(_point(tester, 0));
    await gesture.moveTo(_point(tester, math.pi / 6));
    expect(scope.metronome.bpm, 90);
    await gesture.moveTo(tester.getCenter(_dial));
    await gesture.moveTo(_point(tester, math.pi));
    expect(scope.metronome.bpm, 90);
    await gesture.cancel();
    await tester.pump();
    expect(scope.metronome.isPlaying, isFalse);
    await _turn(tester, math.pi / 2);
    expect(scope.metronome.bpm, 120);
  });

  testWidgets('a second pointer does not alter the active rotation', (
    tester,
  ) async {
    final scope = await _open(tester);
    final first = await tester.startGesture(_point(tester, 0), pointer: 1);
    final second = await tester.startGesture(
      _point(tester, math.pi),
      pointer: 2,
    );
    await second.moveTo(_point(tester, -math.pi / 2));
    expect(scope.metronome.bpm, 80);
    await first.moveTo(_point(tester, math.pi / 6));
    expect(scope.metronome.bpm, 90);
    await second.up();
    await first.up();
    await tester.pump();
    expect(scope.metronome.isPlaying, isFalse);
  });

  testWidgets('a fast crossing of the centre does not jump sixty BPM', (
    tester,
  ) async {
    final scope = await _open(tester);
    final gesture = await tester.startGesture(_point(tester, 0));
    await gesture.moveTo(_point(tester, math.pi));
    expect(scope.metronome.bpm, 80);
    await gesture.moveTo(_point(tester, math.pi + math.pi / 6));
    expect(scope.metronome.bpm, 90);
    await gesture.up();
    await tester.pump();
    expect(scope.metronome.isPlaying, isFalse);
  });

  testWidgets('playing keeps running and applies the existing 300 ms rest', (
    tester,
  ) async {
    final scope = await _open(tester);
    final m = scope.metronome;
    await m.start();
    await tester.pump();
    await _turn(tester, math.pi / 2);
    expect(m.bpm, 110);
    expect(m.soundingBpm, 80);
    expect(m.isPlaying, isTrue);
    await tester.pump(const Duration(milliseconds: 299));
    expect(m.soundingBpm, 80);
    await tester.pump(const Duration(milliseconds: 1));
    expect(m.soundingBpm, 110);
    expect(m.isPlaying, isTrue);
    await tester.tapAt(tester.getCenter(_dial));
    await tester.pump();
    expect(m.isPlaying, isFalse);
  });

  testWidgets('slider semantics are separate from the central button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final scope = await _open(tester);
    final finder = find.bySemanticsLabel('Tempo dial');
    final node = tester.getSemantics(finder);
    expect(node.getSemanticsData().flagsCollection.isSlider, isTrue);
    expect(node.getSemanticsData().value, '80 BPM');
    expect(find.bySemanticsLabel('Start the metronome'), findsOneWidget);
    tester.binding.rootPipelineOwner.visitChildren((owner) {
      owner.semanticsOwner?.performAction(node.id, SemanticsAction.increase);
    });
    await tester.pump();
    expect(scope.metronome.bpm, 81);
    expect(scope.metronome.isPlaying, isFalse);
    scope.metronome.setBpm(250);
    await tester.pump();
    expect(
      tester
          .getSemantics(finder)
          .getSemanticsData()
          .hasAction(SemanticsAction.increase),
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('gesture lock does not lock tempo adjustments', (tester) async {
    final scope = await _open(tester, locked: true);
    await _turn(tester, math.pi / 2);
    expect(scope.metronome.bpm, 110);
    expect(scope.navigation.section, AppSection.metronome);
  });

  for (final size in [
    const Size(320, 640),
    const Size(640, 360),
    const Size(768, 1024),
  ]) {
    testWidgets('small and large layouts with enlarged text: $size', (
      tester,
    ) async {
      final scope = await _open(tester, size: size, scale: 2);
      await _turn(tester, math.pi / 2);
      expect(scope.metronome.bpm, 110);
      expect(tester.takeException(), isNull);
      expect(find.text('TAP'), findsOneWidget);
    });
  }

  testWidgets('swiping outside the band still changes section', (tester) async {
    final scope = await _open(tester);
    final rect = tester.getRect(find.byKey(DialLayout.dialKey));
    await tester.dragFrom(rect.center, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(scope.navigation.section, AppSection.drone);
  });
}
