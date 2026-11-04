import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/metronome/time_signature.dart';
import 'package:low_end/features/tuner/drone/drone_controller.dart';
import 'package:low_end/features/tuner/drone/harmony.dart';

void main() {
  test('counts down the wait for the metronome\'s bar line', () async {
    final piano = SilentPianoOutput();
    final drone = DroneController(SilentToneOutput(), piano: piano);
    drone.setVoicing(DroneVoicing.chord);
    await drone.start();
    // Nothing to wait for: the piano came in at once.
    expect(drone.waitLeft, isNull);
    await drone.stop();
    expect(drone.waitLeft, isNull);

    piano.delay = const Duration(seconds: 2);
    // The wait is only known once the piano is scheduled, after the start
    // was announced: whoever shows it must be told again, for every voicing.
    final heard = <Duration?>[];
    drone.addListener(() => heard.add(drone.waitLeft));
    await drone.start();
    expect(heard.whereType<Duration>(), isNotEmpty);
    final left = drone.waitLeft!;
    expect(left, greaterThan(const Duration(milliseconds: 1500)));
    expect(left, lessThanOrEqualTo(const Duration(seconds: 2)));
    await drone.stop();
    expect(drone.waitLeft, isNull);
  });

  testWidgets('the hub shows the beats to go', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final piano = SilentPianoOutput()..delay = const Duration(seconds: 3);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        pianoOutput: piano,
        micInput: FakeMicInput(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Harmony'),
      ),
    );
    await tester.pumpAndSettle();
    await scope.drone.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('A4'), findsNothing);

    // Stopped, the hub goes back to its hint.
    await scope.drone.stop();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('4'), findsNothing);
  });

  testWidgets('the hub writes a chord out, and the hertz of a note alone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        pianoOutput: SilentPianoOutput()..handOverWait = Duration.zero,
        micInput: FakeMicInput(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Harmony'),
      ),
    );
    await tester.pumpAndSettle();
    scope.drone
      ..setPitchClass(9)
      ..setVoicing(DroneVoicing.chord)
      ..setChord(ChordQuality.major);
    await scope.drone.start();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('A C♯ E'), findsOneWidget);
    // The root's frequency would mislead about a chord.
    expect(find.textContaining('Hz'), findsNothing);

    // A change of voicing waits for the bar line (RF-ARM-15), here at once.
    scope.drone.setVoicing(DroneVoicing.root);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('A C♯ E'), findsNothing);
    expect(find.text('220.0 Hz'), findsOneWidget);
    await scope.drone.stop();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('a progression waits for its first chord to be heard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final piano = _HeldPianoOutput();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        pianoOutput: piano,
        micInput: FakeMicInput(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Harmony'),
      ),
    );
    await tester.pumpAndSettle();
    final drone = scope.drone..setVoicing(DroneVoicing.progression);
    unawaited(drone.start());
    await tester.pump();
    // A moment: nothing to say yet, so a quick start does not flash.
    expect(drone.isStarting, isTrue);
    expect(drone.showsWait, isFalse);
    expect(find.text('Getting the sounds ready…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(drone.showsWait, isTrue);
    expect(find.text('Getting the sounds ready…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Bars go by unheard: the progression stays on its first chord.
    await tester.pump(const Duration(seconds: 6));
    expect(drone.step, 0);
    expect(drone.startsSlowly, isTrue);
    piano.release();
    await tester.pump();
    await tester.pump();
    expect(drone.isStarting, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Getting the sounds ready…'), findsNothing);
    // Heard: from now on it moves on, a chord each bar.
    await tester.pump(const Duration(seconds: 6));
    expect(drone.step, isNot(0));
    await drone.stop();
    await tester.pump(const Duration(milliseconds: 200));
  });
}

/// A piano whose first loop comes out only when [release]d, as over a slow
/// network.
class _HeldPianoOutput extends SilentPianoOutput {
  final _held = Completer<void>();

  void release() => _held.complete();

  @override
  Future<LoopStart> play({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required double a4,
    required double volume,
    Duration? startAt,
    bool onTheBeat = false,
    bool patient = false,
    bool handOver = false,
  }) async {
    await _held.future;
    return super.play(
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
      volume: volume,
      startAt: startAt,
      onTheBeat: onTheBeat,
      patient: patient,
      handOver: handOver,
    );
  }
}
