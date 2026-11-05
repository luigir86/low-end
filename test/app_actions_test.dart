import 'dart:io';

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
import 'package:low_end/features/tuner/tuner_tuning.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:low_end/audio/pitch.dart';

import 'dart:math' as math;
import 'dart:typed_data';

/// [samples] of a sine at [hz], at 16 kHz, loud enough to be heard.
Float64List sine(double hz, int samples) => Float64List.fromList([
  for (var i = 0; i < samples; i++)
    0.5 * math.sin(2 * math.pi * hz * i / 16000),
]);

void main() {
  late SilentToneOutput output;
  late FakeMicInput mic;
  late AppSettings settings;
  late AppActions actions;

  setUp(() {
    output = SilentToneOutput();
    mic = FakeMicInput();
    settings = AppSettings();
    actions = AppActions(
      drone: DroneController(output),
      metronome: MetronomeController(SilentClickOutput()),
      tuner: TunerController(mic),
      navigation: AppNavigation(),
      settings: settings,
    );
  });

  test('docs/llm-actions.json matches the action catalog', () {
    // Regenerate with: flutter test --update-goldens
    final file = File('docs/llm-actions.json');
    if (autoUpdateGoldenFiles) file.writeAsStringSync(exportActions());
    // Git on Windows may check the file out with CRLF line endings.
    final text = file.readAsStringSync().replaceAll('\r\n', '\n');
    expect(text, exportActions());
  });

  test('a link cannot change the saved settings, a direct call can', () async {
    for (final (name, args) in [
      ('set_reference_pitch', <String, Object?>{'hz': 442}),
      ('settings_set', <String, Object?>{'language': 'it'}),
    ]) {
      final refused = await actions.call(name, args, true);
      expect(refused['ok'], false, reason: name);
      expect('${refused['error']}', contains('link'));
    }
    expect(settings.a4, 440);
    expect(settings.languageCode, isNull);
    expect(
      (await actions.call('set_reference_pitch', {'hz': 442}))['ok'],
      true,
    );
    expect(settings.a4, 442);
    // The harmless actions still work from a link.
    expect((await actions.call('drone_stop', const {}, true))['ok'], true);
  });

  test('reads note names in English and Italian', () {
    expect(parseNote('A'), (pitchClass: 9, octave: null));
    expect(parseNote('Bb1'), (pitchClass: 10, octave: 1));
    expect(parseNote('f♯'), (pitchClass: 6, octave: null));
    expect(parseNote('Sol2'), (pitchClass: 7, octave: 2));
    expect(parseNote('sib'), (pitchClass: 10, octave: null));
    expect(parseNote('do#3'), (pitchClass: 1, octave: 3));
    expect(parseNote('H'), isNull);
  });

  test('plays and stops the drone with its settings', () async {
    final result = await actions.call('drone_play', {
      'note': 'D',
      'voicing': 'chord',
      'chord': 'minor',
    });
    expect(result['ok'], isTrue);
    final drone = (result['state']! as Map)['drone'] as Map;
    expect(drone['playing'], isTrue);
    expect(drone['note'], 'D3');
    expect(drone['voicing'], 'chord');
    expect(drone['chord'], 'minor');
    expect(output.frequencies, hasLength(3));

    await actions.call('drone_stop');
    expect(output.frequencies, isEmpty);
  });

  test('sets the held tone of Harmony', () async {
    var result = await actions.call('drone_set', {'held_tone': true});
    expect(result['ok'], isTrue);
    expect(((result['state']! as Map)['drone'] as Map)['held_tone'], isTrue);
    expect(actions.drone.continuous, isTrue);
    result = await actions.call('drone_set', {'held_tone': 'maybe'});
    expect(result['ok'], isFalse);
    result = await actions.call('drone_set', {'held_tone': false});
    expect(actions.drone.continuous, isFalse);
  });

  test('the held tone is also the fifth style, as in the menu', () async {
    var result = await actions.call('drone_set', {'style': 'arpeggio'});
    result = await actions.call('drone_set', {'style': 'tone'});
    expect(result['ok'], isTrue);
    var drone = (result['state']! as Map)['drone'] as Map;
    expect(drone['style'], 'tone');
    expect(drone['held_tone'], isTrue);
    // A piano style brings the piano back.
    result = await actions.call('drone_set', {'style': 'walking'});
    drone = (result['state']! as Map)['drone'] as Map;
    expect(drone['style'], 'walking');
    expect(actions.drone.continuous, isFalse);
    // held_tone false goes back to the style last chosen.
    await actions.call('drone_set', {'held_tone': true});
    await actions.call('drone_set', {'held_tone': false});
    expect(actions.drone.style, DroneStyle.walking);
    // The two must agree.
    result = await actions.call('drone_set', {
      'style': 'beat',
      'held_tone': true,
    });
    expect(result['ok'], isFalse);
    expect(actions.drone.style, DroneStyle.walking);
  });

  test('changes and reports the settings', () async {
    await actions.call('set_reference_pitch', {'hz': 415});
    expect(settings.a4, 415);
    await actions.call('set_reference_pitch', {'hz': 432});
    expect(settings.a4, 432);
    await actions.call('set_reference_pitch', {'hz': 438});
    final result = await actions.call('settings_set', {
      'language': 'it',
      'note_names': 'letters',
    });
    expect((result['state']! as Map)['settings'], {
      'reference_pitch_hz': 438.0,
      'language': 'it',
      'note_names': 'letters',
      'transposition': 'c',
      'octave_numbering': 'scientific',
      'tuner_instrument': 'chromatic',
      'in_tune_cents': 5.0,
      'circle_layout': 'fifths',
      'keep_screen_on': true,
      'lock_gestures': false,
    });
    expect(settings.a4, 438);
    await actions.call('settings_set', {'language': 'system'});
    expect(settings.languageCode, isNull);
  });

  test('every setting on the settings page is an action too', () async {
    final result = await actions.call('settings_set', {
      'octave_numbering': 'italian',
      'tuner_instrument': 'violin',
      'in_tune_cents': 2,
      'circle_layout': 'chromatic',
      'keep_screen_on': false,
      'lock_gestures': true,
    });
    expect(result['ok'], true);
    expect(settings.octaveNumbering, OctaveNumbering.italian);
    expect(settings.tuning, TunerTuning.violin);
    expect(settings.inTuneCents, 2);
    expect(settings.circleLayout, CircleLayout.chromatic);
    expect(settings.keepScreenOn, isFalse);
    expect(settings.gesturesLocked, isTrue);
    await actions.call('settings_set', {'tuner_instrument': 'chromatic'});
    expect(settings.tuning, TunerTuning.chromatic);
    // One wrong value and nothing changes.
    final refused = await actions.call('settings_set', {
      'in_tune_cents': 3,
      'circle_layout': 'fifths',
    });
    expect(refused['ok'], false);
    expect(settings.circleLayout, CircleLayout.chromatic);
  });

  test('the tuner state reads the strings of the instrument chosen', () async {
    settings.setTunerInstrument(TunerTuning.bass);
    settings.setTransposition(Transposition.bFlat);
    await actions.call('tuner_start');
    // A low E a little flat: the bass's fourth string.
    mic.add(sine(40.8, 16000 * 2));
    final state = (await actions.call('get_state'))['state']! as Map;
    final reading = (state['tuner'] as Map)['reading'] as Map;
    expect(reading['target'], 'E1');
    // The strings sound as written: no transposition outside the chromatic.
    expect(reading['written'], 'E1');
  });

  test('an example song and the spelling of the key are actions', () async {
    var result = await actions.call('drone_set', {'song': 'Blue Bossa'});
    expect(result['ok'], true);
    expect(actions.drone.voicing, DroneVoicing.progression);
    expect(actions.drone.note.pitchClass, 0);
    expect(actions.metronome.bpm, 126);
    expect(
      (await actions.call('drone_set', {'song': 'Yesterday'}))['ok'],
      false,
    );
    result = await actions.call('drone_set', {'note': 'F#', 'flat': true});
    expect(actions.drone.spelledFlat(6), isTrue);
    expect(((result['state']! as Map)['drone'] as Map)['flat'], true);
    await actions.call('drone_set', {'flat': false});
    expect(actions.drone.spelledFlat(6), isFalse);
  });

  test('the time signature is an action, checked with the tempo', () async {
    var result = await actions.call('metronome_set', {
      'time_signature': '7/8',
      'bpm': 300,
    });
    expect(result['ok'], true);
    expect(actions.metronome.signature.label, '7/8');
    expect(actions.metronome.bpm, 300);
    // 300 is too fast for quarter notes: refused, and nothing changes.
    result = await actions.call('metronome_set', {
      'time_signature': '4/4',
      'bpm': 300,
    });
    expect(result['ok'], false);
    expect(actions.metronome.signature.label, '7/8');
    expect(
      (await actions.call('metronome_set', {'time_signature': '4/3'}))['ok'],
      false,
    );
  });

  test('the song list of the actions is the list on screen', () {
    final action = AppActions.catalog.firstWhere((a) => a.name == 'drone_set');
    expect((action.parameters['song']! as Map)['enum'], [
      for (final s in exampleSongs) s.title,
    ]);
  });

  test('starting the tuner shows it, leaving it turns the mic off', () async {
    await actions.call('open_section', {'section': 'metronome'});
    final result = await actions.call('tuner_start');
    final state = result['state']! as Map;
    expect(state['section'], 'tuner');
    expect((state['tuner'] as Map)['status'], 'listening');
    expect(mic.isCapturing, isTrue);

    await actions.call('tuner_stop');
    expect(mic.isCapturing, isFalse);
  });

  test('explains wrong calls instead of failing', () async {
    expect(await actions.call('fly'), {
      'ok': false,
      'error': 'Unknown action "fly".',
    });
    expect(
      (await actions.call('set_reference_pitch', {'hz': 446}))['error'],
      contains('whole number from 415 to 445'),
    );
    expect(
      (await actions.call('drone_set', {'chord': 'ninth'}))['error'],
      contains('must be one of'),
    );
    expect(
      (await actions.call('drone_set', {'octave': 2}))['error'],
      contains('no parameter'),
    );
  });

  test('turns links into actions with typed arguments', () {
    final (name, args) = AppActions.parseLink(
      Uri.parse('lowend://action/drone_play?note=A&voicing=chord'),
    )!;
    expect(name, 'drone_play');
    expect(args, {'note': 'A', 'voicing': 'chord'});
    expect(
      AppActions.parseLink(
        Uri.parse('lowend://action/set_reference_pitch?hz=442'),
      )?.$2,
      {'hz': 442},
    );
    expect(AppActions.parseLink(Uri.parse('/tuner_stop'))?.$1, 'tuner_stop');
    expect(AppActions.parseLink(Uri.parse('/settings')), isNull);
  });

  testWidgets('a link sent to the running app starts the drone', (
    tester,
  ) async {
    final output = SilentToneOutput();
    await tester.pumpWidget(
      LowEndApp(toneOutput: output, micInput: FakeMicInput()),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePushRoute('/drone_play?note=E');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(output.frequencies.single, closeTo(164.81, 0.1)); // E3
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // It opens the Drone tab, with the key lit.
    expect(find.bySemanticsLabel('Stop E'), findsOneWidget);

    await tester.binding.handlePushRoute('/open_section?section=drone');
    await tester.pump(const Duration(milliseconds: 300));
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    expect(scope.navigation.section, AppSection.drone);
  });
}
