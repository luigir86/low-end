// The Player's screen (RF-PLY-02, RF-PLY-03, RF-PLY-07, RF-PLY-16): the
// middle, the ring, the field and the messages, in the whole app with silent
// outputs.

import 'dart:math' as math;
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
import 'package:low_end/features/player/player_dial.dart';
import 'package:low_end/features/player/player_panel.dart';
import 'package:low_end/features/player/ring_wave.dart';
import 'package:low_end/features/player/ring_window.dart';
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
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.text('Tap to start'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('the middle shows title and artist only when the file has tags, '
      'and the hint only when stopped (RF-PLY-02, RF-PLY-19)', (tester) async {
    final files = FakeTrackFiles(next: _song)
      ..tagsAnswer = (title: 'Blue Bossa', artist: 'Kenny Dorham');
    final screen = await _open(tester, files: files);
    await screen.player.pick();
    await screen.settle();
    expect(find.text('Blue Bossa · Kenny Dorham'), findsOneWidget);
    expect(find.text('Tap to start'), findsOneWidget);
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
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.text('Tap to start'), findsNothing);
    expect(find.bySemanticsLabel('Pause'), findsWidgets);

    screen.output.advance(const Duration(seconds: 72));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1:12'), findsOneWidget);

    await tester.tap(hub);
    await screen.settle();
    expect(screen.player.isPlaying, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.text('Tap to start'), findsOneWidget);
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

    Rect dialRect(WidgetTester tester) =>
        tester.getRect(find.byKey(DialLayout.dialKey));

    Offset ring(WidgetTester tester, double dx, double dy) {
      final dial = dialRect(tester);
      return dial.center + Offset(dial.width * dx, dial.height * dy);
    }

    /// Where the flag of [edge] waits, on the screen.
    Offset corner(WidgetTester tester, LoopEdge edge) {
      final dial = dialRect(tester);
      return dial.topLeft + holderCenter(edge, dial.size);
    }

    /// Where the pennant of a flag on the ring is, on the screen.
    Offset pennant(WidgetTester tester, LoopEdge edge, Duration time) {
      final dial = dialRect(tester);
      return dial.topLeft + gripCenter(edge, whole, time, dial.size);
    }

    /// The point of the ring, outside the middle, at [time].
    Offset onRing(WidgetTester tester, Duration time) {
      final dial = dialRect(tester);
      final g = DialGeometry(dial.size);
      final angle = whole.angleOf(time);
      final r = g.ringInner + g.ringWidth * 0.5;
      return dial.topLeft +
          g.center +
          Offset(math.sin(angle), -math.cos(angle)) * r;
    }

    /// Drags from [from] to [to] in steps and lets go.
    Future<void> drag(
      WidgetTester tester,
      Offset from,
      Offset to, {
      bool letGo = true,
    }) async {
      final gesture = await tester.startGesture(from);
      await tester.pump();
      for (var i = 1; i <= 6; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 6)!);
        await tester.pump(const Duration(milliseconds: 20));
      }
      if (letGo) await gesture.up();
      await tester.pump();
    }

    String message(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(PlayerPanel.messageKey)).data!;

    Future<_Screen> track(WidgetTester tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      return screen;
    }

    testWidgets('with no track the controls are off', (tester) async {
      final screen = await _open(tester);
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isFalse);
      expect(enabled(tester, PlayerPanel.earlierKey), isFalse);
      expect(enabled(tester, PlayerPanel.laterKey), isFalse);
      expect(find.byKey(PlayerPanel.messageKey), findsNothing);
      await tester.tap(find.byKey(PlayerPanel.speedFieldKey));
      await screen.settle();
      expect(find.text('Listening speed'), findsNothing);
    });

    testWidgets('the line of messages says the next step', (tester) async {
      final screen = await track(tester);
      expect(
        message(tester),
        'Drag A and B onto the ring to choose the passage to repeat',
      );
      await tester.tapAt(corner(tester, LoopEdge.start));
      await screen.settle();
      expect(message(tester), 'Touch the ring where the passage starts');
      await tester.tapAt(corner(tester, LoopEdge.end));
      await screen.settle();
      expect(message(tester), 'Touch the ring where the passage ends');
      await tester.tapAt(onRing(tester, b));
      await screen.settle();
      expect(message(tester), 'Now bring A to where the passage starts');
      await tester.tapAt(corner(tester, LoopEdge.start));
      await tester.tapAt(onRing(tester, a));
      await screen.settle();
      expect(message(tester), 'Fine-tune with ‹ and ›');
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

    testWidgets('the arrows move the active flag, a hundredth at a touch', (
      tester,
    ) async {
      final screen = await track(tester);
      await screen.player.place(LoopEdge.start, const Duration(seconds: 10));
      await screen.player.place(LoopEdge.end, const Duration(seconds: 20));
      await screen.settle();
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isTrue);
      // B was placed last: the arrows say B.
      expect(
        find.descendant(
          of: find.byKey(PlayerPanel.earlierKey),
          matching: find.text('B'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(PlayerPanel.laterKey));
      await screen.settle();
      expect(screen.player.loopEnd, const Duration(milliseconds: 20010));
      expect(screen.player.loopStart, const Duration(seconds: 10));
      // A touch on the pennant of A on the ring makes A the active one.
      await tester.tapAt(
        pennant(tester, LoopEdge.start, const Duration(seconds: 10)),
      );
      await screen.settle();
      expect(screen.player.activeEdge, LoopEdge.start);
      expect(
        find.descendant(
          of: find.byKey(PlayerPanel.earlierKey),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(PlayerPanel.earlierKey));
      await screen.settle();
      expect(screen.player.loopStart, const Duration(milliseconds: 9990));
      expect(screen.player.loopEnd, const Duration(milliseconds: 20010));
    });

    testWidgets('the arrows are off while the active flag is in its corner', (
      tester,
    ) async {
      final screen = await track(tester);
      expect(enabled(tester, PlayerPanel.earlierKey), isFalse);
      await screen.player.place(LoopEdge.end, b);
      await screen.settle();
      expect(enabled(tester, PlayerPanel.laterKey), isTrue);
      screen.player.focus(LoopEdge.start);
      await screen.settle();
      expect(enabled(tester, PlayerPanel.laterKey), isFalse);
    });

    testWidgets('holding an arrow keeps moving the flag', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );
      await screen.settle();
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(PlayerPanel.laterKey)),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await hold.up();
      await screen.settle();
      expect(
        screen.player.loopEnd! > const Duration(milliseconds: 20050),
        isTrue,
      );
      expect(screen.player.loopStart, const Duration(seconds: 10));
    });

    testWidgets('the loop switch repeats the passage or lets it go', (
      tester,
    ) async {
      final screen = await track(tester);
      await screen.player.place(LoopEdge.end, b);
      await screen.settle();
      // The switch needs both flags.
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isFalse);
      await screen.player.place(LoopEdge.start, Duration.zero);
      await screen.settle();
      expect(screen.player.looping, isTrue);
      expect(screen.output.loop, isNotNull);
      await tester.tap(find.byKey(PlayerPanel.loopSwitchKey));
      await screen.settle();
      expect(screen.player.looping, isFalse);
      await tester.tap(find.byKey(PlayerPanel.loopSwitchKey));
      await screen.settle();
      expect(screen.player.looping, isTrue);
    });

    testWidgets('the speed field asks for a speed in a sheet', (tester) async {
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
      expect(find.text('Listening speed'), findsOneWidget);
      await tester.tap(find.text('70%'));
      await screen.settle();
      expect(screen.player.speed, 70);
      expect(screen.output.speed, 0.7);
    });

    testWidgets('the last row is the track field alone', (tester) async {
      final screen = await track(tester);
      expect(find.byKey(PlayerPanel.trackFieldKey), findsOneWidget);
      final field = tester.getRect(find.byKey(PlayerPanel.trackFieldKey));
      final speed = tester.getRect(find.byKey(PlayerPanel.speedFieldKey));
      expect(field.top, greaterThan(speed.bottom));
      expect(screen.player.title, 'Blue Bossa');
    });

    testWidgets('dragging A from its corner onto the ring puts it there, '
        'with its time in the middle, and does not change section', (
      tester,
    ) async {
      final screen = await track(tester);
      final from = corner(tester, LoopEdge.start);
      final gesture = await tester.startGesture(from);
      await tester.pump();
      for (var i = 1; i <= 6; i++) {
        await gesture.moveTo(
          Offset.lerp(
            from,
            onRing(tester, const Duration(seconds: 90)),
            i / 6,
          )!,
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      // The middle shows the time of the flag held, to the hundredth.
      expect(find.textContaining('A 1:3'), findsWidgets);
      expect(screen.player.loopStart, isNull);
      await gesture.up();
      await screen.settle();
      expect(screen.scope.navigation.section, AppSection.player);
      expect(screen.player.loopStart!.inMilliseconds, closeTo(90000, 1500));
      expect(screen.player.loopEnd, isNull);
      expect(screen.player.looping, isFalse);
      expect(screen.player.activeEdge, LoopEdge.start);
    });

    testWidgets('both flags dragged on turn the loop on', (tester) async {
      final screen = await track(tester);
      await drag(tester, corner(tester, LoopEdge.start), onRing(tester, a));
      await drag(tester, corner(tester, LoopEdge.end), onRing(tester, b));
      await screen.settle();
      expect(screen.player.loopStart!.inMilliseconds, closeTo(60000, 1500));
      expect(screen.player.loopEnd!.inMilliseconds, closeTo(120000, 1500));
      expect(screen.player.looping, isTrue);
      expect(screen.output.loop, isNotNull);
    });

    testWidgets('a flag let go outside the ring goes back to its corner', (
      tester,
    ) async {
      final screen = await track(tester);
      final from = corner(tester, LoopEdge.start);
      await drag(tester, from, from + const Offset(-10, 10));
      await screen.settle();
      expect(screen.player.loopStart, isNull);
      expect(screen.scope.navigation.section, AppSection.player);
    });

    testWidgets('a flag dragged over the other sends it back', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      // A, from its corner, to just before B.
      await drag(
        tester,
        corner(tester, LoopEdge.start),
        onRing(tester, b - const Duration(milliseconds: 500)),
      );
      await screen.settle();
      expect(screen.player.loopEnd, isNull);
      expect(screen.player.looping, isFalse);
      expect(screen.player.loopStart!.inMilliseconds, closeTo(119500, 1500));
    });

    testWidgets('two touches put a flag: its corner, then the ring', (
      tester,
    ) async {
      final screen = await track(tester);
      await screen.player.seek(const Duration(seconds: 200));
      await tester.tapAt(corner(tester, LoopEdge.start));
      await screen.settle();
      expect(screen.player.armed, LoopEdge.start);
      await tester.tapAt(onRing(tester, a));
      await screen.settle();
      expect(screen.player.armed, isNull);
      expect(screen.player.loopStart!.inMilliseconds, closeTo(60000, 1500));
      // The touch put the flag and did not move the listening point.
      expect(screen.player.position, const Duration(seconds: 200));
    });

    testWidgets('a second touch on an armed flag disarms it, and the other '
        'takes its place', (tester) async {
      final screen = await track(tester);
      await tester.tapAt(corner(tester, LoopEdge.start));
      await tester.tapAt(corner(tester, LoopEdge.end));
      expect(screen.player.armed, LoopEdge.end);
      await tester.tapAt(corner(tester, LoopEdge.end));
      expect(screen.player.armed, isNull);
      // Unarmed, a touch on the ring is a seek.
      await tester.tapAt(onRing(tester, b));
      await screen.settle();
      expect(screen.player.position.inMilliseconds, closeTo(120000, 1500));
      expect(screen.player.hasLoop, isFalse);
    });

    testWidgets('leaving the tab disarms', (tester) async {
      final screen = await track(tester);
      await tester.tapAt(corner(tester, LoopEdge.start));
      expect(screen.player.armed, LoopEdge.start);
      screen.scope.navigation.open(AppSection.metronome);
      await tester.pumpAndSettle();
      expect(screen.player.armed, isNull);
    });

    testWidgets('dragging a flag on the ring moves it, stops a second from '
        'the other and does not change section', (tester) async {
      final screen = await track(tester);
      await screen.player.setLoop(a, b);
      await screen.settle();
      await drag(
        tester,
        onRing(tester, b),
        onRing(tester, const Duration(seconds: 150)),
      );
      await screen.settle();
      expect(screen.scope.navigation.section, AppSection.player);
      expect(screen.player.loopEnd!.inMilliseconds, closeTo(150000, 2500));
      expect(screen.player.loopStart, a);
      // Dragged back past A: it stops a second after it.
      await drag(
        tester,
        onRing(tester, screen.player.loopEnd!),
        onRing(tester, const Duration(seconds: 50)),
      );
      await screen.settle();
      expect(
        screen.player.loopEnd,
        greaterThanOrEqualTo(a + PlayerController.minLoop),
      );
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
