// The app opens as it was left: on the same section, with the harmony set as
// the player chose it, like the metronome's tempo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:shared_preferences/shared_preferences.dart';

const DroneSetup _blues = (
  pitchClass: 6,
  voicing: DroneVoicing.progression,
  chordVoicing: DroneVoicing.root,
  chord: ChordQuality.minor,
  progression: Progression.blues,
  style: DroneStyle.walking,
  continuous: false,
  flats: {6},
);

/// [setup] as plain values, the black keys sorted, to compare.
List<Object> _plain(DroneSetup? setup) => [
  setup!.pitchClass,
  setup.voicing,
  setup.chordVoicing,
  setup.chord,
  setup.progression,
  setup.style,
  setup.continuous,
  ...setup.flats.toList()..sort(),
];

Future<AudioScope> _open(
  WidgetTester tester,
  AppSettings settings, {
  SilentPianoOutput? piano,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: SilentToneOutput(),
      pianoOutput: piano ?? SilentPianoOutput(),
      micInput: FakeMicInput(),
      settings: settings,
    ),
  );
  await tester.pumpAndSettle();
  return AudioScope.of(tester.element(find.byType(HomeShell)));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'seen_guide': true}));

  group('the settings keep', () {
    test('the harmony and the section for the next launch', () async {
      final settings = await AppSettings.load();
      expect(settings.drone, isNull);
      expect(settings.section, AppSection.drone);
      settings.rememberDrone(_blues);
      settings.rememberSection(AppSection.tuner);
      await Future<void>.delayed(Duration.zero);

      final again = await AppSettings.load();
      expect(_plain(again.drone), _plain(_blues));
      expect(again.section, AppSection.tuner);
    });

    test('values they cannot read fall back, one by one', () async {
      SharedPreferences.setMockInitialValues({
        'harmony_note': 2,
        'harmony_style': 'bebop',
        'harmony_progression': 7,
        'harmony_flats': ['x', '1'],
        'section': 'library',
      });
      final settings = await AppSettings.load();
      final drone = settings.drone!;
      expect(drone.pitchClass, 2);
      expect(drone.style, DroneStyle.beat);
      expect(drone.progression, Progression.values.first);
      expect(drone.flats, {1});
      expect(settings.section, AppSection.drone);
    });

    test('nothing for a note out of range', () async {
      SharedPreferences.setMockInitialValues({'harmony_note': 14});
      expect((await AppSettings.load()).drone, isNull);
    });
  });

  group('the app opens as it was left', () {
    testWidgets('the first time on the harmony, on a '
        'progression, a chord on every beat', (tester) async {
      final scope = await _open(tester, await AppSettings.load());
      expect(scope.navigation.section, AppSection.drone);
      expect(scope.drone.voicing, DroneVoicing.progression);
      expect(scope.drone.progression, Progression.oneSixFourFive);
      expect(scope.drone.note.pitchClass, 9);
      // Chord, from there, is a chord and not the note alone.
      expect(scope.drone.chordVoicing, DroneVoicing.chord);
      expect(scope.drone.style, DroneStyle.beat);
      expect(scope.drone.isPlaying, isFalse);
    });

    testWidgets('on the harmony, as it was, silent and ready', (tester) async {
      final first = await AppSettings.load();
      first.rememberDrone(_blues);
      first.rememberSection(AppSection.drone);
      await tester.pump();

      final piano = SilentPianoOutput();
      final scope = await _open(tester, await AppSettings.load(), piano: piano);
      expect(scope.navigation.section, AppSection.drone);
      final pages = tester.widget<PageView>(find.byType(PageView));
      expect(pages.controller!.page, AppSection.drone.index);
      expect(_plain(scope.drone.setup), _plain(_blues));
      expect(scope.drone.isPlaying, isFalse);
      // Got ready for the touch a moment after the first frames
      // (RNF-AVV-01), the double bass with it: the blues is walking.
      expect(piano.prepared, isNull);
      await tester.pump(LowEndApp.prepareAfterLaunch);
      expect(piano.prepared, isNotNull);
      expect(piano.preparedBass, isTrue);
      expect(piano.chords, isNull);
    });

    testWidgets('on the harmony, the double bass only for a walking bass', (
      tester,
    ) async {
      final first = await AppSettings.load();
      first.rememberDrone((
        pitchClass: _blues.pitchClass,
        voicing: _blues.voicing,
        chordVoicing: _blues.chordVoicing,
        chord: _blues.chord,
        progression: _blues.progression,
        style: DroneStyle.beat,
        continuous: _blues.continuous,
        flats: _blues.flats,
      ));
      first.rememberSection(AppSection.drone);
      await tester.pump();

      final piano = SilentPianoOutput();
      await _open(tester, await AppSettings.load(), piano: piano);
      await tester.pump(LowEndApp.prepareAfterLaunch);
      expect(piano.prepared, isNotNull);
      // Not read ahead any more: 90 files, on the screen's thread.
      expect(piano.preparedBass, isFalse);
    });

    testWidgets('what the player changes is kept', (tester) async {
      final settings = await AppSettings.load();
      final scope = await _open(tester, settings);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Tuner'),
        ),
      );
      await tester.pumpAndSettle();
      scope.drone.setStyle(DroneStyle.arpeggio);
      scope.drone.setPitchClass(3);
      await tester.pump();

      final again = await AppSettings.load();
      expect(again.section, AppSection.tuner);
      expect(again.drone!.style, DroneStyle.arpeggio);
      expect(again.drone!.pitchClass, 3);
    });
  });

  group('getting the piano ready', () {
    test('brings the double bass after it', () async {
      final piano = SilentPianoOutput();
      final drone = DroneController(
        SilentToneOutput(),
        piano: piano,
        prefetchBass: true,
      );
      drone.setVoicing(DroneVoicing.chord);
      drone.preparePiano();
      await Future<void>.delayed(Duration.zero);
      expect(piano.preparedBass, isTrue);
      drone.dispose();
    });

    test(
      'leaves it, unless asked to, until the walking bass is chosen',
      () async {
        final piano = SilentPianoOutput();
        final drone = DroneController(SilentToneOutput(), piano: piano);
        drone.setVoicing(DroneVoicing.chord);
        drone.preparePiano();
        await Future<void>.delayed(Duration.zero);
        expect(piano.preparedBass, isFalse);
        drone.dispose();
      },
    );

    test('mixes the loop a touch would play, before the touch', () async {
      final piano = SilentPianoOutput();
      final drone = DroneController(SilentToneOutput(), piano: piano);
      drone.setVoicing(DroneVoicing.chord);
      drone.setStyle(DroneStyle.walking);
      drone.preparePiano();
      await Future<void>.delayed(Duration.zero);
      expect(piano.prerendered, piano.prepared);
      expect(piano.prerenderedStyle, PianoStyle.walking);
      drone.dispose();
    });

    test('mixes it again once the player stops changing it', () async {
      final piano = SilentPianoOutput();
      final drone = DroneController(SilentToneOutput(), piano: piano);
      drone.setVoicing(DroneVoicing.chord);
      drone.preparePiano();
      await Future<void>.delayed(Duration.zero);
      final first = piano.prerendered;
      drone.setPitchClass(2);
      drone.setPitchClass(4);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(piano.prerendered, first);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(piano.prerendered!.first.first % 12, 4);
      drone.dispose();
    });
  });
}
