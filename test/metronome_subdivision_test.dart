import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/actions/app_actions.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/click_sound.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/metronome/subdivision.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/tuner/tuner_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One bar at 60 BPM as samples from -1 to 1.
Float64List _bar({
  TimeSignature signature = TimeSignature.fourFour,
  Subdivision subdivision = Subdivision.quarters,
  bool backbeat = false,
}) {
  final wav = ClickSound.bar(
    bpm: 60,
    signature: signature,
    subdivision: subdivision,
    backbeat: backbeat,
  );
  return Float64List.fromList([
    for (var i = 44; i < wav.length; i += 2)
      ((wav[i] | (wav[i + 1] << 8)).toSigned(16)) / 32767,
  ]);
}

/// The energy of [length] samples of [bar] from [from].
double _energy(Float64List bar, int from, [int length = 2000]) {
  var sum = 0.0;
  for (var i = from; i < from + length; i++) {
    sum += bar[i] * bar[i];
  }
  return sum;
}

const _beat = ClickSound.sampleRate; // A beat at 60 BPM.

void main() {
  group('the click', () {
    test('subdivisions put softer clicks inside each beat', () {
      for (final s in Subdivision.values.skip(1)) {
        final bar = _bar(subdivision: s);
        for (var b = 0; b < 4; b++) {
          for (final fraction in s.inner) {
            final at = b * _beat + (_beat * fraction).round();
            final inside = _energy(bar, at);
            expect(inside, greaterThan(0), reason: '$s beat $b at $fraction');
            // Softer than the beat itself.
            expect(inside, lessThan(_energy(bar, b * _beat)));
          }
        }
      }
      // Without a subdivision, only the beats.
      expect(_energy(_bar(), _beat ~/ 2), 0);
    });

    test('bars counted in eighths play no subdivision', () {
      final plain = _bar(signature: TimeSignature.sixEight);
      final asked = _bar(
        signature: TimeSignature.sixEight,
        subdivision: Subdivision.sixteenths,
      );
      expect(asked, plain);
    });

    test('on 2 and 4, beats 1 and 3 are silent', () {
      final bar = _bar(backbeat: true);
      expect(_energy(bar, 0), 0);
      expect(_energy(bar, _beat), greaterThan(0));
      expect(_energy(bar, 2 * _beat), 0);
      expect(_energy(bar, 3 * _beat), greaterThan(0));
      // What is inside them is silent too: the beats 2 and 4 are subdivided.
      final split = _bar(backbeat: true, subdivision: Subdivision.eighths);
      expect(_energy(split, 0, _beat), 0);
      expect(_energy(split, _beat ~/ 2), 0);
      expect(_energy(split, _beat + _beat ~/ 2), greaterThan(0));
      // In 3/4 there is no backbeat: every beat sounds.
      final waltz = _bar(signature: TimeSignature.threeFour, backbeat: true);
      expect(_energy(waltz, 0), greaterThan(0));
      expect(_energy(waltz, 2 * _beat), greaterThan(0));
    });
  });

  group('the controller', () {
    late SilentClickOutput output;
    late MetronomeController metronome;

    setUp(() {
      output = SilentClickOutput();
      metronome = MetronomeController(output);
    });

    test('changes are heard at once while it plays', () async {
      await metronome.start();
      final before = output.bar;
      metronome.setSubdivision(Subdivision.sixteenths);
      await Future<void>.delayed(Duration.zero);
      expect(output.bar, isNot(before));
      final split = output.bar;
      metronome.setBackbeat(true);
      await Future<void>.delayed(Duration.zero);
      expect(output.bar, isNot(split));
      await metronome.stop();
    });

    test('says which beats are silent, only in 2/4 and 4/4', () {
      metronome.setBackbeat(true);
      expect(
        [for (var b = 0; b < 4; b++) metronome.isSilent(b)],
        [true, false, true, false],
      );
      metronome.setSignature(TimeSignature.threeFour);
      expect(metronome.backbeatApplies, isFalse);
      expect(metronome.isSilent(0), isFalse);
      metronome.setSignature(TimeSignature.twoFour);
      expect(metronome.isSilent(0), isTrue);
      expect(metronome.isSilent(1), isFalse);
    });
  });

  test('subdivision and the click on 2 and 4 are saved', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await AppSettings.load();
    first.rememberMetronome(
      bpm: 100,
      signature: TimeSignature.fourFour,
      subdivision: Subdivision.triplets,
      backbeat: true,
    );
    await Future<void>.delayed(Duration.zero);
    final second = await AppSettings.load();
    expect(second.metronomeSubdivision, Subdivision.triplets);
    expect(second.metronomeBackbeat, isTrue);
    SharedPreferences.setMockInitialValues({
      'metronome_subdivision': 'quintuplets',
      'metronome_backbeat': 'yes',
    });
    final odd = await AppSettings.load();
    expect(odd.metronomeSubdivision, Subdivision.quarters);
    expect(odd.metronomeBackbeat, isFalse);
  });

  test('an assistant sets the subdivision and the click on 2 and 4', () async {
    final metronome = MetronomeController(SilentClickOutput());
    final actions = AppActions(
      drone: DroneController(SilentToneOutput()),
      metronome: metronome,
      tuner: TunerController(FakeMicInput()),
      navigation: AppNavigation(),
      settings: AppSettings(),
    );
    var result = await actions.call('metronome_set', {
      'subdivision': 'sixteenths',
      'backbeat': true,
    });
    expect(result['ok'], isTrue);
    expect(metronome.subdivision, Subdivision.sixteenths);
    expect(metronome.backbeat, isTrue);
    final state = (result['state']! as Map)['metronome'] as Map;
    expect(state['subdivision'], 'sixteenths');
    expect(state['backbeat'], isTrue);
    result = await actions.call('metronome_set', {
      'subdivision': 'swing_eighths',
    });
    expect(metronome.subdivision, Subdivision.swungEighths);
    expect(
      ((result['state']! as Map)['metronome'] as Map)['subdivision'],
      'swing_eighths',
    );
    // The old name of the swing is gone.
    result = await actions.call('metronome_set', {'subdivision': 'swing'});
    expect(result['ok'], isFalse);
    expect(metronome.subdivision, Subdivision.swungEighths);
    // Wrong values change nothing.
    result = await actions.call('metronome_set', {
      'bpm': 100,
      'subdivision': 'quintuplets',
    });
    expect(result['ok'], isFalse);
    expect(metronome.bpm, 80);
    expect((await actions.call('metronome_set'))['ok'], isFalse);
  });

  group('on screen', () {
    Future<MetronomeController> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final settings = AppSettings()..rememberSection(AppSection.metronome);
      await tester.pumpWidget(
        LowEndApp(
          toneOutput: SilentToneOutput(),
          clickOutput: SilentClickOutput(),
          micInput: FakeMicInput(),
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();
      return AudioScope.of(tester.element(find.byType(HomeShell))).metronome;
    }

    testWidgets(
      'the field beside the time signature picks what fills the beat',
      (tester) async {
        final metronome = await pump(tester);
        await tester.tap(find.byKey(const Key('subdivisionMenu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Triplets'));
        await tester.pumpAndSettle();
        expect(metronome.subdivision, Subdivision.triplets);
        await tester.tap(find.byKey(const Key('subdivisionMenu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Swung eighth notes'));
        await tester.pumpAndSettle();
        expect(metronome.subdivision, Subdivision.swungEighths);
        // Off in the bars counted in eighths.
        metronome.setSignature(TimeSignature.sixEight);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('subdivisionMenu')));
        await tester.pumpAndSettle();
        expect(find.text('Triplets'), findsNothing);
      },
    );

    testWidgets('the click on 2 and 4 is in the time signature list', (
      tester,
    ) async {
      final metronome = await pump(tester);
      await tester.tap(find.text('4/4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backbeatSwitch')));
      await tester.pumpAndSettle();
      expect(metronome.backbeat, isTrue);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('4/4 · 2 & 4'), findsOneWidget);
    });

    testWidgets('holding + runs the tempo up, faster and faster', (
      tester,
    ) async {
      final metronome = await pump(tester);
      final plus = find.widgetWithIcon(OutlinedButton, Icons.add);
      final gesture = await tester.startGesture(tester.getCenter(plus));
      // Not yet a hold: nothing moves.
      await tester.pump(const Duration(milliseconds: 300));
      expect(metronome.bpm, 80);
      // Then one at once, and more and more often.
      await tester.pump(const Duration(milliseconds: 200));
      final early = metronome.bpm;
      expect(early, greaterThan(80));
      await tester.pump(const Duration(milliseconds: 600));
      final inFirst = metronome.bpm - early;
      await tester.pump(const Duration(milliseconds: 600));
      final inSecond = metronome.bpm - early - inFirst;
      expect(inSecond, greaterThan(inFirst));
      // No tooltip comes up.
      expect(find.text('Faster'), findsNothing);
      // After a couple of seconds, steps of 5, on round numbers.
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 140));
      final before = metronome.bpm;
      expect(before % 5, 0);
      await tester.pump(const Duration(milliseconds: 140));
      expect(metronome.bpm - before, 5);
      final held = metronome.bpm;
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      // Letting go stops it, and does not add a tap.
      expect(metronome.bpm, held);
      // A tap still moves by one.
      await tester.tap(plus);
      await tester.pump();
      expect(metronome.bpm, held + 1);
    });
  });
}
