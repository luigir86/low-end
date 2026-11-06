// The Player's screen (RF-PLY-02, RF-PLY-03, RF-PLY-07, RF-PLY-16): the
// middle, the ring, the field and the messages, in the whole app with silent
// outputs.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/screen_awake.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/player/player_controller.dart';
import 'package:low_end/features/player/player_panel.dart';
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
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('0:00 / 6:00'), findsOneWidget);
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
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.bySemanticsLabel('Pause'), findsWidgets);

    screen.output.advance(const Duration(seconds: 72));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1:12 / 6:00'), findsOneWidget);

    await tester.tap(hub);
    await screen.settle();
    expect(screen.player.isPlaying, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    // The position stays.
    expect(find.text('1:12 / 6:00'), findsOneWidget);
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
      expect(find.text('0:00 / 6:00'), findsOneWidget);
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

  group('speed and loop (RF-PLY-08 to RF-PLY-12)', () {
    Finder pressable(Key key) => find.descendant(
      of: find.byKey(key),
      matching: find.byWidgetPredicate(
        (w) => w is OutlinedButton || w is FilledButton,
      ),
    );

    bool enabled(WidgetTester tester, Key key) {
      final button = tester.widget<ButtonStyleButton>(pressable(key).first);
      return button.onPressed != null;
    }

    Offset ring(WidgetTester tester, double dx, double dy) {
      final dial = tester.getRect(find.byKey(DialLayout.dialKey));
      return dial.center + Offset(dial.width * dx, dial.height * dy);
    }

    testWidgets('with no track the controls are off', (tester) async {
      final screen = await _open(tester);
      expect(enabled(tester, PlayerPanel.markStartKey), isFalse);
      expect(enabled(tester, PlayerPanel.markEndKey), isFalse);
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isFalse);
      expect(enabled(tester, PlayerPanel.stepBackKey), isFalse);
      expect(find.text('A –'), findsOneWidget);
      expect(find.text('B –'), findsOneWidget);
      await tester.tap(find.byKey(PlayerPanel.speedFieldKey));
      await screen.settle();
      expect(find.text('Listening speed'), findsNothing);
    });

    testWidgets('Set A and Set B mark the loop and turn it on', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.seek(const Duration(seconds: 10));

      await tester.tap(find.byKey(PlayerPanel.markStartKey));
      await screen.settle();
      expect(find.text('A 0:09.8'), findsOneWidget);
      expect(enabled(tester, PlayerPanel.stepBackKey), isTrue);
      // The loop switch needs both ends.
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isFalse);

      await screen.player.seek(const Duration(seconds: 20));
      await tester.tap(find.byKey(PlayerPanel.markEndKey));
      await screen.settle();
      expect(find.text('B 0:19.8'), findsOneWidget);
      expect(screen.player.looping, isTrue);
      expect(screen.output.loop, isNotNull);
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isTrue);

      // The switch turns the repeat off and back on, the ends stay.
      await tester.tap(find.byKey(PlayerPanel.loopSwitchKey));
      await screen.settle();
      expect(screen.player.looping, isFalse);
      expect(find.text('A 0:09.8'), findsOneWidget);
      await tester.tap(find.byKey(PlayerPanel.loopSwitchKey));
      await screen.settle();
      expect(screen.player.looping, isTrue);
    });

    testWidgets('the segments choose the end that − and + move', (
      tester,
    ) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );
      await screen.settle();
      expect(screen.player.edge, LoopEdge.start);

      await tester.tap(find.byKey(PlayerPanel.stepBackKey));
      await screen.settle();
      expect(screen.player.loopStart, const Duration(milliseconds: 9900));

      await tester.tap(find.text('B 0:20.0'));
      await screen.settle();
      expect(screen.player.edge, LoopEdge.end);
      await tester.tap(find.byKey(PlayerPanel.stepForwardKey));
      await screen.settle();
      expect(screen.player.loopStart, const Duration(milliseconds: 9900));
      expect(screen.player.loopEnd, const Duration(milliseconds: 20100));
    });

    testWidgets('holding + keeps moving the end', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );
      screen.player.selectEdge(LoopEdge.end);
      await tester.pump();
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(PlayerPanel.stepForwardKey)),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await hold.up();
      await screen.settle();
      expect(
        screen.player.loopEnd! > const Duration(milliseconds: 20300),
        isTrue,
      );
    });

    testWidgets('the speed field asks for a speed in a sheet', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      expect(
        find.descendant(
          of: find.byKey(PlayerPanel.speedFieldKey),
          matching: find.text('100%'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(PlayerPanel.speedFieldKey));
      await screen.settle();
      expect(find.text('Listening speed'), findsOneWidget);
      await tester.tap(find.text('70%'));
      await screen.settle();
      expect(screen.player.speed, 70);
      expect(screen.output.speed, 0.7);
      expect(
        find.descendant(
          of: find.byKey(PlayerPanel.speedFieldKey),
          matching: find.text('70%'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('holding the ring and sliding draws a loop', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      // From 3 o'clock (a quarter: 1:30) to 6 o'clock (half: 3:00).
      final slide = await tester.startGesture(ring(tester, 0.4, 0));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await slide.moveTo(ring(tester, 0.3, 0.3));
      await tester.pump();
      await slide.moveTo(ring(tester, 0, 0.4));
      await tester.pump();
      await slide.up();
      await screen.settle();
      expect(screen.player.looping, isTrue);
      expect(screen.player.loopStart, const Duration(seconds: 90));
      expect(screen.player.loopEnd, const Duration(minutes: 3));
      expect(find.text('A 1:30.0'), findsOneWidget);
      expect(find.text('B 3:00.0'), findsOneWidget);
    });

    testWidgets('a slide shorter than a second is a touch', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      final slide = await tester.startGesture(ring(tester, 0.4, 0));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await slide.up();
      await screen.settle();
      expect(screen.player.hasLoop, isFalse);
      expect(screen.player.position, const Duration(seconds: 90));
    });

    testWidgets('a touch on the ring outside the loop turns it off', (
      tester,
    ) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );
      await tester.tapAt(ring(tester, 0.4, 0));
      await screen.settle();
      expect(screen.player.looping, isFalse);
      expect(screen.player.loopStart, const Duration(seconds: 10));
      expect(screen.player.position, const Duration(seconds: 90));
    });

    testWidgets('swiping between sections still works over the ring', (
      tester,
    ) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      expect(screen.scope.navigation.section, AppSection.player);
      await tester.flingFrom(ring(tester, 0, -0.4), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(screen.scope.navigation.section, AppSection.drone);
      expect(screen.player.hasLoop, isFalse);
    });
  });
}
