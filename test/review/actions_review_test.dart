import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/actions/app_actions.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/tuner/tuner_controller.dart';

Map<String, Object?> _state(Map<String, Object?> r) =>
    r['state']! as Map<String, Object?>;

void main() {
  late SilentToneOutput output;
  late FakeMicInput mic;
  late AppSettings settings;
  late AppActions actions;
  late DroneController drone;
  late AppNavigation navigation;

  setUp(() {
    output = SilentToneOutput();
    mic = FakeMicInput();
    settings = AppSettings();
    drone = DroneController(output);
    navigation = AppNavigation();
    actions = AppActions(
      drone: drone,
      metronome: MetronomeController(SilentClickOutput()),
      tuner: TunerController(mic),
      navigation: navigation,
      settings: settings,
    );
  });

  group('argument validation', () {
    test('missing required argument', () async {
      final r = await actions.call('set_reference_pitch');
      expect(r['ok'], isFalse);
      expect(r['error'], contains('needs "hz"'));
      expect(
        (await actions.call('open_section', {'section': null}))['ok'],
        isFalse,
      );
    });

    test('wrong types are explained, not thrown', () async {
      for (final (name, args) in [
        ('set_reference_pitch', {'hz': '442'}),
        ('set_reference_pitch', {'hz': true}),
        ('set_reference_pitch', {'hz': 442.5}),
        ('set_reference_pitch', {'hz': double.nan}),
        ('open_section', {'section': 3}),
        ('open_section', {'section': 'settings'}),
        ('drone_set', {'voicing': 1}),
        ('drone_set', {'note': 'H'}),
        ('drone_set', {'note': ''}),
        ('drone_set', {'note': 'A##'}),
        ('settings_set', {'language': 'fr'}),
        ('settings_set', {'language': 1}),
        ('settings_set', {'note_names': 'numbers'}),
      ]) {
        final r = await actions.call(name, args);
        expect(r['ok'], isFalse, reason: '$name $args');
        expect(r['error'], isA<String>(), reason: '$name $args');
      }
    });

    test('int hz is accepted', () async {
      final r = await actions.call('set_reference_pitch', {'hz': 442});
      expect(r['ok'], isTrue);
      expect(settings.a4, 442.0);
    });

    test('a rejected call changes nothing (settings_set)', () async {
      final r = await actions.call('settings_set', {
        'language': 'it',
        'note_names': 'bogus',
      });
      expect(r['ok'], isFalse);
      expect(
        settings.languageCode,
        isNull,
        reason: 'language applied although the call was rejected',
      );
    });

    test('a rejected call changes nothing (drone_set)', () async {
      final r = await actions.call('drone_set', {
        'note': 'D',
        'chord': 'ninth',
      });
      expect(r['ok'], isFalse);
      expect(
        drone.note.pitchClass,
        9,
        reason: 'note applied although the call was rejected',
      );
    });

    test(
      'note names with octave numbers are accepted and octave ignored',
      () async {
        for (final (text, pc) in [
          ('A2', 9),
          ('Bb1', 10),
          ('Sib1', 10),
          ('la3', 9),
          ('Do#', 1),
          ('Cb', 11),
          ('B#', 0),
          ('Mi♭', 3),
          (' fa ', 5),
          ('Sol', 7),
          ('Re', 2),
          ('E-1', 4),
        ]) {
          final r = await actions.call('drone_set', {'note': text});
          expect(r['ok'], isTrue, reason: text);
          expect(drone.note.pitchClass, pc, reason: text);
          expect(drone.note.octave, DroneController.rootOctave, reason: text);
        }
      },
    );

    test('drone_play twice does not restart, chord then root', () async {
      await actions.call('drone_play', {'note': 'E', 'voicing': 'chord'});
      expect(output.frequencies, hasLength(3));
      await actions.call('drone_play', {'voicing': 'root'});
      expect(output.frequencies, hasLength(1));
      expect(drone.isPlaying, isTrue);
    });

    test('state reports a reading with rounded values', () async {
      final r = await actions.call('get_state');
      expect(r['ok'], isTrue);
      final s = _state(r);
      expect((s['tuner']! as Map)['reading'], isNull);
      expect((s['drone']! as Map)['frequency_hz'], 220.0);
      expect(s['metronome'], {
        'playing': false,
        'bpm': 80,
        'time_signature': '4/4',
        'subdivision': 'quarters',
        'backbeat': false,
      });
    });
  });

  group('deep links', () {
    test('the link in the parseLink doc comment works', () async {
      // "lowend://action/drone_play?note=A" is the documented example. It
      // used to carry "&octave=2", which the drone has no parameter for.
      final link = AppActions.parseLink(
        Uri.parse('lowend://action/drone_play?note=A'),
      )!;
      final r = await actions.call(link.$1, link.$2);
      expect(r['ok'], isTrue, reason: '${r['error']}');
      // An unknown argument is still refused with a readable reason.
      final old = AppActions.parseLink(
        Uri.parse('lowend://action/drone_play?note=A&octave=2'),
      )!;
      final refused = await actions.call(old.$1, old.$2);
      expect(refused['ok'], isFalse);
      expect(refused['error'], contains('octave'));
    });

    test('typed arguments from query strings', () {
      expect(
        AppActions.parseLink(Uri.parse('/set_reference_pitch?hz=441.0'))!.$2,
        {'hz': 441.0},
      );
      expect(
        AppActions.parseLink(Uri.parse('/set_reference_pitch?hz=abc'))!.$2,
        {'hz': 'abc'},
      );
      expect(AppActions.parseLink(Uri.parse('/drone_play?note=F%23'))!.$2, {
        'note': 'F#',
      });
      expect(AppActions.parseLink(Uri.parse('/')), isNull);
      expect(AppActions.parseLink(Uri.parse('lowend://action')), isNull);
    });
  });

  group('in the running app', () {
    Future<AudioScope> pump(WidgetTester tester, {AppSettings? s}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        LowEndApp(toneOutput: output, micInput: mic, settings: s),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return AudioScope.of(tester.element(find.byType(HomeShell)));
    }

    testWidgets('tuner_start from another tab answers "listening"', (
      tester,
    ) async {
      final scope = await pump(tester);
      await scope.actions.call('open_section', {'section': 'drone'});
      await tester.pump();
      expect(scope.tuner.status, TunerStatus.idle);
      late Map<String, Object?> r;
      await tester.runAsync(() async {
        r = await scope.actions.call('tuner_start');
      });
      expect(r['ok'], isTrue);
      expect(
        (_state(r)['tuner']! as Map)['status'],
        'listening',
        reason: 'the answer was taken while the tuner was still starting',
      );
      await tester.pump();
    });

    testWidgets('reference pitch in the settings retunes a playing drone', (
      tester,
    ) async {
      final s = AppSettings();
      final scope = await pump(tester, s: s);
      await scope.drone.tapNote(9);
      s.setReferencePitch(445);
      await tester.pump();
      expect(output.frequencies.single, closeTo(445 / 2, 1e-9));
      expect(scope.drone.a4, 445);
      await scope.drone.stop();
    });

    testWidgets('a launch link runs once and keeps the home page', (
      tester,
    ) async {
      tester.platformDispatcher.defaultRouteNameTestValue =
          '/drone_play?note=D&voicing=chord';
      final scope = await pump(tester);
      await tester.pump();
      expect(scope.drone.isPlaying, isTrue);
      expect(output.frequencies, hasLength(3));
      expect(find.byType(HomeShell), findsOneWidget);
      await scope.drone.stop();
    });

    testWidgets('a bad link while running does nothing and opens no page', (
      tester,
    ) async {
      final scope = await pump(tester);
      await tester.binding.handlePushRoute('/drone_play?note=H');
      await tester.binding.handlePushRoute('/no_such_action');
      await tester.binding.handlePushRoute(
        'lowend://action/settings_set?language=xx',
      );
      await tester.pump();
      expect(scope.drone.isPlaying, isFalse);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(HomeShell))).canPop(),
        isFalse,
      );
    });

    testWidgets('settings kept by the caller do not outlive the app', (
      tester,
    ) async {
      final s = AppSettings();
      await pump(tester, s: s);
      await tester.pumpWidget(const SizedBox());
      // The app is gone; changing the (caller-owned) settings must not
      // touch its disposed drone.
      expect(() => s.setReferencePitch(442), returnsNormally);
      expect(tester.takeException(), isNull);
    });
  });
}
