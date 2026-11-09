// The phone screenshots of the Google Play listing (1156 x 2312), made from
// the real app with its own fonts, in English and Italian.
//
//   flutter test test_screenshots/store_screenshots_test.dart --update-goldens
//
// The PNGs are written to store/graphics/phone/<locale>/.
@Tags(['ui_review'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/l10n/app_localizations.dart';

Future<ByteData> _file(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

void main() {
  setUpAll(() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(_file(f));
      }
      await loader.load();
    }

    await load('Edwin', [
      'assets/fonts/Edwin-Roman.otf',
      'assets/fonts/Edwin-Bold.otf',
    ]);
    await load('NotoMusic', ['assets/fonts/NotoMusic-Regular.ttf']);
    await load('MaterialIcons', ['test/fonts/materialicons-regular.otf']);
  });

  for (final (locale, lang, track) in [
    ('en-US', 'en', 'Band rehearsal'),
    ('it-IT', 'it', 'Prova con la band'),
    ('es-ES', 'es', 'Ensayo con la banda'),
    ('fr-FR', 'fr', 'Répétition du groupe'),
  ]) {
    testWidgets('store screenshots $locale', (tester) async {
      final l10n = lookupAppLocalizations(Locale(lang));
      WidgetsApp.debugAllowBannerOverride = false;
      addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
      tester.view.physicalSize = const Size(1156, 2312);
      tester.view.devicePixelRatio = 2.625;
      tester.platformDispatcher.localesTestValue = [Locale(lang)];
      tester.platformDispatcher.localeTestValue = Locale(lang);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final mic = FakeMicInput();
      final files = FakeTrackFiles(
        next: TrackRef(uri: 'content://rehearsal', name: '$track.m4a'),
      );
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          clickOutput: SilentClickOutput(),
          pianoOutput: SilentPianoOutput(),
          micInput: mic,
          trackOutput: SilentTrackOutput(length: const Duration(minutes: 4)),
          trackFiles: files,
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      Future<void> shot(String name) => expectLater(
        find.byType(LowEndApp),
        matchesGoldenFile('../store/graphics/phone/$locale/$name.png'),
      );

      await settle();

      // 1. Harmony, where the app first opens: the progression it opens on
      // (I–VI–IV–V in A, Stand by Me), playing.
      final dialCentre = tester.getCenter(find.text(l10n.droneHint));
      await tester.tapAt(dialCentre);
      await settle();
      await tester.pump(const Duration(milliseconds: 600));
      await shot('1_harmony');

      // 2. The progressions, the menu open on the harmony's dial.
      await tester.tap(find.byKey(const Key('progressionMenu')));
      await settle();
      await shot('2_progressions');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      // Stopped, so that the tuner pauses nothing.
      await tester.tapAt(dialCentre);
      await settle();

      // 4. The tuner, a little flat on an E.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byTooltip(l10n.tunerTab),
        ),
      );
      await settle();
      for (var i = 0; i < 20; i++) {
        mic.add(
          Float64List.fromList([
            for (var s = i * 1600; s < (i + 1) * 1600; s++)
              0.3 *
                  math.sin(
                    2 * math.pi * 82.41 * math.pow(2, -9 / 1200) * s / 16000,
                  ),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await shot('4_tuner');

      // 3. The metronome, running, with swung eighths.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byTooltip(l10n.metronomeTab),
        ),
      );
      await settle();
      await tester.tap(find.byKey(const Key('subdivisionMenu')));
      await settle();
      await tester.tap(find.text(l10n.subdivisionSwungEighths));
      await settle();
      await tester.tap(find.text(l10n.metronomeHint));
      await settle();
      await tester.pump(const Duration(milliseconds: 600));
      await shot('3_metronome');

      // 5. The Player: a rehearsal of the person's own, slowed to 80%, with a
      // passage looping on its waveform.
      final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
      final player = scope.player;
      await scope.metronome.stop();
      await settle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byTooltip(l10n.playerTab),
        ),
      );
      await settle();
      await player.open(files.next!);
      await settle();
      // A made-up wave: phrases that swell and fade, with beats, 10 ms a
      // value.
      final rng = math.Random(7);
      files.peakStreams.last.add(
        Uint16List.fromList([
          for (var i = 0; i < 24000; i++)
            (32767 *
                    math.pow(
                      10,
                      -(30 * (1 - math.sin(math.pi * (i % 2300) / 2300)) +
                              10 * (1 - math.sin(math.pi * (i % 170) / 170)) +
                              6 * rng.nextDouble()) /
                          20,
                    ))
                .round(),
        ]),
      );
      await files.peakStreams.last.close();
      player.setSpeed(80);
      await player.setLoop(
        const Duration(minutes: 1, seconds: 4),
        const Duration(minutes: 1, seconds: 36),
      );
      await player.seek(const Duration(minutes: 1, seconds: 17));
      await player.start();
      await settle();
      await tester.pump(const Duration(milliseconds: 600));
      await shot('5_player');
      await player.stop();
      await settle();
    });
  }
}
