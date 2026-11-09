// The Player's recording (RF-PLY-20): REC, Stop and Discard, the take over
// the track being studied, and the actions for assistants. No microphone:
// FakeTakeRecorder stands for it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/actions/app_actions.dart';
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
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/player/player_controller.dart';
import 'package:low_end/features/player/player_dial.dart';
import 'package:low_end/features/player/player_panel.dart';
import 'package:low_end/features/player/recording_controller.dart';
import 'package:low_end/features/player/ring_wave.dart';
import 'package:low_end/features/player/track_peaks.dart';
import 'package:low_end/features/tuner/tuner_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _song = TrackRef(uri: 'content://song', name: 'Blue Bossa.mp3');
const _other = TrackRef(uri: 'content://other', name: 'Other.m4a');

Duration _s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SilentTrackOutput output;
  late FakeTrackFiles files;
  late PlayerController player;
  late FakeTakeRecorder recorder;
  late AppNavigation navigation;
  late RecordingController recording;

  setUp(() async {
    output = SilentTrackOutput();
    files = FakeTrackFiles(next: _song);
    player = PlayerController(output, files);
    recorder = FakeTakeRecorder();
    navigation = AppNavigation(section: AppSection.player);
    recording = RecordingController(
      recorder,
      player: player,
      navigation: navigation,
    );
    await player.pick();
  });

  tearDown(() {
    recording.dispose();
    player.dispose();
  });

  /// Studies [_song] at 70% with the passage 10 to 20 s, looping.
  Future<void> study() async {
    player.setSpeed(70);
    await player.setLoop(_s(10), _s(20));
  }

  group('recording (RF-PLY-20)', () {
    test('REC pauses the Player and records', () async {
      await player.start();
      await recording.start(label: 'Take');
      expect(player.isPlaying, isFalse);
      expect(recording.status, RecordingStatus.recording);
      expect(recorder.recording, startsWith('Take '));
      expect(recorder.recording, endsWith('.m4a'));
    });

    test('Stop opens the take over the track being studied', () async {
      await study();
      await recording.start();
      await recording.finish();
      expect(recording.status, RecordingStatus.idle);
      expect(player.track, isA<RecordedTrack>());
      expect(player.status, PlayerStatus.ready);
      expect(player.speed, 100);
      expect(player.hasLoop, isFalse);
      // The studied track keeps its right to be read, and stays the one
      // remembered for the next launch.
      expect(files.released, isEmpty);
      expect(player.setup?.track, _song);
      expect(player.setup?.speed, 70);
      expect(player.setup?.loopStart, _s(10));
    });

    test('deleting the take brings the track back as it was', () async {
      await study();
      await recording.start();
      await recording.finish();
      final take = player.track! as RecordedTrack;
      await player.removeRecording(take);
      expect(player.track, _song);
      expect(player.speed, 70);
      expect(player.loopStart, _s(10));
      expect(player.loopEnd, _s(20));
      expect(player.looping, isTrue);
      // Only the take's temporary file is let go.
      expect(files.released, [take]);
      // The track is opened again at the first play, at A, at its speed.
      await player.start();
      expect(output.opened, _song);
      expect(output.speed, 0.7);
      expect(output.loop, (_s(10), _s(20)));
    });

    test('a second take replaces the first, the track stays under', () async {
      await recording.start();
      await recording.finish();
      final first = player.track! as RecordedTrack;
      await recording.start();
      await recording.finish();
      expect(player.track, isNot(first));
      expect(files.released, [first]);
      await player.removeRecording(player.track! as RecordedTrack);
      expect(player.track, _song);
    });

    test(
      'another file chosen over a take lets the track under it go',
      () async {
        await recording.start();
        await recording.finish();
        final take = player.track! as RecordedTrack;
        files.next = _other;
        await player.pick();
        expect(player.track, _other);
        expect(files.released, containsAll([take, _song]));
        expect(player.setup?.track, _other);
      },
    );

    test('choosing the same file again keeps its right to be read', () async {
      await recording.start();
      await recording.finish();
      await player.pick();
      expect(player.track, _song);
      expect(files.released, isNot(contains(_song)));
    });

    test('Discard throws the take away and leaves the track', () async {
      await study();
      await recording.start();
      await recording.finish(discard: true);
      expect(recorder.cancelled, 1);
      expect(player.track, _song);
      expect(player.speed, 70);
      expect(player.looping, isTrue);
    });

    test('without the microphone nothing records and it says why', () async {
      recorder.granted = false;
      final problems = <RecordingProblem>[];
      final listening = recording.problems.listen(problems.add);
      await recording.start();
      await pumpEventQueue();
      expect(recording.status, RecordingStatus.idle);
      expect(problems, [RecordingProblem.permissionDenied]);
      expect(player.track, _song);
      await listening.cancel();
    });

    test('a busy microphone says it failed', () async {
      recorder.failStart = true;
      final problems = <RecordingProblem>[];
      final listening = recording.problems.listen(problems.add);
      await recording.start();
      await pumpEventQueue();
      expect(recording.active, isFalse);
      expect(problems, [RecordingProblem.failed]);
      await listening.cancel();
    });

    test('leaving the Player keeps the take, like Stop', () async {
      await recording.start();
      navigation.open(AppSection.metronome);
      await pumpEventQueue();
      expect(recording.active, isFalse);
      expect(player.track, isA<RecordedTrack>());
    });

    test('opening the settings over the Player stops it too', () async {
      await recording.start();
      navigation.setCovered(true);
      await pumpEventQueue();
      expect(recording.active, isFalse);
      expect(player.track, isA<RecordedTrack>());
    });

    test('playing the Player stops the recording', () async {
      await recording.start();
      await player.start();
      await pumpEventQueue();
      expect(recording.active, isFalse);
      expect(player.track, isA<RecordedTrack>());
    });

    test('the wave of the take grows while it records', () async {
      expect(recording.levels, isNull);
      recorder.loudness = 0.5;
      await recording.start(label: 'Take');
      final levels = recording.levels!;
      expect(levels.fullScale, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(levels.length, greaterThan(0));
      // Half the loudest sample is 6 dB down, of 48.
      final height = levels.heights(Duration.zero, TrackPeaks.frame, 1)[0];
      expect(height, closeTo(1 - 6.02 / TrackPeaks.rangeDb, 0.01));
      await recording.finish();
      expect(recording.levels, isNull);
    });

    test('the ring of a take grows by round lengths', () {
      expect(recordingTurn(Duration.zero), const Duration(minutes: 1));
      expect(recordingTurn(_s(59.9)), const Duration(minutes: 1));
      expect(recordingTurn(_s(60)), const Duration(minutes: 2));
      expect(recordingTurn(_s(4 * 60 + 30)), const Duration(minutes: 5));
      expect(
        recordingTurn(const Duration(minutes: 61)),
        const Duration(minutes: 90),
      );
    });

    test('a take is never remembered without a track under it', () async {
      final empty = PlayerController(SilentTrackOutput(), FakeTrackFiles());
      final rec = RecordingController(FakeTakeRecorder(), player: empty);
      await rec.start();
      await rec.finish();
      expect(empty.track, isA<RecordedTrack>());
      expect(empty.setup, isNull);
      await empty.removeRecording(empty.track! as RecordedTrack);
      expect(empty.track, isNull);
      rec.dispose();
      empty.dispose();
    });
  });

  group('actions (RF-LLM)', () {
    late AppActions actions;

    setUp(() {
      actions = AppActions(
        drone: DroneController(SilentToneOutput()),
        metronome: MetronomeController(SilentClickOutput()),
        tuner: TunerController(FakeMicInput()),
        player: player,
        recording: recording,
        navigation: navigation,
        settings: AppSettings(),
      );
    });

    test('player_record and player_record_stop', () async {
      navigation.open(AppSection.metronome);
      var result = await actions.call('player_record');
      expect(result['ok'], isTrue);
      expect(navigation.section, AppSection.player);
      final state = (result['state']! as Map)['player'] as Map;
      expect(state['recording'], 'recording');
      result = await actions.call('player_record');
      expect(result['ok'], isFalse);
      result = await actions.call('player_record_stop');
      expect(result['ok'], isTrue);
      final after = (result['state']! as Map)['player'] as Map;
      expect(after['recording'], 'idle');
      expect(after['take'], isTrue);
      result = await actions.call('player_record_stop');
      expect(result['ok'], isFalse);
    });

    test('player_record_stop with discard keeps the track', () async {
      await actions.call('player_record');
      final result = await actions.call('player_record_stop', {
        'discard': true,
      });
      expect(result['ok'], isTrue);
      expect(player.track, _song);
    });

    test('player_record says when the microphone is not allowed', () async {
      recorder.granted = false;
      final result = await actions.call('player_record');
      expect(result['ok'], isFalse);
      expect(recording.active, isFalse);
    });
  });

  testWidgets('REC, Stop and the take row in the app', (tester) async {
    SharedPreferences.setMockInitialValues({'seen_guide': true});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final mic = FakeTakeRecorder();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        trackOutput: SilentTrackOutput(),
        trackFiles: FakeTrackFiles(next: _song),
        takeRecorder: mic,
        screenAwake: FakeScreenAwake(),
        settings: AppSettings()..rememberSection(AppSection.player),
      ),
    );
    await tester.pumpAndSettle();
    final rec = find.byKey(PlayerPanel.recordKey);
    expect(find.byTooltip('Record'), findsOne);
    final dot = tester.widget<Icon>(
      find.descendant(of: rec, matching: find.byIcon(Icons.circle)),
    );
    final theme = Theme.of(tester.element(rec));
    expect(dot.color, theme.colorScheme.error);
    await tester.tap(rec);
    await tester.pump();
    await tester.pump();
    expect(mic.recording, isNotNull);
    expect(find.byKey(const Key('takeStop')), findsOne);
    // The ring draws the take in red as it is recorded.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter is RingWave &&
            (w.painter! as RingWave).color == theme.colorScheme.error,
      ),
      findsOne,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('takeStop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(mic.takes, 1);
    // The take's row: save, share, delete.
    expect(find.byTooltip('Save'), findsOne);
    expect(find.byTooltip('Share'), findsOne);
    final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
    expect(scope.player.track, isA<RecordedTrack>());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
