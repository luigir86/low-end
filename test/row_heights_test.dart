import 'package:flutter/material.dart';
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
import 'package:low_end/widgets/row_controls.dart';

/// In the row of controls under each dial, the field (the time signature, the
/// chord, the reference A) and the chips beside it (TAP, − +, +7) are the
/// same height, also with large text.
void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('the field and the chips of a row are as tall as each other '
        '(text x$scale)', (tester) async {
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
      scope.drone.setVoicing(DroneVoicing.chord);
      for (final section in AppSection.values) {
        scope.navigation.open(section);
        await tester.pumpAndSettle();
        final heights = {
          for (final finder in [
            find.byType(LabeledField),
            find.byType(RowButton),
            find.byKey(const Key('chordMenu')),
            find.byType(FilterChip),
          ])
            for (final e in finder.hitTestable().evaluate())
              tester.getSize(find.byWidget(e.widget)).height,
        };
        expect(heights, hasLength(1), reason: '$section: $heights');
      }
    });
  }
}
