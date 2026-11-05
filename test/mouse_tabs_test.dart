import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The web app on a computer: a mouse, and a window wider than tall, so the
/// tabs are the rail. A real click often moves the mouse a pixel or two.
void main() {
  Future<AppNavigation> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'seen_guide': true,
      'seen_swipe_hint': true,
    });
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    return AudioScope.of(tester.element(find.byType(HomeShell))).navigation;
  }

  /// A mouse click on [at] that moves [by] while the button is down.
  Future<void> click(
    WidgetTester tester,
    TestGesture mouse,
    Offset at,
    Offset by,
  ) async {
    await mouse.moveTo(at);
    await mouse.down(at);
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.moveTo(at + by);
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.up();
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [
    ('rail', const Size(1600, 900)),
    ('bottom bar', const Size(900, 1600)),
  ]) {
    testWidgets('a mouse click that moves a little changes tab ($name)', (
      tester,
    ) async {
      final navigation = await open(tester, size);
      expect(navigation.section, AppSection.drone);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      for (final (tab, section) in [
        ('Tuner', AppSection.tuner),
        ('Metronome', AppSection.metronome),
        ('Harmony', AppSection.drone),
      ]) {
        await click(
          tester,
          mouse,
          tester.getCenter(find.text(tab).last),
          const Offset(1, 3),
        );
        expect(navigation.section, section);
      }
    });
  }

  testWidgets('a mouse drag on the rail does not flip the section', (
    tester,
  ) async {
    final navigation = await open(tester, const Size(1600, 900));
    final rail = find.byKey(const Key('tabRail'));
    final at = tester.getTopLeft(rail) + const Offset(40, 40);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.down(at);
    for (var i = 1; i <= 5; i++) {
      await mouse.moveTo(at + Offset(0, 20.0 * i));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    expect(navigation.section, AppSection.drone);
  });
}
