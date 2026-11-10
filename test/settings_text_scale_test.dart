import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';

/// With the phone's text enlarged, the menu fields of the Settings go under
/// their names and take the whole width, so that their values are not cut;
/// at the normal size they stay beside them.
void main() {
  const tooltips = {
    'en': 'Settings',
    'it': 'Impostazioni',
    'es': 'Ajustes',
    'fr': 'Paramètres',
  };
  const keys = [
    'languageMenu',
    'noteNamesMenu',
    'octaveNumberingMenu',
    'referencePitchMenu',
    'inTuneZoneMenu',
    'circleLayoutMenu',
  ];
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final entry in tooltips.entries) {
      testWidgets('settings at ${scale}x in ${entry.key}', (tester) async {
        // A narrow phone: 360 dp wide.
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.platformDispatcher.localesTestValue = [Locale(entry.key)];
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpWidget(
          LowEndApp(toneOutput: SilentToneOutput(), micInput: FakeMicInput()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(entry.value));
        await tester.pumpAndSettle();
        for (final key in keys) {
          final field = find.byKey(Key(key));
          await tester.scrollUntilVisible(
            field,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          final width = tester.getSize(field).width;
          if (scale > 1.15) {
            expect(width, greaterThan(300), reason: '$key at ${scale}x');
          } else {
            expect(width, lessThan(240), reason: '$key at ${scale}x');
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
