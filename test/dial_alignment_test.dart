import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/widgets/dial.dart';
import 'package:low_end/widgets/reference_pitch_row.dart';

/// The three round dials (beats, circle of fifths, strobe) and the rows under
/// them must sit in the same place on every tab: moving between tabs, only
/// what is drawn inside them changes.
void main() {
  Future<void> open(
    WidgetTester tester,
    Size size,
    double scale, {
    MicInput? mic,
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
        micInput: mic ?? FakeMicInput(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The dial box and the three rows of the section on screen.
  List<Rect> geometry(WidgetTester tester) {
    final layouts = find.byType(DialLayout);
    // Sideways pages in portrait, one above the other in landscape (beside
    // the tab rail): the visible page starts at the page viewport origin,
    // below the shared header in landscape.
    final wide = tester.view.physicalSize.aspectRatio > 1;
    final viewport = tester.getRect(find.byType(PageView));
    final onScreen = [
      for (var i = 0; i < layouts.evaluate().length; i++)
        if ((wide
                ? tester.getRect(layouts.at(i)).top
                : tester.getRect(layouts.at(i)).left) ==
            (wide ? viewport.top : viewport.left))
          i,
    ];
    expect(onScreen, hasLength(1), reason: 'one section on screen');
    final layout = layouts.at(onScreen.single);
    final boxes = find.descendant(
      of: layout,
      matching: find.byType(ConstrainedBox),
    );
    final rows = <Rect>[];
    for (final e in boxes.evaluate()) {
      final box = e.renderObject! as RenderBox;
      final c = (e.widget as ConstrainedBox).constraints;
      if (c.minHeight == DialLayout.rowHeight) {
        rows.add(box.localToGlobal(Offset.zero) & box.size);
      }
    }
    expect(rows, hasLength(3), reason: 'dial, then three rows');
    final dial = find.descendant(
      of: layout,
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width != null && w.width == w.height,
      ),
    );
    final d = tester.getRect(dial.first);
    return [d, ...rows];
  }

  Future<List<List<Rect>>> allTabs(WidgetTester tester) async {
    final all = <List<Rect>>[];
    for (final tab in ['Metronome', 'Harmony', 'Player', 'Tuner']) {
      final rail = find.byKey(const Key('tabRail'));
      await tester.tap(
        rail.evaluate().isEmpty
            ? find.text(tab).last
            : find.descendant(of: rail, matching: find.text(tab)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      all.add(geometry(tester));
    }
    return all;
  }

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.5),
    (const Size(915, 412), 1.0),
    (const Size(915, 412), 2.0),
    (const Size(640, 360), 1.0),
    (const Size(640, 360), 1.5),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets('dials and rows are aligned on $size at x$scale', (
      tester,
    ) async {
      await open(tester, size, scale);
      final tabs = await allTabs(tester);
      for (final g in tabs) {
        expect(g.length, 4);
        expect(g[0].center, tabs[0][0].center);
        expect(g[0].size, tabs[0][0].size);
        for (var i = 1; i < 4; i++) {
          expect(g[i].top, tabs[0][i].top, reason: 'row $i');
        }
      }
    });
  }

  testWidgets('the three rows are equal, slider row included', (tester) async {
    await open(tester, const Size(390, 844), 1.0);
    for (final g in await allTabs(tester)) {
      // The same height and no space between them, whatever is in them:
      // the rows of controls and the slider's are one measure. Global rects
      // subtract transformed coordinates, so allow floating-point roundoff
      // while still rejecting even a tiny visible height or spacing change.
      for (var i = 1; i < 4; i++) {
        expect(g[i].height, closeTo(DialLayout.rowHeight, 1e-6));
      }
      expect(g[2].top, closeTo(g[1].bottom, 1e-6));
      expect(g[3].top, closeTo(g[2].bottom, 1e-6));
    }
  });

  testWidgets('the first row is empty on the metronome and the harmony, and '
      'holds the cents bar or message on the tuner', (tester) async {
    await open(tester, const Size(390, 844), 1.0);
    final tabs = await allTabs(tester);
    // allTabs leaves the tuner open; check it first, then go back.
    final tuner = tabs[3];
    await tester.pumpAndSettle();
    final hint = tester.getRect(find.text('Cents').last);
    expect(hint.center.dy, inInclusiveRange(tuner[1].top, tuner[1].bottom));
    expect(
      tester.getRect(find.text('Chromatic').last).center.dy,
      inInclusiveRange(tuner[2].top, tuner[2].bottom),
    );
    expect(
      tester.getRect(find.byType(ReferencePitchRow).last).center.dy,
      inInclusiveRange(tuner[3].top, tuner[3].bottom),
    );
    await tester.tap(find.text('Metronome').last);
    await tester.pumpAndSettle();
    final metro = tabs[0];
    expect(
      tester.getRect(find.text('TAP').last).center.dy,
      inInclusiveRange(metro[3].top, metro[3].bottom),
    );
    expect(
      tester.getRect(find.byKey(const Key('barSwitch')).last).center.dy,
      inInclusiveRange(metro[2].top, metro[2].bottom),
    );
  });

  testWidgets('the dial stays put when the tuner shows a long message', (
    tester,
  ) async {
    await open(
      tester,
      const Size(390, 844),
      1.0,
      mic: FakeMicInput(allowed: false),
    );
    final tabs = await allTabs(tester);
    expect(tabs[3][0].center.dy, tabs[0][0].center.dy);
    expect(tabs[3][0].size, tabs[0][0].size);
  });

  testWidgets('landscape: dial on the left, three equal rows to its right', (
    tester,
  ) async {
    await open(tester, const Size(915, 412), 1.0);
    for (final g in await allTabs(tester)) {
      expect(g[0].height, inInclusiveRange(300, 360));
      expect(g[0].left, lessThan(150), reason: 'the dial is by the rail');
      for (var i = 1; i < 4; i++) {
        expect(g[i].height, closeTo(DialLayout.rowHeight, 1e-6));
        expect(g[i].left, greaterThanOrEqualTo(g[0].right));
        expect(g[i].width, greaterThanOrEqualTo(DialLayout.columnMinWidth));
      }
      expect(g[2].top, closeTo(g[1].bottom, 1e-6));
      expect(g[3].top, closeTo(g[2].bottom, 1e-6));
    }
  });

  testWidgets('landscape on a narrow phone: smaller dial, column kept', (
    tester,
  ) async {
    await open(tester, const Size(640, 360), 1.0);
    final g = (await allTabs(tester)).first;
    expect(g[0].width, lessThan(260));
    expect(g[0].width, greaterThanOrEqualTo(160));
    expect(g[1].width, greaterThanOrEqualTo(DialLayout.columnMinWidth));
  });
}
