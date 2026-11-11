// Share and Save of a take, as the person meets them: the name window,
// Cancel, the phone answering an error, and what reaches Android
// (TakeFiles.kt, tested on its side in android/app/src/test).
// The happy path is in player_panel_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/screen_awake.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/recorded_track.dart';
import 'package:low_end/audio/take_recorder.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/player/recording_controls.dart';
import 'package:low_end/widgets/row_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _takes = MethodChannel('low_end/takes');

/// The app on the Player with a take just recorded, and Android's side of
/// the takes channel answering [answer].
Future<(AudioScope, List<MethodCall>)> _recorded(
  WidgetTester tester,
  Future<Object?> Function(MethodCall call) answer,
) async {
  SharedPreferences.setMockInitialValues({'seen_guide': true});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final calls = <MethodCall>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_takes, (call) {
    calls.add(call);
    return answer(call);
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_takes, null));
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: SilentToneOutput(),
      clickOutput: SilentClickOutput(),
      micInput: FakeMicInput(),
      trackOutput: SilentTrackOutput(),
      trackFiles: FakeTrackFiles(),
      takeRecorder: FakeTakeRecorder(),
      screenAwake: FakeScreenAwake(),
      settings: AppSettings()..rememberSection(AppSection.player),
    ),
  );
  await tester.pumpAndSettle();
  final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
  await tester.tap(find.byTooltip('Record'));
  await _settle(tester);
  await tester.tap(find.byTooltip('Stop'));
  await _settle(tester);
  expect(scope.player.track, isA<RecordedTrack>());
  return (scope, calls);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

RecordedTrack _take(AudioScope scope) => scope.player.track! as RecordedTrack;

void main() {
  testWidgets('Cancel in the name window shares nothing and keeps the name', (
    tester,
  ) async {
    final (scope, calls) = await _recorded(tester, (_) async => true);
    final before = _take(scope).fileName;
    await tester.tap(find.byTooltip('Share'));
    await _settle(tester);
    await tester.enterText(find.byKey(TakeNameDialog.nameKey), 'Other');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.byType(TakeNameDialog), findsNothing);
    expect(calls, isEmpty);
    expect(_take(scope).fileName, before);
    // The buttons work again.
    await tester.tap(find.byTooltip('Share'));
    await _settle(tester);
    expect(find.byType(TakeNameDialog), findsOneWidget);
  });

  testWidgets('a name of only spaces or symbols cannot be confirmed', (
    tester,
  ) async {
    final (_, calls) = await _recorded(tester, (_) async => true);
    await tester.tap(find.byTooltip('Share'));
    await _settle(tester);
    await tester.enterText(find.byKey(TakeNameDialog.nameKey), '   ');
    await tester.pump();
    final confirm = tester.widget<FilledButton>(
      find.byKey(TakeNameDialog.confirmKey),
    );
    expect(confirm.onPressed, isNull);
    await tester.enterText(find.byKey(TakeNameDialog.nameKey), '..');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(TakeNameDialog.confirmKey))
          .onPressed,
      isNull,
    );
    expect(calls, isEmpty);
  });

  testWidgets('Share sends the path of the take and the name with its '
      'extension', (tester) async {
    final (scope, calls) = await _recorded(tester, (_) async => true);
    await tester.tap(find.byTooltip('Share'));
    await _settle(tester);
    await tester.enterText(
      find.byKey(TakeNameDialog.nameKey),
      '  Lezione 3 – Blue Bossa  ',
    );
    await tester.tap(find.byKey(TakeNameDialog.confirmKey));
    await _settle(tester);
    expect(calls.map((call) => call.method), ['share']);
    final arguments = calls.single.arguments as Map;
    expect(arguments['name'], 'Lezione 3 – Blue Bossa.m4a');
    expect(arguments['path'], Uri.parse(_take(scope).uri).toFilePath());
    // No notice: the system's share window is the answer.
    expect(find.text('Audio operation failed. Try again.'), findsNothing);
    // Sharing does not count as saving.
    expect(find.text('Temporary'), findsOneWidget);
  });

  testWidgets('a failure on the phone is said at the top, and Share can be '
      'tried again', (tester) async {
    var fail = true;
    final (_, calls) = await _recorded(tester, (call) async {
      if (fail) {
        throw PlatformException(code: 'share', message: 'copy failed');
      }
      return true;
    });
    await tester.tap(find.byTooltip('Share'));
    await _settle(tester);
    await tester.tap(find.byKey(TakeNameDialog.confirmKey));
    await _settle(tester);
    expect(find.text('Audio operation failed. Try again.'), findsOneWidget);
    // At the top of the screen, away from the controls.
    final notice = tester.getCenter(
      find.text('Audio operation failed. Try again.'),
    );
    expect(notice.dy, lessThan(tester.view.physicalSize.height / 2.625 / 2));
    fail = false;
    await tester.tap(find.byTooltip('Share'));
    await _settle(tester);
    await tester.tap(find.byKey(TakeNameDialog.confirmKey));
    await _settle(tester);
    expect(calls.map((call) => call.method), ['share', 'share']);
  });

  testWidgets('Save cancelled in the system window leaves the take '
      'temporary; saved, it says so and Save is off', (tester) async {
    var saved = false;
    final (scope, calls) = await _recorded(tester, (_) async => saved);
    await tester.tap(find.byTooltip('Save'));
    await _settle(tester);
    await tester.tap(find.byKey(TakeNameDialog.confirmKey));
    await _settle(tester);
    expect(find.text('Temporary'), findsOneWidget);
    expect(_take(scope).saved, isFalse);
    saved = true;
    await tester.tap(find.byTooltip('Save'));
    await _settle(tester);
    await tester.tap(find.byKey(TakeNameDialog.confirmKey));
    await _settle(tester);
    expect(calls.map((call) => call.method), ['save', 'save']);
    expect(find.text('Saved'), findsOneWidget);
    expect(_take(scope).saved, isTrue);
    final save = find.ancestor(
      of: find.byIcon(Icons.save_outlined),
      matching: find.byType(RowButton),
    );
    expect(tester.widget<RowButton>(save).onPressed, isNull);
    // Share still works on a saved take.
    await tester.tap(find.byTooltip('Share'));
    await _settle(tester);
    await tester.tap(find.byKey(TakeNameDialog.confirmKey));
    await _settle(tester);
    expect(calls.last.method, 'share');
  });

  testWidgets('a save that fails on the phone is said, and the take stays '
      'temporary', (tester) async {
    final (scope, _) = await _recorded(
      tester,
      (_) async => throw PlatformException(code: 'save'),
    );
    await tester.tap(find.byTooltip('Save'));
    await _settle(tester);
    await tester.tap(find.byKey(TakeNameDialog.confirmKey));
    await _settle(tester);
    expect(find.text('Audio operation failed. Try again.'), findsOneWidget);
    expect(_take(scope).saved, isFalse);
  });
}
