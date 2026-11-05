import 'dart:io';

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
import 'package:low_end/features/harmony/drone_controller.dart';

Future<ByteData> _font(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

/// Harmony shows the metronome's tempo beside the Mode field and changes it
/// with the metronome's sheet.
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

  Future<AudioScope> open(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('Tempo is exactly as tall as Mode (text x$scale)', (
      tester,
    ) async {
      final scope = await open(tester, scale: scale);
      for (final voicing in [DroneVoicing.progression, DroneVoicing.root]) {
        scope.drone.setVoicing(voicing);
        await tester.pumpAndSettle();
        final mode = tester.getRect(find.byKey(const Key('voicingMenu')));
        final tempo = tester.getRect(find.byKey(const Key('harmonyTempo')));
        expect(tempo.height, mode.height, reason: '$voicing');
        expect(tempo.top, mode.top, reason: '$voicing');
      }
    });
  }

  testWidgets('Tempo shows the metronome\'s and changes it', (tester) async {
    final scope = await open(tester);
    expect(find.text('♩ = 80'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('harmonyTempo'))),
      matchesSemantics(
        label: 'Tempo',
        value: '80 BPM',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    await tester.tap(find.byKey(const Key('harmonyTempo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('120 BPM'));
    await tester.pumpAndSettle();
    expect(scope.metronome.bpm, 120);
    expect(scope.navigation.section, AppSection.drone);
    expect(find.text('♩ = 120'), findsOneWidget);
    // Set on the metronome, it shows here too.
    scope.metronome.setBpm(96);
    await tester.pumpAndSettle();
    expect(find.text('♩ = 96'), findsOneWidget);
  });
}
