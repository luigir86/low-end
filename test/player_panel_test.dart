// The Player's screen (RF-PLY-02, RF-PLY-03, RF-PLY-07, RF-PLY-16): the
// middle, the ring, the field and the messages, in the whole app with silent
// outputs.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/screen_awake.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/app/theme.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/take_recorder.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/player/clock_text.dart';
import 'package:low_end/features/player/passage_strip.dart';
import 'package:low_end/features/player/player_controller.dart';
import 'package:low_end/features/player/player_dial.dart';
import 'package:low_end/features/player/player_panel.dart';
import 'package:low_end/features/player/recording_controls.dart';
import 'package:low_end/features/player/ring_wave.dart';
import 'package:low_end/features/player/ring_window.dart';
import 'package:low_end/features/player/time_scale.dart';
import 'package:low_end/widgets/dial.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _song = TrackRef(uri: 'content://song', name: 'Blue Bossa.mp3');

class _Screen {
  _Screen(this.tester, this.scope, this.output, this.files);

  final WidgetTester tester;
  final AudioScope scope;
  final SilentTrackOutput output;
  final FakeTrackFiles files;

  PlayerController get player => scope.player;

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
}

Future<_Screen> _open(
  WidgetTester tester, {
  FakeTrackFiles? files,
  FakeTakeRecorder? recorder,
  Size size = const Size(1080, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final output = SilentTrackOutput();
  final chooser = files ?? FakeTrackFiles(next: _song);
  await tester.pumpWidget(
    LowEndApp(
      toneOutput: SilentToneOutput(),
      clickOutput: SilentClickOutput(),
      micInput: FakeMicInput(),
      trackOutput: output,
      trackFiles: chooser,
      takeRecorder: recorder,
      screenAwake: FakeScreenAwake(),
      settings: AppSettings()..rememberSection(AppSection.player),
    ),
  );
  await tester.pumpAndSettle();
  final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
  return _Screen(tester, scope, output, chooser);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'seen_guide': true}));

  final hub = find.byKey(const Key('playerHub'));

  testWidgets(
    'the three rows support discard, review, export and removal of takes',
    (tester) async {
      final screen = await _open(tester);
      final messenger = tester.binding.defaultBinaryMessenger;
      const takes = MethodChannel('low_end/takes');
      final exports = <String>[];
      final names = <Object?>[];
      messenger.setMockMethodCallHandler(takes, (call) async {
        exports.add(call.method);
        if (call.arguments is Map) names.add((call.arguments as Map)['name']);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(takes, null));
      await screen.player.open(_song);
      const at = Duration(seconds: 43);
      await screen.player.seek(at);
      await screen.settle();
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      await tester.tap(find.byTooltip('Record'));
      await screen.settle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(DialLayout.rowKeys.last), findsOneWidget);
      await tester.tap(find.byTooltip('Discard'));
      await screen.settle();
      expect(screen.player.track, same(_song));
      expect(screen.player.position, at);
      await tester.tap(find.byTooltip('Record'));
      await screen.settle();
      await tester.tap(find.byTooltip('Stop'));
      await screen.settle();
      expect(screen.player.status, PlayerStatus.ready);
      expect(screen.player.isPlaying, isFalse);
      expect(screen.player.looping, isFalse);
      expect(screen.player.position, Duration.zero);
      // The track being studied stays the one remembered (RF-PLY-20).
      expect(screen.player.setup?.track, _song);
      await tester.tap(find.byTooltip('Share'));
      await screen.settle();
      // The take is named after its number that day and the date, and
      // the name can be changed before it goes.
      final field = tester.widget<TextField>(
        find.byKey(TakeNameDialog.nameKey),
      );
      expect(
        field.controller!.text,
        matches(RegExp(r'^Take1_\d+_[a-z]+_\d{4}$')),
      );
      expect(find.text('.m4a'), findsOneWidget);
      await tester.enterText(find.byKey(TakeNameDialog.nameKey), 'Bass: line');
      await tester.tap(find.byKey(TakeNameDialog.confirmKey));
      await screen.settle();
      expect(exports, ['share']);
      expect(names, ['Bass_ line.m4a']);
      expect(screen.player.title, 'Bass_ line');
      // REC stays in its place, next to the take's own buttons.
      expect(find.byTooltip('Record'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      // The X in the track field discards the take.
      expect(find.byTooltip('Discard'), findsOneWidget);
      // The field gives the length of the take.
      expect(
        find.descendant(
          of: find.byKey(PlayerPanel.trackFieldKey),
          matching: find.text(clockText(screen.player.duration)),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(PlayerPanel.trackFieldKey));
      await screen.settle();
      await tester.tap(find.text('Keep'));
      await screen.settle();
      expect(find.text('Temporary'), findsOneWidget);
      await tester.tap(find.byTooltip('Save'));
      await screen.settle();
      // The name given for sharing is offered again.
      expect(find.text('Bass_ line'), findsOneWidget);
      await tester.tap(find.byKey(TakeNameDialog.confirmKey));
      await screen.settle();
      expect(exports, ['share', 'save']);
      expect(names, ['Bass_ line.m4a', 'Bass_ line.m4a']);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byTooltip('Record'), findsOneWidget);
      final take = screen.player.track;
      await tester.tap(find.byTooltip('Discard'));
      await screen.settle();
      // The track studied before the take comes back; a saved take needs
      // no Undo.
      expect(screen.player.track, _song);
      expect(screen.files.released, contains(take));
      expect(screen.files.released, isNot(contains(_song)));
      expect(find.byKey(DiscardedRow.undoKey), findsNothing);
      // A second X empties the Player, and the file is no longer
      // remembered.
      await tester.tap(find.byTooltip('Discard'));
      await screen.settle();
      expect(screen.player.track, isNull);
      expect(screen.player.setup, isNull);
      expect(find.byTooltip('Discard'), findsNothing);
      expect(find.text('Choose a track'), findsWidgets);
    },
  );

  testWidgets(
    'discard during a microphone prompt cannot start a late recording',
    (tester) async {
      final permission = Completer<bool>();
      final recorder = FakeTakeRecorder()..prompt = permission.future;
      final screen = await _open(tester, recorder: recorder);
      await screen.player.open(_song);
      await screen.settle();
      await tester.tap(find.byTooltip('Record'));
      await screen.settle();
      await tester.tap(find.byTooltip('Discard'));
      permission.complete(true);
      await screen.settle();
      expect(recorder.starts, 0);
      expect(screen.player.track, same(_song));
      expect(find.byTooltip('Record'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    },
  );

  testWidgets('an unsaved take discarded can be brought back in its own '
      'row, and REC over it asks first', (tester) async {
    final screen = await _open(tester);
    await screen.player.open(_song);
    await screen.settle();
    await tester.tap(find.byTooltip('Record'));
    await screen.settle();
    await tester.tap(find.byTooltip('Stop'));
    await screen.settle();
    final take = screen.player.track;
    // REC on a take not saved would replace it: it asks.
    await tester.tap(find.byTooltip('Record'));
    await screen.settle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await screen.settle();
    expect(screen.player.track, same(take));
    await tester.tap(find.byTooltip('Discard'));
    await screen.settle();
    expect(screen.player.track, _song);
    // Said in the track row, not in a notice over the controls.
    expect(find.byKey(const Key('notice')), findsNothing);
    expect(find.text('Recording discarded'), findsOneWidget);
    // The file stays while Undo can still bring the take back.
    expect(screen.files.released, isNot(contains(take)));
    await tester.tap(find.byKey(DiscardedRow.undoKey));
    await screen.settle();
    expect(screen.player.track, same(take));
    expect(find.text('Recording discarded'), findsNothing);
    expect(screen.files.released, isNot(contains(take)));
    // Discarded again and left alone: the row comes back by itself, and
    // only then is the file let go.
    await tester.tap(find.byTooltip('Discard'));
    await screen.settle();
    expect(find.text('Recording discarded'), findsOneWidget);
    await tester.pump(PlayerController.undoTime);
    await screen.settle();
    expect(find.text('Recording discarded'), findsNothing);
    expect(screen.files.released, contains(take));
    expect(screen.player.track, _song);
    expect(find.byKey(PlayerPanel.trackFieldKey), findsOneWidget);
  });

  testWidgets('the X empties the Player of a file', (tester) async {
    final screen = await _open(tester);
    expect(find.byTooltip('Discard'), findsNothing);
    await screen.player.open(_song);
    screen.player.setSpeed(70);
    await screen.player.start();
    await screen.settle();
    await tester.tap(find.byTooltip('Discard'));
    await screen.settle();
    expect(screen.player.track, isNull);
    expect(screen.player.isPlaying, isFalse);
    expect(screen.player.setup, isNull);
    expect(screen.files.released, contains(_song));
    expect(find.byKey(DiscardedRow.undoKey), findsNothing);
    expect(find.byTooltip('Discard'), findsNothing);
  });

  testWidgets('with no track the middle asks for one, and a touch opens the '
      'chooser', (tester) async {
    final screen = await _open(tester);
    expect(find.text('Choose a track'), findsWidgets);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.bySemanticsLabel('Choose a track'), findsWidgets);

    await tester.tap(hub);
    await screen.settle();
    expect(screen.files.picks, 1);
    expect(screen.player.status, PlayerStatus.ready);
    // The track opens but does not play by itself.
    expect(screen.player.isPlaying, isFalse);
    expect(
      find.descendant(of: hub, matching: find.byIcon(Icons.play_arrow)),
      findsNothing,
    );
    expect(find.text('/ 6:00'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('the middle shows title and artist only when the file has tags, '
      'and the duration below the clock (RF-PLY-02, RF-PLY-19)', (
    tester,
  ) async {
    final files = FakeTrackFiles(next: _song)
      ..tagsAnswer = (title: 'Blue Bossa', artist: 'Kenny Dorham');
    final screen = await _open(tester, files: files);
    await screen.player.pick();
    await screen.settle();
    expect(find.text('Blue Bossa · Kenny Dorham'), findsOneWidget);
    expect(find.text('/ 6:00'), findsOneWidget);
    await tester.tap(hub);
    await screen.settle();
    expect(find.text('Tap to start'), findsNothing);
    expect(find.text('Blue Bossa · Kenny Dorham'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without tags the middle shows no title', (tester) async {
    final screen = await _open(tester);
    await screen.player.pick();
    await screen.settle();
    expect(screen.player.hasTags, isFalse);
    expect(
      find.descendant(of: hub, matching: find.text('Blue Bossa')),
      findsNothing,
    );
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('the field names the track and opens the chooser again', (
    tester,
  ) async {
    final screen = await _open(tester);
    expect(
      find.descendant(
        of: find.byKey(PlayerPanel.trackFieldKey),
        matching: find.text('Choose a track'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(PlayerPanel.trackFieldKey));
    await screen.settle();
    expect(screen.files.picks, 1);
    expect(
      find.descendant(
        of: find.byKey(PlayerPanel.trackFieldKey),
        matching: find.text('Blue Bossa'),
      ),
      findsOneWidget,
    );
    screen.files.next = const TrackRef(uri: 'content://b', name: 'Other.wav');
    await tester.tap(find.byKey(PlayerPanel.trackFieldKey));
    await screen.settle();
    expect(screen.player.title, 'Other');
  });

  testWidgets('the middle plays and pauses, and shows the clock', (
    tester,
  ) async {
    final screen = await _open(tester);
    await screen.player.open(_song);
    await screen.settle();

    await tester.tap(hub);
    await screen.settle();
    expect(screen.player.isPlaying, isTrue);
    expect(screen.output.playing, isTrue);
    expect(
      find.descendant(of: hub, matching: find.byIcon(Icons.pause)),
      findsNothing,
    );
    expect(find.text('Tap to start'), findsNothing);
    expect(find.bySemanticsLabel('Pause'), findsWidgets);

    screen.output.advance(const Duration(seconds: 72));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1:12'), findsOneWidget);

    await tester.tap(hub);
    await screen.settle();
    expect(screen.player.isPlaying, isFalse);
    expect(
      find.descendant(of: hub, matching: find.byIcon(Icons.play_arrow)),
      findsNothing,
    );
    expect(find.text('/ 6:00'), findsOneWidget);
    // The position stays.
    expect(find.text('1:12'), findsOneWidget);
  });

  testWidgets('a touch on the ring moves the listening point', (tester) async {
    final screen = await _open(tester);
    await screen.player.open(_song);
    await screen.settle();

    final dial = tester.getRect(find.byKey(DialLayout.dialKey));
    // 3 o'clock, on the ring: a quarter of six minutes.
    await tester.tapAt(dial.center + Offset(dial.width * 0.4, 0));
    await screen.settle();
    expect(screen.player.position, const Duration(seconds: 90));
    // 6 o'clock: half.
    await tester.tapAt(dial.center + Offset(0, dial.height * 0.4));
    await screen.settle();
    expect(screen.player.position, const Duration(minutes: 3));
    // The middle is the button's: it does not seek.
    await tester.tapAt(dial.center + Offset(dial.width * 0.1, 0));
    await screen.settle();
    expect(screen.player.position, const Duration(minutes: 3));
    expect(screen.player.isPlaying, isTrue);
  });

  testWidgets('a touch on the ring with no track does nothing', (tester) async {
    final screen = await _open(tester);
    final dial = tester.getRect(find.byKey(DialLayout.dialKey));
    await tester.tapAt(dial.center + Offset(dial.width * 0.4, 0));
    await screen.settle();
    expect(screen.files.picks, 0);
    expect(screen.player.status, PlayerStatus.empty);
  });

  testWidgets('a file that cannot be opened is said, and the Player is empty', (
    tester,
  ) async {
    final screen = await _open(tester);
    screen.output.failWith = TrackOpenException(TrackProblem.unreadable);
    await tester.tap(hub);
    await screen.settle();
    expect(find.text("This file can't be opened."), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);

    screen.output.failWith = TrackOpenException(TrackProblem.missing);
    await tester.tap(hub);
    await screen.settle();
    expect(find.text('The file is no longer available.'), findsOneWidget);

    // A good one clears the message.
    await tester.tap(hub);
    await screen.settle();
    expect(find.text('The file is no longer available.'), findsNothing);
  });

  testWidgets('the ring is a slider for screen readers, in steps of ten '
      'seconds, and does not announce the time by itself', (tester) async {
    final handle = tester.ensureSemantics();
    final screen = await _open(tester);
    await screen.player.open(_song);
    await screen.settle();
    await screen.player.seek(const Duration(seconds: 72));
    await screen.settle();

    final slider = find.bySemanticsLabel('Track');
    expect(
      tester.getSemantics(slider.first),
      matchesSemantics(
        label: 'Track',
        value: '1:12 of 6:00',
        increasedValue: '1:22 of 6:00',
        decreasedValue: '1:02 of 6:00',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isSlider: true,
        hasTapAction: false,
      ),
    );
    tester.semantics.increase(
      find.semantics.byAction(SemanticsAction.increase),
    );
    await screen.settle();
    expect(screen.player.position, const Duration(seconds: 82));
    tester.semantics.decrease(
      find.semantics.byAction(SemanticsAction.increase),
    );
    tester.semantics.decrease(
      find.semantics.byAction(SemanticsAction.increase),
    );
    await screen.settle();
    expect(screen.player.position, const Duration(seconds: 62));

    // Playing, the value is not rewritten every second.
    await screen.player.start();
    await screen.settle();
    final before = tester.getSemantics(slider.first).value;
    screen.output.advance(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getSemantics(slider.first).value, before);
    handle.dispose();
  });

  testWidgets('it fits a narrow phone with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final screen = await _open(tester, size: const Size(840, 1600));
    await screen.player.open(_song);
    await screen.settle();
    expect(tester.takeException(), isNull);
  });

  group('the wave in the ring (RF-PLY-03, RF-PLY-15)', () {
    Finder waves() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter.runtimeType.toString() == 'RingWave',
    );

    testWidgets('appears as the file is read, and a track with none still '
        'plays', (tester) async {
      final screen = await _open(tester);
      expect(waves(), findsNothing);
      await screen.player.open(_song);
      await screen.settle();
      // Ready, nothing read yet: the layer is there, still clear.
      expect(waves(), findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(
                of: waves(),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        0,
      );

      final stream = screen.files.peakStreams.last;
      stream.add(Uint16List.fromList([for (var i = 0; i < 3000; i++) i * 10]));
      await tester.pump();
      await screen.settle();
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.ancestor(
                of: waves(),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        1,
      );
      stream.add(
        Uint16List.fromList([for (var i = 0; i < 3000; i++) 30000 - i * 10]),
      );
      await stream.close();
      await screen.settle();
      expect(screen.player.peaks!.complete, isTrue);

      // Another track: a new wave, from nothing.
      screen.files.next = const TrackRef(uri: 'content://b', name: 'Other.wav');
      await screen.player.pick();
      await screen.settle();
      expect(screen.player.peaks!.length, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a track whose wave cannot be read plays all the same', (
      tester,
    ) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      screen.files.peakStreams.last.addError(StateError('no wave'));
      await screen.settle();
      await tester.tap(find.byKey(const Key('playerHub')));
      await screen.settle();
      expect(screen.player.isPlaying, isTrue);
      expect(find.text('0:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the playhead is a line across the ring, only for a track', (
      tester,
    ) async {
      final screen = await _open(tester);
      bool playhead() => tester.any(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_PlayheadPainter',
        ),
      );
      expect(playhead(), isFalse);
      await screen.player.open(_song);
      await screen.settle();
      expect(playhead(), isTrue);
    });
  });

  group('the flags and the passage (RF-PLY-08 to RF-PLY-12, RF-PLY-18)', () {
    const a = Duration(minutes: 1), b = Duration(minutes: 2);
    final whole = RingWindow.whole(const Duration(minutes: 6));

    bool enabled(WidgetTester tester, Key key) =>
        tester
            .widget<ButtonStyleButton>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            )
            .onPressed !=
        null;

    Rect dialRect(WidgetTester tester) =>
        tester.getRect(find.byKey(DialLayout.dialKey));

    Offset ring(WidgetTester tester, double dx, double dy) {
      final dial = dialRect(tester);
      return dial.center + Offset(dial.width * dx, dial.height * dy);
    }

    Future<_Screen> track(WidgetTester tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      return screen;
    }

    testWidgets('with no track the controls are off', (tester) async {
      final screen = await _open(tester);
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isFalse);
      expect(find.byKey(PlayerPanel.messageKey), findsNothing);
      await tester.tap(find.byKey(PlayerPanel.speedFieldKey));
      await screen.settle();
      expect(find.text('85%'), findsNothing);
    });

    testWidgets('two taps capture a passage; the dial and button stay put', (
      tester,
    ) async {
      final screen = await track(tester);
      final dial = dialRect(tester);
      final button = find.byKey(PlayerPanel.loopSwitchKey);
      final center = tester.getCenter(button);
      expect(find.byKey(PassageStrip.stripKey), findsOneWidget);
      // Always in its place, off until a flag is set.
      expect(enabled(tester, PlayerPanel.newPassageKey), isFalse);
      await screen.player.seek(a);
      await tester.tap(find.text('Mark start'));
      await screen.settle();
      expect(screen.player.loopStart, a);
      await screen.player.seek(b);
      await tester.tap(find.text('Mark end'));
      await screen.settle();
      expect(screen.player.loopEnd, b);
      await tester.tap(find.text('Loop active'));
      await screen.settle();
      expect(screen.player.looping, isFalse);
      expect(screen.player.loopStart, a);
      await tester.tap(find.text('Resume loop'));
      await screen.settle();
      expect(screen.player.looping, isTrue);
      expect(dialRect(tester), dial);
      expect(tester.getCenter(button), center);
      await tester.tap(find.byTooltip('New passage'));
      await screen.settle();
      expect(screen.player.loopStart, isNull);
      expect(screen.player.loopEnd, isNull);
      expect(find.text('Mark start'), findsOneWidget);
    });

    testWidgets('dragging a pole of the strip moves that flag, without '
        'changing section', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      final strip = tester.getRect(find.byKey(PassageStrip.stripKey));
      // The window is the passage with a quarter of its length each side:
      // A at a fifth of the way and B at four fifths of the inner width.
      final inner = strip.width - 2 * PassageStrip.margin;
      final startX =
          strip.left +
          PassageStrip.margin +
          inner *
              RingWindow.passage(
                a,
                b,
                const Duration(minutes: 6),
              ).fractionOf(a);
      final from = Offset(startX, strip.center.dy);
      final gesture = await tester.startGesture(from);
      await tester.pump();
      for (var i = 1; i <= 6; i++) {
        await gesture.moveTo(from + Offset(i * 8.0, 0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await screen.settle();
      expect(screen.scope.navigation.section, AppSection.player);
      expect(screen.player.loopStart! > a, isTrue);
      expect(screen.player.loopEnd, b);
      expect(screen.player.activeEdge, LoopEdge.start);
    });

    testWidgets('a pole held against the end of the strip widens it and '
        'goes past the passage', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      final strip = tester.getRect(find.byKey(PassageStrip.stripKey));
      final window = RingWindow.passage(a, b, const Duration(minutes: 6));
      final inner = strip.width - 2 * PassageStrip.margin;
      final from = Offset(
        strip.left + PassageStrip.margin + inner * window.fractionOf(b),
        strip.center.dy,
      );
      final gesture = await tester.startGesture(from);
      await tester.pump();
      final edge = Offset(strip.right - 4, strip.center.dy);
      for (var i = 1; i <= 8; i++) {
        await gesture.moveTo(Offset.lerp(from, edge, i / 8)!);
        await tester.pump(const Duration(milliseconds: 20));
      }
      // Held there for a second: the strip and B go on to the right.
      for (var i = 0; i < 60; i++) {
        await tester.pump(PassageStrip.pushTick);
      }
      await gesture.up();
      await screen.settle();
      expect(screen.scope.navigation.section, AppSection.player);
      expect(screen.player.loopEnd! > window.to, isTrue);
      expect(screen.player.loopStart, a);
    });

    testWidgets('A and B are grips on the ring: dragged round, the flag '
        'follows, past the strip', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      final dial = dialRect(tester);
      final geometry = PlayerDialGeometry(dial.size);
      Offset at(Duration time) {
        final angle = whole.angleOf(time);
        return dial.topLeft +
            geometry.center +
            Offset(math.sin(angle), -math.cos(angle)) *
                (geometry.ringOuter - gripRadius(geometry));
      }

      final gesture = await tester.startGesture(at(b));
      await tester.pump();
      const target = Duration(minutes: 3);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(
          at(b + Duration(microseconds: (target - b).inMicroseconds * i ~/ 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await screen.settle();
      expect(screen.scope.navigation.section, AppSection.player);
      expect(screen.player.loopStart, a);
      expect(
        (screen.player.loopEnd! - target).inMilliseconds.abs(),
        lessThan(1500),
      );
      // A touch on a grip makes it the flag the strip moves.
      await tester.tapAt(at(a));
      await screen.settle();
      expect(screen.player.activeEdge, LoopEdge.start);
      expect(screen.player.loopStart, a);
    });

    testWidgets('the passage button is filled like TAP and names its point', (
      tester,
    ) async {
      final screen = await track(tester);
      final button = find.byKey(PlayerPanel.loopSwitchKey);
      expect(
        find.descendant(of: button, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
      LetterBadge flag() => tester.widget<LetterBadge>(
        find.descendant(of: button, matching: find.byType(LetterBadge)),
      );
      expect(flag().letter, 'A');
      await tester.tap(find.text('Mark start'));
      await screen.settle();
      expect(flag().letter, 'B');
    });

    testWidgets('a touch on a pole makes that flag the active one', (
      tester,
    ) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      expect(screen.player.activeEdge, LoopEdge.end);
      final strip = tester.getRect(find.byKey(PassageStrip.stripKey));
      final inner = strip.width - 2 * PassageStrip.margin;
      await tester.tapAt(
        Offset(
          strip.left +
              PassageStrip.margin +
              inner *
                  RingWindow.passage(
                    a,
                    b,
                    const Duration(minutes: 6),
                  ).fractionOf(a),
          strip.center.dy,
        ),
      );
      await screen.settle();
      expect(screen.player.activeEdge, LoopEdge.start);
      expect(screen.player.loopStart, a);
    });

    testWidgets('a touch elsewhere on the strip moves the listening point, '
        'and outside the passage turns the loop off', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      final strip = tester.getRect(find.byKey(PassageStrip.stripKey));
      final inner = strip.width - 2 * PassageStrip.margin;
      await tester.tapAt(
        Offset(strip.left + PassageStrip.margin + inner * 0.5, strip.center.dy),
      );
      await screen.settle();
      expect(screen.player.position.inMilliseconds, closeTo(90000, 2000));
      expect(screen.player.looping, isTrue);
      await tester.tapAt(
        Offset(strip.left + PassageStrip.margin + 2, strip.center.dy),
      );
      await screen.settle();
      expect(screen.player.looping, isFalse);
    });

    testWidgets('the strip holds at a narrow phone and at twice the text', (
      tester,
    ) async {
      final screen = await _open(tester, size: const Size(840, 1800));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await screen.settle();
      expect(find.byKey(PassageStrip.stripKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      final strip = tester.getRect(find.byKey(PassageStrip.stripKey));
      expect(strip.height, greaterThanOrEqualTo(PassageStrip.height));
      expect(strip.width, lessThanOrEqualTo(420));
    });

    testWidgets('a swipe on the strip away from the poles changes section', (
      tester,
    ) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      final strip = tester.getRect(find.byKey(PassageStrip.stripKey));
      await tester.flingFrom(
        Offset(strip.left + strip.width * 0.5, strip.center.dy),
        const Offset(400, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(screen.scope.navigation.section, AppSection.drone);
      expect(screen.player.loopStart, a);
    });

    testWidgets('the strip has a slider for each flag, a tenth of a second '
        'a step', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Start 1:00.00'), findsOneWidget);
      expect(find.bySemanticsLabel('End 2:00.00'), findsOneWidget);
      // ignore: deprecated_member_use
      final owner = tester.binding.pipelineOwner.semanticsOwner!;
      SemanticsNode? node;
      void visit(SemanticsNode n) {
        if (n.label == 'End 2:00.00') node = n;
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(owner.rootSemanticsNode!);
      owner.performAction(node!.id, SemanticsAction.increase);
      await tester.pump();
      expect(screen.player.loopEnd, b + const Duration(milliseconds: 100));
      handle.dispose();
    });

    testWidgets('a file that fails is said in the same line, as an error', (
      tester,
    ) async {
      final screen = await _open(tester);
      screen.output.failWith = TrackOpenException(TrackProblem.missing);
      await tester.tap(hub);
      await screen.settle();
      final text = tester.widget<Text>(find.byKey(PlayerPanel.messageKey));
      expect(text.data, 'The file is no longer available.');
      expect(
        text.style?.color,
        Theme.of(tester.element(find.byKey(PlayerPanel.messageKey)))
            .colorScheme
            .error,
      );
    });

    testWidgets('the speed field offers a short list of speeds', (
      tester,
    ) async {
      final screen = await track(tester);
      expect(
        find.descendant(
          of: find.byKey(PlayerPanel.speedFieldKey),
          matching: find.text('100%'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(PlayerPanel.speedFieldKey));
      await screen.settle();
      for (final p in PlayerPanel.speedChoices) {
        expect(find.text('$p%'), findsWidgets);
      }
      await tester.tap(find.text('70%'));
      await screen.settle();
      expect(screen.player.speed, 70);
      expect(screen.output.speed, 0.7);
      // Away from 100% the value is in the accent, to be noticed.
      final value = tester.widget<Text>(
        find.descendant(
          of: find.byKey(PlayerPanel.speedFieldKey),
          matching: find.text('70%'),
        ),
      );
      expect(
        value.style?.color,
        LowEndColors.of(tester.element(find.text('70%'))).activeFill,
      );
    });

    testWidgets('the last row is the track field alone', (tester) async {
      final screen = await track(tester);
      expect(find.byKey(PlayerPanel.trackFieldKey), findsOneWidget);
      final field = tester.getRect(find.byKey(PlayerPanel.trackFieldKey));
      final speed = tester.getRect(find.byKey(PlayerPanel.speedFieldKey));
      expect(field.top, greaterThan(speed.bottom));
      expect(screen.player.title, 'Blue Bossa');
    });

    testWidgets('a swipe that does not start on a flag changes section, '
        'also with a passage marked', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      await tester.flingFrom(ring(tester, 0, -0.4), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(screen.scope.navigation.section, AppSection.drone);
      expect(screen.player.loopStart, a);
      expect(screen.player.loopEnd, b);
    });

    testWidgets('holding the ring does nothing any more', (tester) async {
      final screen = await track(tester);
      final slide = await tester.startGesture(ring(tester, 0.4, 0));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await slide.moveTo(ring(tester, 0, 0.4));
      await tester.pump();
      await slide.up();
      await screen.settle();
      expect(screen.player.hasLoop, isFalse);
      expect(screen.player.loopStart, isNull);
    });

    testWidgets('the ring is always the whole track', (tester) async {
      final screen = await track(tester);
      RingWindow shown() =>
          (tester
                      .widget<CustomPaint>(
                        find.byWidgetPredicate(
                          (w) => w is CustomPaint && w.painter is RingWave,
                        ),
                      )
                      .painter!
                  as RingWave)
              .window;
      expect(shown(), whole);
      await screen.player.setLoop(a, b);
      await screen.settle();
      expect(shown(), whole);
    });
  });
}
