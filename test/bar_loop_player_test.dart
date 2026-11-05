import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/bar_loop_player.dart';
import 'package:low_end/audio/loop_transport.dart';

import 'fake_loop_engine.dart';

/// The looping bars on an engine with its own clock (RF-ARM-15, RF-MET-08,
/// RF-ACC-02): a loop replaced, an entry on the other loop's bar line, the
/// tail of a loop let go, the fades of a hand-over and of a new tempo.
void main() {
  const bar = Duration(seconds: 2);
  Duration ms(int n) => Duration(milliseconds: n);
  late FakeLoopEngine engine;
  late BarLoopPlayer click, piano;

  setUp(() {
    engine = FakeLoopEngine();
    final transport = LoopTransport(engine: engine);
    click = BarLoopPlayer('click', transport: transport);
    piano = BarLoopPlayer(
      'piano',
      follows: true,
      crossfade: const Duration(milliseconds: 200),
      transport: transport,
    );
  });

  FakeVoice only(String name) {
    final all = engine.playing(name).toList();
    expect(all, hasLength(1), reason: name);
    return all.single;
  }

  test('a loop alone starts at once and goes round', () async {
    final start = await click.play(fakeWav(bar), bar);
    expect(start.delay, _near(Duration.zero));
    final voice = only('click-loop.wav');
    expect(voice.soundsAt(engine.now), isTrue);
    engine.advance(bar + ms(500));
    expect(voice.positionAt(engine.now), ms(500));
  });

  test('the second loop comes in on the first one\'s bar line', () async {
    await click.play(fakeWav(bar), bar);
    engine.advance(ms(1500));
    final start = await piano.play(
      fakeWav(bar * 4),
      bar,
      startAt: Duration.zero,
    );
    expect(start.delay, _near(ms(500)));
    final voice = only('piano-loop.wav');
    expect(voice.startsAt, bar);
    expect(voice.soundsAt(engine.now), isFalse);
    engine.advance(ms(500));
    expect(voice.soundsAt(engine.now), isTrue);
  });

  test('a bar line too close to schedule is skipped', () async {
    await click.play(fakeWav(bar), bar);
    engine.advance(bar - ms(20));
    final start = await piano.play(fakeWav(bar), bar, startAt: Duration.zero);
    expect(start.delay, _near(bar + ms(20)));
  });

  test('a new loop from its start replaces the old on the bar line, '
      'its tail playing from there', () async {
    await click.play(fakeWav(bar), bar);
    await piano.play(fakeWav(bar * 4), bar, startAt: Duration.zero);
    engine.advance(bar + ms(700));
    final old = only('piano-loop.wav');
    final asked = <Duration>[];
    await piano.play(
      fakeWav(bar * 4),
      bar,
      startAt: Duration.zero,
      tailFor: (at) async {
        asked.add(at);
        return fakeWav(const Duration(seconds: 3));
      },
    );
    final line = bar * 2;
    // The old one stops at the very sample the new one comes in.
    expect(old.stopsAt, line);
    final fresh = engine.voices.values.where(
      (v) => v.name == 'piano-loop.wav' && v != old,
    );
    expect(fresh.single.startsAt, line);
    // Its tail starts there too, made for where the old loop is by then.
    expect(asked, [bar]);
    final tail = engine.voices.values.singleWhere((v) => v.name == 'tail.wav');
    expect(tail.startsAt, line);
    expect(tail.volumeAt(line), 1);
  });

  test('a tail made too slowly is dropped, the next bar line taken', () async {
    await click.play(fakeWav(bar), bar);
    await piano.play(fakeWav(bar), bar, startAt: Duration.zero);
    engine.advance(bar + ms(1800));
    final start = await piano.play(
      fakeWav(bar),
      bar,
      startAt: Duration.zero,
      tailFor: (_) async {
        // The bar line goes by while the tail is made.
        engine.advance(ms(300));
        return fakeWav(bar);
      },
    );
    expect(engine.voices.values.where((v) => v.name == 'tail.wav'), isEmpty);
    expect(engine.loaded.where((n) => n == 'tail.wav'), hasLength(1));
    expect(engine.disposed, hasLength(1));
    final voices = engine.voices.values
        .where((v) => v.name == 'piano-loop.wav')
        .toList();
    expect(voices.last.startsAt, bar * 3);
    expect(voices.first.stopsAt, bar * 3);
    expect(start.delay, _near(bar * 3 - engine.now));
  });

  test('a hand-over lets the old loop down to the bar line, '
      'where the new one comes in', () async {
    await click.play(fakeWav(bar), bar);
    await piano.play(fakeWav(bar), bar, startAt: Duration.zero);
    engine.advance(bar + ms(400));
    final old = only('piano-loop.wav');
    final wait = piano.beginHandOver(lead: ms(500))!;
    expect(wait, ms(1600));
    final line = engine.now + wait;
    expect(old.volumeAt(line), closeTo(BarLoopPlayer.handOverLevel, 1e-9));
    // Asked again, the same bar line.
    engine.advance(ms(400));
    expect(piano.beginHandOver(lead: ms(500)), ms(1200));
    await piano.play(
      fakeWav(bar),
      bar,
      startAt: Duration.zero,
      handOver: true,
      tailFor: (_) async => fakeWav(bar),
    );
    expect(old.stopsAt, line);
    final tail = engine.voices.values.singleWhere((v) => v.name == 'tail.wav');
    expect(tail.startsAt, line);
    expect(tail.volumeAt(line), closeTo(BarLoopPlayer.handOverLevel, 1e-9));
  });

  test('clicks asked to meet the piano change on its hand-over bar line, '
      'the old ones clicking until then', () async {
    await click.play(fakeWav(bar), bar);
    await piano.play(fakeWav(bar), bar, startAt: Duration.zero);
    engine.advance(bar + ms(400));
    final oldClick = only('click-loop.wav');
    final wait = piano.beginHandOver(lead: ms(500))!;
    final line = engine.now + wait;
    const faster = Duration(milliseconds: 1500);
    final start = await click.play(
      fakeWav(faster),
      faster,
      startAt: Duration.zero,
      atMeeting: true,
    );
    expect(start.delay, _near(wait));
    final newClick = engine.voices.values.lastWhere(
      (v) => v.name == 'click-loop.wav',
    );
    expect(newClick.startsAt, line);
    expect(oldClick.stopsAt, line);
    expect(oldClick.volumeAt(line), closeTo(BarLoopPlayer.handOverLevel, 1e-9));
    // The piano's new loop comes in on that same bar line.
    await piano.play(
      fakeWav(faster),
      faster,
      startAt: Duration.zero,
      handOver: true,
    );
    final newPiano = engine.voices.values.lastWhere(
      (v) => v.name == 'piano-loop.wav',
    );
    expect(newPiano.startsAt, line);
  });

  test('a hand-over called off brings the loop back up', () async {
    await piano.play(fakeWav(bar), bar);
    engine.advance(ms(300));
    final voice = only('piano-loop.wav');
    piano.beginHandOver(lead: ms(500));
    engine.advance(ms(850));
    expect(voice.volumeAt(engine.now), lessThan(1));
    piano.cancelHandOver();
    engine.advance(ms(300));
    expect(voice.volumeAt(engine.now), 1);
    expect(voice.stopsAt, isNull);
  });

  test('a new tempo carries on, the two loops crossing over', () async {
    await piano.play(fakeWav(bar), bar);
    engine.advance(ms(500));
    final old = only('piano-loop.wav');
    const faster = Duration(milliseconds: 1600);
    final start = await piano.play(fakeWav(faster), faster);
    // A quarter of the bar in, as before.
    expect(start.position, ms(400));
    final fresh = engine.voices.values.last;
    expect(fresh.volumeAt(engine.now), 0);
    engine.advance(ms(200));
    expect(fresh.volumeAt(engine.now), 1);
    expect(old.volumeAt(engine.now), 0);
    expect(old.isValidAt(engine.now), isFalse);
  });

  test('a new chord carrying on waits for the next pulse', () async {
    await piano.play(fakeWav(bar), bar);
    engine.advance(ms(600));
    final old = only('piano-loop.wav');
    await piano.play(fakeWav(bar), bar, onPulse: ms(500));
    final fresh = engine.voices.values.last;
    // The pulse at 1 s, 400 ms away: the old one gives way 10 ms before.
    final pulse = engine.now + ms(400);
    expect(old.isValidAt(pulse - ms(20)), isTrue);
    expect(old.isValidAt(pulse), isFalse);
    expect(fresh.volumeAt(pulse - ms(20)), 0);
    expect(fresh.volumeAt(pulse), 1);
  });

  test('stopped with a tail, the tail plays on from where it was', () async {
    await piano.play(fakeWav(bar), bar);
    engine.advance(ms(700));
    final voice = only('piano-loop.wav');
    Duration? asked;
    await piano.stop(
      tailFor: (at) async {
        asked = at;
        return fakeWav(const Duration(seconds: 3));
      },
    );
    expect(asked, ms(700));
    expect(voice.isValidAt(engine.now), isFalse);
    expect(piano.isPlaying, isFalse);
    final tail = engine.voices.values.singleWhere((v) => v.name == 'tail.wav');
    expect(tail.soundsAt(engine.now), isTrue);
    expect(engine.disposed, isNotEmpty);
  });

  test('the volume is kept for the loops that follow', () async {
    piano.setVolume(0.5);
    await piano.play(fakeWav(bar), bar);
    expect(only('piano-loop.wav').volumeAt(engine.now), 0.5);
    piano.setVolume(0.8);
    expect(only('piano-loop.wav').volumeAt(engine.now), 0.8);
  });

  test('the fake reads the length from the header', () async {
    final source = await engine.loadMem('x', fakeWav(bar));
    expect(engine.getLength(source), bar);
  });
}

/// Within a few milliseconds of [time]: the delay is counted from when
/// [BarLoopPlayer.play] returns, on the phone's own clock.
Matcher _near(Duration time) => predicate<Duration>(
  (d) => (d - time).abs() < const Duration(milliseconds: 5),
  'within 5 ms of $time',
);
