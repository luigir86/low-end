import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';

/// Checks the main screens against Flutter's accessibility guidelines: touch
/// targets of at least 48 dp, a label on every tappable element, and text
/// contrast of at least 4.5:1 (3:1 for large text), as WCAG 2.1 AA asks.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Future<void> pumpApp(
  WidgetTester tester, {
  MicInput? mic,
  ThemeMode? themeMode,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (themeMode == ThemeMode.dark) {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: SilentToneOutput(),
      micInput: mic ?? FakeMicInput(),
      trackOutput: SilentTrackOutput(),
      trackFiles: FakeTrackFiles(
        next: const TrackRef(uri: 'content://song', name: 'Blue Bossa.mp3'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The app opens on the metronome; these checks start from the tuner.
  await tester.tap(find.text('Tuner'));
  await tester.pumpAndSettle();
}

/// The Harmony and Metronome tabs: their names are not written anywhere
/// else on the screen.
final _harmonyTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text('Harmony'),
);
final _playerTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text('Player'),
);
final _metronomeTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text('Metronome'),
);

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    // The app is always dark; the phone's own setting must change nothing.
    testWidgets(
      'every screen meets the guidelines (phone set to ${mode.name})',
      (tester) async {
        final handle = tester.ensureSemantics();
        final mic = FakeMicInput();
        await pumpApp(tester, mic: mic, themeMode: mode);
        await expectAccessible(tester);

        // A note slightly flat, then in tune: both colours must stay readable.
        for (final hz in [97.0, 98.0]) {
          for (var i = 0; i < 5; i++) {
            mic.add(_sine(hz, 1600, chunk: i));
            await tester.pump();
          }
          await tester.pump(const Duration(milliseconds: 200));
          await expectAccessible(tester);
        }

        await tester.tap(_harmonyTab.first);
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        // A progression adds the button of the example songs to the row.
        await tester.tap(find.byKey(const Key('voicingMenu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Progression').last);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Example songs'), findsOneWidget);
        await expectAccessible(tester);

        await tester.tap(_metronomeTab);
        await tester.pumpAndSettle();
        await expectAccessible(tester);

        // The Player, empty and then with a track, playing and not.
        await tester.tap(_playerTab);
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        await tester.tap(find.byKey(const Key('playerHub')));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        await tester.tap(find.byKey(const Key('playerHub')));
        await tester.pump(const Duration(milliseconds: 300));
        await expectAccessible(tester);
        handle.dispose();
      },
    );
  }

  testWidgets('screen readers hear the note and whether it is in tune', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final mic = FakeMicInput();
    await pumpApp(tester, mic: mic);
    for (var i = 0; i < 5; i++) {
      mic.add(_sine(98, 1600, chunk: i));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getSemantics(find.bySemanticsLabel('G2, In tune')),
      matchesSemantics(label: 'G2, In tune', isLiveRegion: true),
    );
    handle.dispose();
  });

  testWidgets('drone keys and the reference pitch are labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.tap(_harmonyTab.first);
    await tester.pumpAndSettle();
    // Each key says what a touch does.
    expect(find.bySemanticsLabel('Play A'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Play A'));
    await tester.pump();
    expect(find.bySemanticsLabel('Stop A'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Reference A')), findsWidgets);
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('screens fit with the largest text size', (tester) async {
    await pumpApp(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(_harmonyTab.first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('A'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.tap(_metronomeTab);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.tap(_playerTab);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}

Float64List _sine(double hz, int length, {int chunk = 0, int rate = 16000}) =>
    Float64List.fromList([
      for (var i = chunk * length; i < (chunk + 1) * length; i++)
        0.3 * math.sin(2 * math.pi * hz * i / rate),
    ]);
