// Screenshots for UI review, not regression tests.
//
// Regenerate with:
//   flutter test test_screenshots/ui_review_test.dart --update-goldens
// then look at the PNGs in test_screenshots/goldens/. They live outside
// test/ so that a plain `flutter test` skips them, and are not committed.
@Tags(['ui_review'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';

// Roboto and the Material icons (the tests' text and icon fonts), copied from the Flutter SDK into the repo
// (Apache 2.0, licences beside them) so the tests find them on any machine.
const _fonts = 'test/fonts';

Future<ByteData> _font(String file) async =>
    ByteData.sublistView(await File('$_fonts/$file').readAsBytes());

/// One screen configuration.
Future<ByteData> _asset(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

class _Config {
  const _Config(
    this.id, {
    this.lang = 'en',
    this.dark = false,
    this.scale = 1.0,
    this.size = const Size(1080, 2400),
  });

  final String id;
  final String lang;
  final bool dark;
  final double scale;
  final Size size;

  bool get it => lang == 'it';
}

const _configs = [
  _Config('en_light'),
  _Config('it_dark', lang: 'it', dark: true),
  _Config('it_light', lang: 'it'),
  _Config('en_light_x1.5', scale: 1.5),
  _Config('it_dark_x1.5', lang: 'it', dark: true, scale: 1.5),
  // 360x640 dp at the same density.
  _Config('it_small', lang: 'it', size: Size(945, 1680)),
  _Config('en_small_x1.5', scale: 1.5, size: Size(945, 1680)),
  // Landscape, 915x412 dp and the narrow 640x360.
  _Config('it_landscape_dark', lang: 'it', dark: true, size: Size(2400, 1080)),
  _Config('en_landscape_x1.5', scale: 1.5, size: Size(2400, 1080)),
  _Config('en_landscape_narrow', size: Size(1680, 945)),
];

class _Harness {
  _Harness(this.tester, this.config);

  final WidgetTester tester;
  final _Config config;
  final mic = FakeMicInput();
  var _chunk = 0;

  Future<void> start() async {
    // The debug banner would hide the settings gear.
    WidgetsApp.debugAllowBannerOverride = false;
    addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
    tester.view.physicalSize = config.size;
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.localesTestValue = [Locale(config.lang)];
    tester.platformDispatcher.localeTestValue = Locale(config.lang);
    tester.platformDispatcher.platformBrightnessTestValue = config.dark
        ? Brightness.dark
        : Brightness.light;
    tester.platformDispatcher.textScaleFactorTestValue = config.scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: mic,
      ),
    );
    await _settle();
  }

  /// The strobe animates forever, so pumpAndSettle would never return.
  Future<void> _settle() async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A second of a continuous sine at [hz].
  Future<void> play(double hz) async {
    for (var i = 0; i < 20; i++) {
      mic.add(
        Float64List.fromList([
          for (var s = _chunk * 1600; s < (_chunk + 1) * 1600; s++)
            0.3 * math.sin(2 * math.pi * hz * s / 16000),
        ]),
      );
      _chunk++;
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  String t(String en, String it) => config.it ? it : en;

  Future<void> tab(String en, String it) async {
    // In landscape the names are on the rail.
    final rail = find.byKey(const Key('tabRail'));
    await tester.tap(
      rail.evaluate().isEmpty
          ? find.text(t(en, it)).last
          : find.descendant(of: rail, matching: find.text(t(en, it))),
    );
    await _settle();
  }

  Future<void> tapText(String text, {bool scrollIntoView = false}) async {
    final target = find.text(text).first;
    if (scrollIntoView) await tester.ensureVisible(target);
    await tester.tap(target);
    await _settle();
  }

  Future<void> shot(String name) async {
    await expectLater(
      find.byType(LowEndApp),
      matchesGoldenFile('goldens/${config.id}/$name.png'),
    );
  }
}

void main() {
  setUpAll(() async {
    final roboto = FontLoader('Roboto')
      ..addFont(_font('roboto-regular.ttf'))
      ..addFont(_font('roboto-medium.ttf'))
      ..addFont(_font('roboto-bold.ttf'));
    await roboto.load();
    // The app's own fonts, as the phone has them.
    final edwin = FontLoader('Edwin')
      ..addFont(_asset('assets/fonts/Edwin-Roman.otf'))
      ..addFont(_asset('assets/fonts/Edwin-Bold.otf'));
    await edwin.load();
    final music = FontLoader('NotoMusic')
      ..addFont(_asset('assets/fonts/NotoMusic-Regular.ttf'));
    await music.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(_font('materialicons-regular.otf'));
    await icons.load();
  });

  for (final config in _configs) {
    group(config.id, () {
      testWidgets('tuner', (tester) async {
        final h = _Harness(tester, config);
        await h.start();
        await h.tab('Tuner', 'Accordatore');
        await h.shot('tuner_1_listening');
        // E1 about 20 cents flat.
        await h.play(41.2 * math.pow(2, -20 / 1200));
        await h.shot('tuner_2_flat');
        // A little off: the note turns ochre.
        await h.play(41.2 * math.pow(2, -9 / 1200));
        await h.shot('tuner_2b_close');
        await h.play(55);
        await h.shot('tuner_3_in_tune');
        await tester.tap(find.byKey(const Key('tunerHub')));
        await h._settle();
        await h.shot('tuner_4_paused');
      });

      testWidgets('harmony', (tester) async {
        final h = _Harness(tester, config);
        await h.start();
        await h.tab('Harmony', 'Armonia');
        await h.shot('harmony_1_idle');
        await h.tapText(h.t('A', 'La'));
        await h.shot('harmony_2_root');
        await h.tapText(h.t('Chord', 'Accordo'));
        await h.tester.tap(
          find.byWidgetPredicate((w) => w is DropdownMenu).first,
        );
        await h._settle();
        await h.shot('harmony_3_chord_dropdown');
        await h.tapText(h.t('Minor', 'Minore'));
        await h.shot('harmony_4_minor');
        await h.tapText(h.t('Progression', 'Progressione'));
        await h.shot('harmony_5_progression');
        await h.tab('Metronome', 'Metronomo');
        await h.shot('metronome_idle_drone_on');
        await h.tapText(h.t('Tap to start', 'Tocca per avviare'));
        await h.shot('metronome_beat_1');
        await h.tester.pump(const Duration(milliseconds: 750));
        await h.shot('metronome_beat_2');
      });

      testWidgets('metronome and settings', (tester) async {
        final oldHitTestWarning = WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(
          () =>
              WidgetController.hitTestWarningShouldBeFatal = oldHitTestWarning,
        );
        final h = _Harness(tester, config);
        await h.start();
        await h.tab('Metronome', 'Metronomo');
        await h.shot('metronome_idle');
        // A bar of one beat is a whole ring.
        await h.tapText('4/4');
        await h.tapText('1/1');
        await h.shot('metronome_1_1_idle');
        await h.tapText(h.t('Tap to start', 'Tocca per avviare'));
        await h.shot('metronome_1_1_beat');
        await h.tester.tap(
          find.bySemanticsLabel(
            h.t('Stop the metronome', 'Ferma il metronomo'),
          ),
        );
        await h._settle();
        await h.tapText('1/1');
        await h.tapText('6/8', scrollIntoView: true);
        await h.shot('metronome_6_8_idle');
        await h.tapText(h.t('Tap to start', 'Tocca per avviare'));
        await h.shot('metronome_6_8_beat');
        await h.tester.tap(
          find.bySemanticsLabel(
            h.t('Stop the metronome', 'Ferma il metronomo'),
          ),
        );
        await h._settle();
        await h.tester.tap(find.byTooltip(h.t('Settings', 'Impostazioni')));
        await h._settle();
        await h.shot('settings_1_top');
        await h.tester.drag(find.byType(ListView).last, const Offset(0, -800));
        await h._settle();
        await h.shot('settings_2_scrolled');
      });
    });
  }
}
