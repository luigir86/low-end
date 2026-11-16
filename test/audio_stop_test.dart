// Stop silences the piano at once, whatever it is doing: playing, waiting
// for its bar line, or handing over to a new loop. Followed on the fake
// engine, which knows which voices sound, and how loud.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/bar_loop_player.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/in_steps.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/piano_mixer.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/metronome/time_signature.dart';

import 'fake_loop_engine.dart';

const bar = Duration(seconds: 2);
const ms300 = Duration(milliseconds: 300);
const ms500 = Duration(milliseconds: 500);

/// The voices heard at [at], with their level.
String heard(FakeLoopEngine engine, Duration at) => engine.voices.values
    .where((v) => v.soundsAt(at) && v.volumeAt(at) > 0)
    .map((v) => '${v.name}@${v.volumeAt(at).toStringAsFixed(2)}')
    .join(', ');

/// The piano's voices heard at [at] (tails included), the clicks left out.
String pianoHeard(FakeLoopEngine engine, Duration at) => engine.voices.values
    .where((v) => v.name != 'click-loop.wav' && v.soundsAt(at))
    .map((v) => '${v.name}@${v.volumeAt(at).toStringAsFixed(2)}')
    .join(', ');

/// A mixer that makes nothing, says which loops it made tails for, and
/// can hold the tails until [releaseTails].
class _Mixer implements PianoMixer {
  Completer<void>? _tails;
  var tailEntered = Completer<void>();
  final tailsOf = <List<PianoChord>>[];

  void holdTails() {
    _tails = Completer<void>();
    tailEntered = Completer<void>();
  }

  void releaseTails() {
    _tails?.complete();
    _tails = null;
  }

  @override
  Future<void> prepare(List<PianoChord> chords, {bool bass = false}) async {}

  @override
  Future<MixedLoop> loop(
    PianoLoop loop, {
    SlicedWork? work,
    Duration slice = const Duration(milliseconds: 6),
  }) async => (wav: fakeWav(const Duration(seconds: 2)), scale: 1.0);

  @override
  Future<Uint8List> tail(
    PianoLoop loop, {
    required double scale,
    required int position,
    Duration slice = const Duration(milliseconds: 50),
  }) async {
    tailsOf.add(loop.chords);
    if (!tailEntered.isCompleted) tailEntered.complete();
    await _tails?.future;
    return fakeWav(const Duration(seconds: 1));
  }

  @override
  void clear() {}
}

/// Clicks whose start hangs until they are stopped, as clicks waiting to
/// meet a piano that never comes in.
class _WaitingClick implements ClickOutput {
  var stops = 0;
  Completer<void>? _waiting;

  @override
  Future<LoopStart> play(
    Uint8List barWav, {
    Duration? startAt,
    bool atMeeting = false,
  }) async {
    final waiting = _waiting = Completer<void>();
    await waiting.future;
    throw const LoopNotWanted();
  }

  @override
  Future<void> stop() async {
    stops++;
    _waiting?.complete();
    _waiting = null;
  }
}

void main() {
  test('stopping a piano that never sounded makes no tail', () async {
    // The metronome plays; Harmony waits for its next "one" and is
    // stopped before it.
    final engine = FakeLoopEngine();
    final transport = LoopTransport(engine: engine);
    final click = BarLoopPlayer('click', transport: transport);
    final piano = BarLoopPlayer('piano', transport: transport);
    var tails = 0;
    await click.play(fakeWav(bar), bar);
    engine.advance(ms300);
    final started = await piano.play(
      fakeWav(bar * 4),
      bar,
      startAt: Duration.zero,
    );
    expect(started.delay, greaterThan(Duration.zero));
    engine.advance(ms300);
    await piano.stop(
      tailFor: (position) async {
        tails++;
        return fakeWav(ms300);
      },
    );
    expect(tails, 0);
    expect(
      heard(engine, engine.now + const Duration(milliseconds: 1)),
      ['click-loop.wav@1.00'].join(),
    );
    await click.stop();
  });

  test('a stop after a hand-over is scheduled silences the old loop and '
      'its tail', () async {
    // Harmony alone; a new style hands over on the next bar line, and the
    // stop comes during the countdown.
    final engine = FakeLoopEngine();
    final piano = BarLoopPlayer(
      'piano',
      transport: LoopTransport(engine: engine),
    );
    await piano.play(fakeWav(bar * 4), bar, startAt: Duration.zero);
    engine.advance(ms300);
    piano.beginHandOver(lead: ms500);
    await piano.play(
      fakeWav(bar * 4),
      bar,
      startAt: Duration.zero,
      handOver: true,
      tailFor: (_) async => fakeWav(ms300),
    );
    engine.advance(const Duration(milliseconds: 200));
    await piano.stop();
    expect(heard(engine, engine.now + const Duration(milliseconds: 1)), '');
    expect(heard(engine, const Duration(milliseconds: 2100)), '');
    expect(piano.voices, isEmpty);
  });

  test('the same for a new chord waiting for the click\'s bar line', () async {
    final engine = FakeLoopEngine();
    final transport = LoopTransport(engine: engine);
    final click = BarLoopPlayer('click', transport: transport);
    final piano = BarLoopPlayer('piano', transport: transport);
    await click.play(fakeWav(bar), bar);
    await piano.play(fakeWav(bar * 4), bar, startAt: Duration.zero);
    engine.advance(bar + ms300);
    // A new chord struck once a bar: from the top, on the click's bar line.
    await piano.play(
      fakeWav(bar * 4),
      bar,
      startAt: Duration.zero,
      tailFor: (_) async => fakeWav(ms300),
    );
    engine.advance(const Duration(milliseconds: 200));
    await piano.stop();
    expect(
      pianoHeard(engine, engine.now + const Duration(milliseconds: 1)),
      '',
    );
    expect(pianoHeard(engine, const Duration(milliseconds: 4100)), '');
    await click.stop();
  });

  test(
    'a hand-over called off while its tail is made lets the clicks go',
    () async {
      final engine = FakeLoopEngine();
      final transport = LoopTransport(engine: engine);
      final click = BarLoopPlayer('click', transport: transport);
      final piano = BarLoopPlayer('piano', transport: transport);
      await click.play(fakeWav(bar), bar);
      await piano.play(fakeWav(bar * 4), bar, startAt: Duration.zero);
      engine.advance(bar + ms300);
      // A new song: the piano hands over, the clicks wait to meet it.
      piano.beginHandOver(lead: ms500);
      var clickDone = false;
      final clickPlay = click
          .play(fakeWav(bar), bar, startAt: Duration.zero, atMeeting: true)
          .then((_) => clickDone = true);
      var wanted = true;
      final gate = Completer<void>(), entered = Completer<void>();
      final pianoPlay = piano
          .play(
            fakeWav(bar * 4),
            bar,
            startAt: Duration.zero,
            handOver: true,
            tailFor: (_) async {
              entered.complete();
              await gate.future;
              return fakeWav(ms300);
            },
            wanted: () => wanted,
          )
          .then<void>((_) {}, onError: (Object _) {});
      await entered.future;
      // Harmony is stopped while the old loop's tail is being made.
      wanted = false;
      await piano.stop();
      gate.complete();
      await pianoPlay;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(clickDone, isTrue, reason: 'the clicks still wait for a meeting');
      expect(transport.meetingAt, isNull);
      expect(
        engine.playing('click-loop.wav').single.volumeAt(engine.now),
        1,
        reason: 'the clicks stay let down',
      );
      await clickPlay;
      await click.stop();
    },
  );

  test('a stop before a new chord\'s pulse lets go of the old chord', () async {
    final engine = FakeLoopEngine();
    final piano = BarLoopPlayer(
      'piano',
      transport: LoopTransport(engine: engine),
    );
    final asked = <String>[];
    Future<Uint8List> Function(Duration) tailOf(String chord) => (_) async {
      asked.add(chord);
      return fakeWav(ms300);
    };
    await piano.play(fakeWav(bar), bar);
    engine.advance(const Duration(milliseconds: 600));
    // The new chord plays silent under the old one until the pulse at 1 s.
    await piano.play(fakeWav(bar), bar, onPulse: ms500, tailFor: tailOf('old'));
    engine.advance(const Duration(milliseconds: 100));
    await piano.stop(tailFor: tailOf('new'));
    expect(asked, ['old']);
    expect(
      heard(engine, engine.now + const Duration(milliseconds: 1)),
      ['tail.wav@1.00'].single,
    );
  });

  group('through the piano output', () {
    const a = [60, 64, 67], b = [62, 65, 69];
    late FakeLoopEngine engine;
    late _Mixer mixer;
    late SoLoudPianoOutput piano;

    setUp(() {
      engine = FakeLoopEngine();
      mixer = _Mixer();
      piano = SoLoudPianoOutput(
        transport: LoopTransport(engine: engine),
        mixer: mixer,
        engineReady: () async {},
      );
    });

    Future<LoopStart> play(List<int> chord, {bool handOver = false}) =>
        piano.play(
          chords: [chord],
          style: PianoStyle.bar,
          bpm: 120,
          signature: TimeSignature.fourFour,
          a4: 440,
          volume: 0.8,
          startAt: Duration.zero,
          handOver: handOver,
        );

    test('a stop while the next loop is made lets go of the loop that '
        'sounds, not of the next one', () async {
      await play(a);
      engine.advance(ms300);
      var wanted = true;
      piano.stillWanted = () => wanted;
      mixer.holdTails();
      final next = play(b).then<void>((_) {}, onError: (Object _) {});
      await mixer.tailEntered.future;
      wanted = false;
      final stopped = piano.stop();
      await Future<void>.delayed(Duration.zero);
      mixer.releaseTails();
      await Future.wait([next, stopped]);
      expect(mixer.tailsOf.last, [a]);
    });

    test('a stop during the countdown of a hand-over leaves only the '
        'release of the loop heard', () async {
      await play(a);
      engine.advance(ms300);
      piano.beginHandOver(lead: ms500);
      await play(b, handOver: true);
      engine.advance(const Duration(milliseconds: 200));
      final made = mixer.tailsOf.length;
      await piano.stop();
      final t1 = engine.now + const Duration(milliseconds: 1);
      expect(
        engine.voices.values.where(
          (v) => v.name == 'piano-loop.wav' && v.soundsAt(t1),
        ),
        isEmpty,
        reason: 'the old loop plays on after the stop',
      );
      // Let go where it is, at the level it was let down to by then.
      expect(mixer.tailsOf.sublist(made), [
        [a],
      ], reason: 'the tail of a loop never heard');
      final tail = engine.voices.values.last;
      expect(tail.name, 'tail.wav');
      expect(tail.soundsAt(t1), isTrue);
      expect(tail.volumeAt(t1), lessThan(0.8));
      expect(heard(engine, const Duration(milliseconds: 2100)), '');
    });
  });

  group('the metronome stops at once while it waits for the piano', () {
    test('clicks waiting for a meeting that never comes stop at once, '
        'and nothing starts after', () async {
      final engine = FakeLoopEngine();
      final transport = LoopTransport(engine: engine);
      final click = BarLoopPlayer('click', transport: transport);
      final piano = BarLoopPlayer('piano', transport: transport);
      await click.play(fakeWav(bar), bar);
      await piano.play(fakeWav(bar * 4), bar, startAt: Duration.zero);
      engine.advance(bar + ms300);
      // A new song: the piano begins to hand over, and its new loop never
      // comes (being made, slowly).
      piano.beginHandOver(lead: ms500);
      Object? ended;
      final waiting = click
          .play(fakeWav(bar), bar, startAt: Duration.zero, atMeeting: true)
          .then<void>(
            (_) => ended = 'played',
            onError: (Object e) => ended = e,
          );
      await Future<void>.delayed(Duration.zero);
      await click.stop();
      await waiting.timeout(
        const Duration(seconds: 1),
        onTimeout: () => ended = 'still waiting',
      );
      expect(ended, isA<LoopNotWanted>());
      expect(engine.playing('click-loop.wav'), isEmpty);
      expect(click.isPlaying, isFalse);
      await piano.stop();
    });

    test('Stop does not queue behind a start that waits', () async {
      final click = _WaitingClick();
      final metronome = MetronomeController(click);
      final started = metronome.start();
      await Future<void>.delayed(Duration.zero);
      final stopped = metronome.stop();
      await Future<void>.delayed(Duration.zero);
      expect(click.stops, greaterThan(0), reason: 'the stop waits its turn');
      await Future.wait([started, stopped]);
      expect(metronome.isPlaying, isFalse);
      expect(metronome.audioFailed, isFalse);
    });
  });
}
