import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/widgets/dial.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('four compact rows and a centred dial on every tab: $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.reset);
      final settings = AppSettings()..markGuideSeen();
      await tester.pumpWidget(
        LowEndApp(
          settings: settings,
          toneOutput: SilentToneOutput(),
          clickOutput: SilentClickOutput(),
          micInput: FakeMicInput(),
          trackOutput: SilentTrackOutput(),
          trackFiles: FakeTrackFiles(
            next: const TrackRef(uri: 'content://song', name: 'Song.mp3'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
      // Measure the Player with its full passage strip, not only an empty
      // message row: loading a loop must not move the rows below it.
      await scope.player.pick();
      await scope.player.setLoop(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );
      await tester.pumpAndSettle();
      Rect? firstDial;
      for (final section in AppSection.values) {
        scope.navigation.open(section);
        await tester.pumpAndSettle();
        final page = tester.getRect(find.byType(DialLayout));
        final dial = tester.getRect(find.byKey(DialLayout.dialKey));
        final rows = [
          for (final key in DialLayout.rowKeys) tester.getRect(find.byKey(key)),
        ];
        for (final row in rows) {
          expect(row.height, closeTo(64, 0.01), reason: section.name);
        }
        expect(rows[1].top - rows[0].bottom, closeTo(8, 0.01));
        expect(rows[2].top - rows[1].bottom, closeTo(8, 0.01));
        final nav = tester.getRect(find.byType(NavigationBar));
        // The system inset and 2 dp red baseline are outside the tab row.
        expect(nav.height, closeTo(64 + 20, 0.01));
        expect(nav.top - rows[2].bottom, closeTo(8, 0.01));
        expect(dial.center.dy, closeTo((page.top + rows[0].top) / 2, 0.01));
        expect(dial.center.dx, closeTo(page.center.dx, 0.01));
        expect(dial, tester.getRect(find.byKey(DialBackdrop.discKey)));
        expect(dial, firstDial ?? dial, reason: section.name);
        firstDial ??= dial;
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('a short screen keeps the dial usable and scrolls its controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialLayout(
            dial: const Placeholder(),
            upper: const Text('Upper'),
            lower: const Text('Lower'),
          ),
        ),
      ),
    );
    final dial = tester.getRect(find.byKey(DialLayout.dialKey));
    expect(dial.width, greaterThanOrEqualTo(200));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(DialLayout.rowKeys.last)).bottom,
      lessThanOrEqualTo(400),
    );
    expect(tester.takeException(), isNull);
  });
}
