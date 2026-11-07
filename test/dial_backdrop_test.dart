import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/widgets/dial.dart';

/// The disc and the background stay still under the pages: moving between
/// sections only the ring and the controls come and go over them.
void main() {
  Future<void> open(
    WidgetTester tester,
    Size size, {
    double scale = 1.0,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Rect disc(WidgetTester tester) =>
      tester.getRect(find.byKey(DialBackdrop.discKey));

  Future<void> goTo(WidgetTester tester, String tab) async {
    final rail = find.byKey(const Key('tabRail'));
    await tester.tap(
      rail.evaluate().isEmpty
          ? find.byTooltip(tab)
          : find.descendant(of: rail, matching: find.text(tab)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final size in [
    const Size(390, 844),
    const Size(360, 640),
    const Size(915, 412),
    const Size(1280, 800),
  ]) {
    testWidgets('the disc is under the dial of every section on $size', (
      tester,
    ) async {
      await open(tester, size);
      for (final tab in ['Metronome', 'Harmony', 'Tuner']) {
        await goTo(tester, tab);
        // Only the section on screen is built on screen: the others wait
        // out of the way.
        final dial = tester.getRect(find.byKey(DialLayout.dialKey));
        final d = disc(tester);
        expect(d.center.dx, closeTo(dial.center.dx, 0.01), reason: tab);
        expect(d.center.dy, closeTo(dial.center.dy, 0.01), reason: tab);
        expect(d.width, closeTo(dial.width, 0.01), reason: tab);
      }
    });
  }

  testWidgets('the disc stays put while the page is dragged', (tester) async {
    await open(tester, const Size(390, 844));
    final before = disc(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-60, 0));
    await gesture.moveBy(const Offset(-90, 0));
    await tester.pump();
    // The sections come in over the disc: both are on screen, and the dial
    // of the one leaving has not slid away with the page.
    expect(find.byKey(DialLayout.dialKey), findsNWidgets(2));
    expect(disc(tester), before);
    for (final e in find.byKey(DialLayout.dialKey).evaluate()) {
      final box = e.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      expect(rect.center.dx, closeTo(before.center.dx, 0.01));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(disc(tester), before);
    expect(find.byKey(DialLayout.dialKey), findsOneWidget);
  });

  testWidgets(
    'with very large text the disc follows the page when it scrolls',
    (tester) async {
      await open(tester, const Size(320, 480), scale: 2.0);
      final before = disc(tester);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      final dial = tester.getRect(find.byKey(DialLayout.dialKey));
      expect(dial.top, lessThan(before.top), reason: 'the page scrolled');
      final d = disc(tester);
      expect(d.center.dy, closeTo(dial.center.dy, 0.01));
      expect(d.center.dx, closeTo(dial.center.dx, 0.01));
    },
  );
}
