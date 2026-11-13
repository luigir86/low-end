import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_panel.dart';
import 'package:low_end/features/metronome/tempo_dial.dart';

Future<ByteData> _font(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

/// Harmony shows the metronome's tempo above its controls and changes it
/// with the same wheel as the metronome, round its dial.
void main() {
  setUpAll(() async {
    // The app's own fonts: the ♩ comes from the music font, taller than the
    // text, which the test font would hide.
    await (FontLoader('Edwin')
          ..addFont(_font('assets/fonts/Edwin-Roman.otf'))
          ..addFont(_font('assets/fonts/Edwin-Bold.otf')))
        .load();
    await (FontLoader(
      'NotoMusic',
    )..addFont(_font('assets/fonts/NotoMusic-Regular.ttf'))).load();
  });

  Future<AudioScope> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        settings: AppSettings(),
      ),
    );
    await tester.pumpAndSettle();
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    scope.navigation.open(AppSection.drone);
    await tester.pumpAndSettle();
    return scope;
  }

  Finder wheel() => find.descendant(
    of: find.byType(DronePanel),
    matching: find.byKey(const Key('metronomeTempoDial')),
  );

  testWidgets('Tempo shows the metronome\'s and the wheel changes it', (
    tester,
  ) async {
    final scope = await open(tester);
    expect(find.text('♩ = 80'), findsOneWidget);
    // No tempo field any more: the wheel is the slider.
    expect(find.bySemanticsLabel('Tempo'), findsNothing);
    final rect = tester.getRect(wheel());
    final g = TempoDialGeometry(rect.size);
    final radius = (g.inner + g.outer) / 2;
    Offset at(double angle) =>
        rect.center + Offset(math.sin(angle), -math.cos(angle)) * radius;
    // A quarter turn clockwise: 30 BPM faster, and no note plays.
    final gesture = await tester.startGesture(at(0));
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(at(math.pi / 2 * i / 12));
      await tester.pump(const Duration(milliseconds: 5));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scope.metronome.bpm, 110);
    expect(scope.drone.isPlaying, isFalse);
    expect(scope.navigation.section, AppSection.drone);
    expect(find.text('♩ = 110'), findsOneWidget);
    // Set on the metronome, it shows here too.
    scope.metronome.setBpm(96);
    await tester.pumpAndSettle();
    expect(find.text('♩ = 96'), findsOneWidget);
  });
}
