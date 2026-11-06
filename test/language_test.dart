import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/l10n/app_localizations.dart';

/// "Follow the language": with no language chosen, the app speaks the
/// phone's.
void main() {
  Future<void> open(
    WidgetTester tester,
    List<Locale> phone, {
    AppSettings? settings,
  }) async {
    tester.platformDispatcher.localesTestValue = phone;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: settings ?? AppSettings(),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  testWidgets('an Italian phone gets Italian', (tester) async {
    await open(tester, const [Locale('it', 'IT')]);
    expect(l10n(tester).localeName, 'it');
    expect(find.text('Accordatore'), findsOneWidget);
  });

  testWidgets('an Italian phone with English second still gets Italian', (
    tester,
  ) async {
    await open(tester, const [Locale('it', 'IT'), Locale('en', 'GB')]);
    expect(l10n(tester).localeName, 'it');
  });

  testWidgets('an English phone gets English, and any other one too', (
    tester,
  ) async {
    await open(tester, const [Locale('en', 'GB')]);
    expect(l10n(tester).localeName, 'en');
    await open(tester, const [Locale('de', 'DE')]);
    expect(l10n(tester).localeName, 'en');
  });

  testWidgets('a Spanish or French phone gets its language', (tester) async {
    await open(tester, const [Locale('es', 'MX')]);
    expect(l10n(tester).localeName, 'es');
    expect(find.text('Afinador'), findsOneWidget);
    await open(tester, const [Locale('fr', 'CA')]);
    expect(l10n(tester).localeName, 'fr');
    expect(find.text('Accordeur'), findsOneWidget);
  });

  testWidgets('a language chosen in the settings wins over the phone', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final settings = AppSettings()..setLanguage('en');
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        micInput: FakeMicInput(),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    expect(l10n(tester).localeName, 'en');
    settings.setLanguage(null);
    await tester.pumpAndSettle();
    expect(l10n(tester).localeName, 'it');
  });

  testWidgets('"Follow the language" in the settings goes back to the phone', (
    tester,
  ) async {
    final settings = AppSettings();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await open(tester, const [Locale('it', 'IT')], settings: settings);
    await tester.tap(find.byTooltip('Impostazioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('languageMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(settings.languageCode, 'en');
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('languageMenu')));
    await tester.pumpAndSettle();
    // The menu's line, not the field's.
    await tester.tap(find.text('Same as the phone').last);
    await tester.pumpAndSettle();
    expect(settings.languageCode, isNull);
    expect(find.text('Impostazioni'), findsWidgets);
  });

  // On the phone, Android tells the app about the phone's languages only as
  // far as the APK declares them as resources: without values-it the app
  // was told the phone spoke English (the bug this test is named after).
  group('the Android build declares the languages', () {
    final res = Directory('android/app/src/main/res');
    final languages = [
      for (final l in AppLocalizations.supportedLocales) l.languageCode,
    ];

    test('every language has a resource folder', () {
      for (final code in languages) {
        final folder = code == 'en' ? 'values' : 'values-$code';
        expect(
          File('${res.path}/$folder/strings.xml').existsSync(),
          isTrue,
          reason: '$folder/strings.xml',
        );
      }
    });

    test('the locale list lists them, and the manifest points to it', () {
      final config = File('${res.path}/xml/locales_config.xml');
      final text = config.readAsStringSync();
      for (final code in languages) {
        expect(text, contains('android:name="$code"'));
      }
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:localeConfig="@xml/locales_config"'));
      expect(manifest, contains('android:label="@string/app_name"'));
    });

    test('the build keeps both languages', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('localeFilters'));
      for (final code in languages) {
        expect(gradle, contains('"$code"'));
      }
    });
  });
}
