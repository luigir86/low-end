// Stopped, the ring keeps the note a touch on the hub will play outlined
// (RF-ARM-19): selected for the screen reader, its name in bold. While
// Harmony plays, the lit note says it instead.
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

import 'dart:ui' show Tristate;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DroneController> _launch(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'seen_guide': true,
    'seen_swipe_hint': true,
  });
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: SilentToneOutput(),
      micInput: FakeMicInput(),
      settings: AppSettings()..rememberSection(AppSection.drone),
    ),
  );
  await tester.pumpAndSettle();
  return AudioScope.of(tester.element(find.byType(HomeShell))).drone;
}

/// The notes of the ring the screen reader hears as selected.
List<String> _selected(WidgetTester tester) => [
  for (final n in find.bySemanticsLabel(RegExp(r'^(Play|Stop) ')).evaluate())
    if (tester
            .getSemantics(find.byElementPredicate((e) => e == n))
            .flagsCollection
            .isSelected ==
        Tristate.isTrue)
      tester.getSemantics(find.byElementPredicate((e) => e == n)).label,
];

FontWeight? _weight(WidgetTester tester, String name) =>
    tester.widget<Text>(find.text(name).first).style?.fontWeight;

void main() {
  testWidgets('stopped, the chord chosen is outlined on its root', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final drone = await _launch(tester);
    drone
      ..setVoicing(DroneVoicing.chord)
      ..setChord(ChordQuality.dominant)
      ..setPitchClass(7);
    await tester.pump();
    expect(drone.isPlaying, isFalse);
    expect(_selected(tester), ['Play G']);
    expect(_weight(tester, 'G'), FontWeight.w700);
    expect(_weight(tester, 'D'), FontWeight.w400);
    handle.dispose();
  });

  testWidgets('stopped in a progression, the tonic is outlined', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final drone = await _launch(tester);
    drone
      ..setProgression(Progression.twoFiveOne)
      ..setVoicing(DroneVoicing.progression)
      ..setPitchClass(0);
    await tester.pump();
    expect(_selected(tester), ['Play C']);
    handle.dispose();
  });

  testWidgets('playing, only the note heard is selected', (tester) async {
    final handle = tester.ensureSemantics();
    final drone = await _launch(tester);
    drone
      ..setVoicing(DroneVoicing.root)
      ..setPitchClass(9);
    await tester.runAsync(drone.start);
    await tester.pump();
    expect(_selected(tester), ['Stop A']);
    await tester.runAsync(drone.stop);
    await tester.pump(const Duration(seconds: 2));
    expect(_selected(tester), ['Play A']);
    handle.dispose();
  });
}
