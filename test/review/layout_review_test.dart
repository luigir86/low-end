import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/harmony/harmony.dart';

// Roboto and the Material icons, copied from the Flutter SDK into the repo
// (Apache 2.0, licences beside them) so the tests find them on any machine.
const _fonts = 'test/fonts';

Future<ByteData> _font(String file) async =>
    ByteData.sublistView(await File('$_fonts/$file').readAsBytes());

class _BrokenMic extends FakeMicInput {
  @override
  Future<Stream<Float64List>> start(int sampleRate) async =>
      throw Exception('mic busy');
}

class _Config {
  const _Config(
    this.id, {
    this.lang = 'en',
    this.dark = false,
    this.scale = 1,
    this.size = const Size(360, 640),
  });

  final String id;
  final String lang;
  final bool dark;
  final double scale;
  final Size size;
}

const _configs = [
  _Config('en_360x640_x2', scale: 2),
  _Config('it_360x640_x2', lang: 'it', scale: 2),
  _Config('it_360x640_x2_dark', lang: 'it', scale: 2, dark: true),
  _Config('en_320x568_x1.3', scale: 1.3, size: Size(320, 568)),
  _Config('it_360x640_x1', lang: 'it'),
  // Landscape phone.
  _Config('it_640x360_x1.5', lang: 'it', scale: 1.5, size: Size(640, 360)),
  _Config('en_915x412_x1', size: Size(915, 412)),
  _Config(
    'it_915x412_x2_dark',
    lang: 'it',
    scale: 2,
    dark: true,
    size: Size(915, 412),
  ),
  _Config('en_640x360_x2', scale: 2, size: Size(640, 360)),
  _Config('en_1280x800_x1', size: Size(1280, 800)),
  // French is the longest of the languages, Spanish close to it: the
  // narrowest phone, with large text, and a landscape one.
  _Config('fr_320x568_x2', lang: 'fr', scale: 2, size: Size(320, 568)),
  _Config('fr_360x640_x2', lang: 'fr', scale: 2),
  _Config('fr_640x360_x1.5', lang: 'fr', scale: 1.5, size: Size(640, 360)),
  _Config('es_320x568_x2', lang: 'es', scale: 2, size: Size(320, 568)),
  _Config('es_360x640_x2', lang: 'es', scale: 2),
];

class _H {
  _H(this.tester, this.c, {MicInput? mic}) : mic = mic ?? FakeMicInput();

  final WidgetTester tester;
  final _Config c;
  final MicInput mic;
  final output = SilentToneOutput();
  final problems = <String>[];
  var _chunk = 0;
  late AppSettings settings;

  AudioScope get scope => AudioScope.of(tester.element(find.byType(HomeShell)));

  Future<void> start() async {
    tester.view.physicalSize = c.size * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.localesTestValue = [Locale(c.lang)];
    tester.platformDispatcher.localeTestValue = Locale(c.lang);
    tester.platformDispatcher.platformBrightnessTestValue = c.dark
        ? Brightness.dark
        : Brightness.light;
    tester.platformDispatcher.textScaleFactorTestValue = c.scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    settings = AppSettings();
    await tester.pumpWidget(
      LowEndApp(toneOutput: output, micInput: mic, settings: settings),
    );
    await settle('start');
  }

  Future<void> settle(String step) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final e = tester.takeException();
      if (e != null) problems.add('$step: ${'$e'.split('\n').first}');
    }
  }

  Future<void> play(double hz) async {
    final fake = mic as FakeMicInput;
    for (var i = 0; i < 10; i++) {
      fake.add(
        Float64List.fromList([
          for (var s = _chunk * 1600; s < (_chunk + 1) * 1600; s++)
            0.3 * math.sin(2 * math.pi * hz * s / 16000),
        ]),
      );
      _chunk++;
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle('play $hz');
  }

  Future<void> tab(AppSection section) async {
    scope.navigation.open(section);
    await settle('tab ${section.name}');
  }

  void expectClean() => expect(problems, isEmpty, reason: problems.join('\n'));
}

void main() {
  setUpAll(() async {
    final roboto = FontLoader('Roboto')
      ..addFont(_font('roboto-regular.ttf'))
      ..addFont(_font('roboto-medium.ttf'))
      ..addFont(_font('roboto-bold.ttf'));
    await roboto.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(_font('materialicons-regular.otf'));
    await icons.load();
  });

  for (final c in _configs) {
    group(c.id, () {
      testWidgets('tuner: listening, flat note, paused', (tester) async {
        final h = _H(tester, c);
        await h.start();
        await h.tab(AppSection.tuner);
        await h.play(41.2 * math.pow(2, -20 / 1200));
        await h.play(30.87);
        await tester.tap(find.byKey(const Key('tunerHub')));
        await h.settle('pause');
        h.expectClean();
      });

      testWidgets('tuner: permission denied', (tester) async {
        final h = _H(tester, c, mic: FakeMicInput(allowed: false));
        await h.start();
        h.expectClean();
      });

      testWidgets('tuner: mic failed with the harmony playing', (tester) async {
        final h = _H(tester, c, mic: _BrokenMic());
        await h.start();
        await h.scope.drone.tapNote(10);
        await h.settle('drone on');
        h.expectClean();
      });

      testWidgets('drone: idle, root, seventh chord', (tester) async {
        final h = _H(tester, c);
        await h.start();
        await h.tab(AppSection.drone);
        final drone = h.scope.drone;
        await drone.tapNote(1);
        await h.settle('play C#');
        drone.setVoicing(DroneVoicing.chord);
        drone.setChord(ChordQuality.dominant);
        await h.settle('seventh');
        h.settings.setNaming(NoteNaming.solfege);
        await h.settle('solfege');
        h.expectClean();
      });

      testWidgets('metronome with drone playing', (tester) async {
        final h = _H(tester, c);
        await h.start();
        await h.scope.drone.tapNote(8);
        await h.tab(AppSection.metronome);
        h.expectClean();
      });

      testWidgets('settings page and about dialog', (tester) async {
        final h = _H(tester, c);
        await h.start();
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await h.settle('open settings');
        // The page is long, longer still with the text twice as big.
        await tester.scrollUntilVisible(
          find.byIcon(Icons.info_outline),
          200,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 120,
        );
        await h.settle('scroll');
        await tester.tap(find.byIcon(Icons.info_outline));
        await h.settle('about');
        h.expectClean();
      });
    });
  }

  group('language switch', () {
    for (final tab in AppSection.values) {
      testWidgets('on the ${tab.name} tab while the drone plays', (
        tester,
      ) async {
        final h = _H(tester, const _Config('en', scale: 1));
        await h.start();
        await h.tab(AppSection.drone);
        await h.scope.drone.tapNote(9);
        await h.tab(tab);
        for (final lang in ['it', null, 'it', 'en']) {
          h.settings.setLanguage(lang);
          await h.settle('language $lang');
        }
        h.settings.setLanguage('it');
        await h.settle('it');
        // No tab stops the drone by itself, the tuner included: it waits
        // for a touch.
        expect(h.scope.drone.isPlaying, isTrue);
        expect(h.output.frequencies.single, closeTo(220, 1e-9));
        expect((h.mic as FakeMicInput).isCapturing, isFalse);
        expect(h.scope.navigation.section, tab);
        if (tab == AppSection.drone) expect(find.text('La3'), findsOneWidget);
        h.expectClean();
      });
    }

    testWidgets('renames the chosen chord in the chord menu', (tester) async {
      final h = _H(tester, const _Config('en', scale: 1));
      await h.start();
      await h.tab(AppSection.drone);
      h.scope.drone.setVoicing(DroneVoicing.chord);
      h.scope.drone.setChord(ChordQuality.minor);
      await h.settle('chord');
      expect(find.text('Minor'), findsOneWidget);
      h.settings.setLanguage('it');
      await h.settle('italian');
      expect(find.text('Minore'), findsOneWidget);
      expect(find.text('Minor'), findsNothing);
    });

    testWidgets('from the settings page while the drone plays', (tester) async {
      final h = _H(tester, const _Config('en', scale: 2));
      await h.start();
      await h.tab(AppSection.drone);
      await h.scope.drone.tapNote(9);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await h.settle('open settings');
      await tester.tap(find.byKey(const Key('languageMenu')));
      await h.settle('language menu');
      await tester.tap(find.text('Italiano'));
      await h.settle('italiano');
      expect(find.text('Impostazioni'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await h.settle('back');
      expect(h.scope.drone.isPlaying, isTrue);
      expect((h.mic as FakeMicInput).isCapturing, isFalse);
      h.expectClean();
    });
  });
}
