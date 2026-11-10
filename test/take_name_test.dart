// The name a take is shared and saved with (Take1_9_nov_2026), and the
// window that lets the person change it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/recorded_track.dart';
import 'package:low_end/features/player/recording_controls.dart';
import 'package:low_end/features/player/take_name.dart';
import 'package:low_end/l10n/app_localizations.dart';

void main() {
  final day = DateTime(2026, 11, 9, 20, 15);

  test('the name gives the number of the take and the date', () async {
    await initializeDateFormatting();
    String name(String language, int number) =>
        takeName(lookupAppLocalizations(Locale(language)), number, day);
    expect(name('en', 1), 'Take1_9_nov_2026');
    expect(name('it', 2), 'Take2_9_nov_2026');
    expect(name('es', 1), 'Toma1_9_nov_2026');
    expect(name('fr', 3), 'Prise3_9_nov_2026');
    expect(
      takeName(
        lookupAppLocalizations(const Locale('fr')),
        1,
        DateTime(2026, 2, 1),
      ),
      'Prise1_1_févr_2026',
    );
  });

  test('the number starts again from 1 every day', () {
    final settings = AppSettings();
    expect(settings.nextTakeNumber(day), 1);
    expect(settings.nextTakeNumber(day), 2);
    expect(settings.nextTakeNumber(day.add(const Duration(days: 1))), 1);
  });

  test('a name is made safe for a file', () {
    expect(cleanTakeName('  Bass: line 1/2 '), 'Bass_ line 1_2');
    expect(cleanTakeName('..hidden'), 'hidden');
    expect(cleanTakeName('   '), '');
    expect(cleanTakeName('x' * 200).length, maxTakeNameLength);
  });

  testWidgets('sharing offers WhatsApp first when it is on the phone', (
    tester,
  ) async {
    final take = RecordedTrack(uri: 'file:///takes/1.m4a', name: 'take.m4a')
      ..fileName = 'Take1_9_nov_2026';
    TakeExport? answer;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await showDialog<TakeExport>(
              context: context,
              builder: (_) =>
                  TakeNameDialog(take: take, share: true, whatsApp: true),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Other apps'), findsOneWidget);
    expect(find.text('.m4a'), findsOneWidget);
    // An empty name cannot be sent.
    await tester.enterText(find.byKey(TakeNameDialog.nameKey), ' ');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(TakeNameDialog.whatsAppKey))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(TakeNameDialog.nameKey), 'Scales');
    await tester.pump();
    await tester.tap(find.byKey(TakeNameDialog.whatsAppKey));
    await tester.pumpAndSettle();
    expect(answer, (name: 'Scales', whatsApp: true));
  });
}
