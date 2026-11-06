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

  group('the passage (RF-PLY-08 to RF-PLY-12, RF-PLY-17, RF-PLY-18)', () {
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

    /// Where a grip is on the screen, in the window shown.
    Offset grip(
      WidgetTester tester,
      LoopEdge edge,
      RingWindow window,
      Duration time,
    ) {
      final dial = tester.getRect(find.byKey(DialLayout.dialKey));
      return dial.topLeft + gripCenter(edge, window, time, dial.size);
    }

    /// The point of the ring, outside the middle, at [time] of [window].
    Offset onRing(WidgetTester tester, RingWindow window, Duration time) {
      final dial = tester.getRect(find.byKey(DialLayout.dialKey));
      final g = DialGeometry(dial.size);
      final angle = window.angleOf(time);
      final r = g.ringInner + g.ringWidth * 0.5;
      return dial.topLeft +
          g.center +
          Offset(math.sin(angle), -math.cos(angle)) * r;
    }

    RingWindow shown(WidgetTester tester) =>
        (tester
                    .widget<CustomPaint>(
                      find.byWidgetPredicate(
                        (w) => w is CustomPaint && w.painter is RingWave,
                      ),
                    )
                    .painter!
                as RingWave)
            .window;

    const a = Duration(minutes: 1), b = Duration(minutes: 2);
    final passage = RingWindow.passage(a, b, const Duration(minutes: 6));
    final whole = RingWindow.whole(const Duration(minutes: 6));

    testWidgets('with no track the controls are off', (tester) async {
      final screen = await _open(tester);
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isFalse);
      expect(enabled(tester, PlayerPanel.startEarlierKey), isFalse);
      expect(enabled(tester, PlayerPanel.endLaterKey), isFalse);
      expect(find.text('A –'), findsOneWidget);
      expect(find.text('B –'), findsOneWidget);
      expect(find.byKey(PlayerPanel.messageKey), findsNothing);
      await tester.tap(find.byKey(PlayerPanel.speedFieldKey));
      await screen.settle();
      expect(find.text('Listening speed'), findsNothing);
    });

    testWidgets('the line of messages says how to choose, then how to adjust '
        'the passage', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      expect(
        tester.widget<Text>(find.byKey(PlayerPanel.messageKey)).data,
        startsWith('Hold on the ring and slide'),
      );
      await screen.player.setLoop(a, b);
      await screen.settle();
      expect(
        find.text('Drag A and B on the ring to adjust the passage'),
        findsOneWidget,
      );
      expect(find.textContaining('Hold on the ring'), findsNothing);
      // The loop off, the ends still marked: still the adjusting hint.
      await screen.player.setLooping(false);
      await screen.settle();
      expect(find.textContaining('Drag A and B'), findsOneWidget);
    });

    testWidgets('a file that fails is said in the same line, as an error', (
      tester,
    ) async {
      final screen = await _open(tester);
      screen.output.failWith = TrackOpenException(TrackProblem.missing);
      await tester.tap(hub);
      await screen.settle();
      final message = tester.widget<Text>(find.byKey(PlayerPanel.messageKey));
      expect(message.data, 'The file is no longer available.');
      expect(
        message.style?.color,
        Theme.of(tester.element(find.byKey(PlayerPanel.messageKey)))
            .colorScheme
            .error,
      );
    });

    testWidgets('each end has its own − and +, a hundredth at a touch', (
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
      expect(find.text('A 0:10.00'), findsOneWidget);
      expect(find.text('B 0:20.00'), findsOneWidget);
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isTrue);

      await tester.tap(find.byKey(PlayerPanel.startEarlierKey));
      await screen.settle();
      expect(screen.player.loopStart, const Duration(milliseconds: 9990));
      expect(find.text('A 0:09.99'), findsOneWidget);

      await tester.tap(find.byKey(PlayerPanel.endLaterKey));
      await screen.settle();
      expect(screen.player.loopStart, const Duration(milliseconds: 9990));
      expect(screen.player.loopEnd, const Duration(milliseconds: 20010));
      expect(find.text('B 0:20.01'), findsOneWidget);

      await tester.tap(find.byKey(PlayerPanel.startLaterKey));
      await tester.tap(find.byKey(PlayerPanel.endEarlierKey));
      await screen.settle();
      expect(screen.player.loopStart, const Duration(seconds: 10));
      expect(screen.player.loopEnd, const Duration(seconds: 20));
    });

    testWidgets('holding + keeps moving the end', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );
      await screen.settle();
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(PlayerPanel.endLaterKey)),
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
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.mark(LoopEdge.start);
      await screen.settle();
      // The switch needs both ends.
      expect(enabled(tester, PlayerPanel.loopSwitchKey), isFalse);
      await screen.player.seek(const Duration(seconds: 20));
      await screen.player.mark(LoopEdge.end);
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

    testWidgets('holding the ring and sliding draws a passage, and the ring '
        'turns to show it', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      expect(shown(tester), whole);
      // From 3 o'clock (a quarter: 1:30) to 6 o'clock (half: 3:00).
      final slide = await tester.startGesture(ring(tester, 0.4, 0));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await slide.moveTo(ring(tester, 0.3, 0.3));
      await tester.pump();
      await slide.moveTo(ring(tester, 0, 0.4));
      await tester.pump();
      // Still the whole track while the finger works.
      expect(shown(tester), whole);
      await slide.up();
      await screen.settle();
      expect(screen.player.looping, isTrue);
      expect(screen.player.loopStart, const Duration(seconds: 90));
      expect(screen.player.loopEnd, const Duration(minutes: 3));
      expect(find.text('A 1:30.00'), findsOneWidget);
      expect(find.text('B 3:00.00'), findsOneWidget);
      expect(
        shown(tester),
        RingWindow.passage(
          const Duration(seconds: 90),
          const Duration(minutes: 3),
          const Duration(minutes: 6),
        ),
      );
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

    testWidgets('the ring shows the passage while the loop is on, the whole '
        'track when it is off', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await screen.settle();
      expect(shown(tester), passage);
      await screen.player.setLooping(false);
      await screen.settle();
      expect(shown(tester), whole);
      await screen.player.setLooping(true);
      await screen.settle();
      expect(shown(tester), passage);
    });

    testWidgets('a touch on the ring outside the passage turns the loop off, '
        'and the ring goes back to the whole track', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await screen.settle();
      // Just before 12 o'clock: the end of the margin after B.
      await tester.tapAt(
        onRing(tester, passage, passage.to - const Duration(seconds: 1)),
      );
      await screen.settle();
      expect(screen.player.looping, isFalse);
      expect(screen.player.loopStart, a);
      expect(screen.player.position, greaterThan(b));
      expect(shown(tester), whole);
    });

    testWidgets('a touch inside the passage moves the listening point and '
        'keeps the loop', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await screen.settle();
      await tester.tapAt(onRing(tester, passage, const Duration(seconds: 90)));
      await screen.settle();
      expect(screen.player.looping, isTrue);
      expect(screen.player.position.inMilliseconds, closeTo(90000, 1500));
    });

    testWidgets('dragging a grip moves that end and does not change section, '
        'and the ring waits for the finger', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await screen.settle();
      expect(shown(tester), passage);

      final drag = await tester.startGesture(
        grip(tester, LoopEdge.end, passage, b),
      );
      await tester.pump();
      for (final seconds in [122, 124, 126]) {
        await drag.moveTo(onRing(tester, passage, Duration(seconds: seconds)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      // The ring stays still under the finger, and the number follows it.
      expect(shown(tester), passage);
      expect(screen.scope.navigation.section, AppSection.player);
      expect(screen.player.loopEnd!.inMilliseconds, closeTo(126000, 1500));
      // The middle shows the time of the end being dragged.
      expect(find.textContaining('B 2:0'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
      expect(shown(tester), passage);

      await drag.up();
      await tester.pump();
      await screen.settle();
      expect(screen.scope.navigation.section, AppSection.player);
      expect(screen.player.loopStart, a);
      // After a moment of quiet the ring fits the new passage.
      expect(
        shown(tester),
        RingWindow.passage(
          a,
          screen.player.loopEnd!,
          const Duration(minutes: 6),
        ),
      );
    });

    testWidgets('a grip is taken a finger away from its disc, without a jump', (
      tester,
    ) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await screen.settle();
      final at = grip(tester, LoopEdge.start, passage, a) + const Offset(0, 14);
      final drag = await tester.startGesture(at);
      await tester.pump();
      await drag.moveBy(const Offset(0.5, 0));
      await tester.pump();
      await drag.up();
      await screen.settle();
      // Moved by next to nothing: the end does not jump to the finger.
      expect(screen.player.loopStart!.inMilliseconds, closeTo(60000, 600));
    });

    testWidgets('A cannot be dragged past B, nor out of the window', (
      tester,
    ) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await screen.settle();
      final startAt = grip(tester, LoopEdge.start, passage, a);
      final drag = await tester.startGesture(startAt);
      await tester.pump();
      for (final seconds in [70, 90, 110, 119]) {
        final to = onRing(tester, passage, Duration(seconds: seconds));
        await drag.moveTo(to);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await drag.up();
      await screen.settle();
      expect(
        screen.player.loopStart,
        lessThanOrEqualTo(b - PlayerController.minLoop),
      );
      expect(screen.player.loopEnd, b);
    });

    testWidgets('a swipe that does not start on a grip changes section, '
        'also with a passage marked', (tester) async {
      final screen = await _open(tester);
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await screen.settle();
      await tester.flingFrom(ring(tester, 0, -0.4), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(screen.scope.navigation.section, AppSection.drone);
      expect(screen.player.loopStart, a);
      expect(screen.player.loopEnd, b);
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

    testWidgets('with animations off the ring jumps to the passage', (
      tester,
    ) async {
      final screen = await _open(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await screen.player.open(_song);
      await screen.settle();
      await screen.player.setLoop(a, b);
      await tester.pump();
      expect(shown(tester), passage);
    });
  });
}
