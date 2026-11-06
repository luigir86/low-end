// The Player's rules (RF-PLY-01, RF-PLY-02, RF-PLY-06, RF-PLY-07), without
// a phone: a silent output that plays by being told the time, and a chooser
// that gives what it is told to.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/player/player_controller.dart';

const _song = TrackRef(uri: 'content://song', name: 'Blue Bossa.mp3');
const _other = TrackRef(uri: 'content://other', name: 'Other.m4a');

/// An output that opens only when told to, for answers that come late.
class _SlowOutput extends SilentTrackOutput {
  final opens = <Completer<Duration>>[];

  @override
  Future<Duration> open(TrackRef track, {Duration at = Duration.zero}) async {
    opened = track;
    final answer = Completer<Duration>();
    opens.add(answer);
    return answer.future;
  }
}

void main() {
  late SilentTrackOutput output;
  late FakeTrackFiles files;
  late PlayerController player;

  setUp(() {
    output = SilentTrackOutput();
    files = FakeTrackFiles(next: _song);
    player = PlayerController(output, files);
  });

  tearDown(() => player.dispose());

  group('choosing and opening a track', () {
    test('starts empty and creates nothing', () {
      expect(player.status, PlayerStatus.empty);
      expect(player.track, isNull);
      expect(player.isPlaying, isFalse);
      expect(player.position, Duration.zero);
      expect(output.openCount, 0);
    });

    test('the chooser is asked first, in the touch (RF-PLY-01)', () {
      // Nothing awaited before it: a web page allows the chooser only so.
      player.pick();
      expect(files.picks, 1);
    });

    test('a track chosen opens, ready to play, not playing', () async {
      await player.pick();
      expect(player.status, PlayerStatus.ready);
      expect(player.track, _song);
      expect(player.title, 'Blue Bossa');
      expect(player.duration, output.length);
      expect(player.isPlaying, isFalse);
      expect(output.opened, _song);
      expect(output.playing, isFalse);
    });

    test('a chooser closed with no choice changes nothing', () async {
      await player.pick();
      files.next = null;
      await player.pick();
      expect(player.track, _song);
      expect(output.openCount, 1);
    });

    test('another track lets the first go; the same one does not', () async {
      await player.pick();
      files.next = _other;
      await player.pick();
      expect(files.released, [_song]);
      expect(player.track, _other);
      await player.open(_other);
      expect(files.released, [_song]);
    });

    test(
      'a track that cannot be played leaves it empty and says why',
      () async {
        output.failWith = TrackOpenException(TrackProblem.unreadable);
        await player.pick();
        expect(player.status, PlayerStatus.empty);
        expect(player.track, isNull);
        expect(player.problem, TrackProblem.unreadable);
        expect(files.released, [_song]);
        // Choosing another clears the message.
        await player.pick();
        expect(player.problem, isNull);
        expect(player.status, PlayerStatus.ready);
      },
    );

    test('a file that is gone says so, and the app does not stop', () async {
      output.failWith = TrackOpenException(TrackProblem.missing);
      await player.pick();
      expect(player.problem, TrackProblem.missing);
      output.failWith = null;
      await player.open(_other);
      expect(player.status, PlayerStatus.ready);
    });

    test('any other failure is a file that cannot be opened', () async {
      final broken = _Throwing();
      final p = PlayerController(broken, files);
      await p.open(_song);
      expect(p.problem, TrackProblem.unreadable);
      expect(p.status, PlayerStatus.empty);
      p.dispose();
    });

    test('an answer from a track chosen before is ignored', () async {
      final slow = _SlowOutput();
      final p = PlayerController(slow, files);
      final first = p.open(_song);
      final second = p.open(_other);
      expect(p.status, PlayerStatus.opening);
      // The first answers last, with a different length.
      slow.opens[1].complete(const Duration(minutes: 3));
      await second;
      slow.opens[0].complete(const Duration(minutes: 9));
      await first;
      expect(p.track, _other);
      expect(p.duration, const Duration(minutes: 3));
      p.dispose();
    });
  });

  group('playing', () {
    setUp(() => player.pick());

    test('start and pause, the position stays (RF-PLY-02)', () async {
      await player.start();
      expect(player.isPlaying, isTrue);
      expect(output.playing, isTrue);
      output.advance(const Duration(seconds: 42));
      expect(player.position, const Duration(seconds: 42));

      await player.stop();
      expect(player.isPlaying, isFalse);
      expect(output.playing, isFalse);
      expect(player.position, const Duration(seconds: 42));

      await player.toggle();
      expect(player.isPlaying, isTrue);
      await player.toggle();
      expect(player.isPlaying, isFalse);
    });

    test('playing is true at once, and tells the listeners', () {
      var notified = 0;
      player.addListener(() => notified++);
      player.start();
      expect(player.isPlaying, isTrue);
      expect(notified, 1);
    });

    test('without a track, start does nothing', () async {
      final empty = PlayerController(SilentTrackOutput(), files);
      await empty.start();
      expect(empty.isPlaying, isFalse);
      empty.dispose();
    });

    test(
      'a start asked while the track opens plays when it is ready',
      () async {
        final slow = _SlowOutput();
        final p = PlayerController(slow, files);
        final opening = p.open(_song);
        await p.start();
        expect(p.isPlaying, isTrue);
        expect(slow.playing, isFalse);
        slow.opens.single.complete(const Duration(minutes: 3));
        await opening;
        expect(slow.playing, isTrue);
        p.dispose();
      },
    );

    test('seek moves within the track, and not outside it', () async {
      await player.seek(const Duration(minutes: 2));
      expect(player.position, const Duration(minutes: 2));
      await player.seek(const Duration(minutes: 99));
      expect(player.position, output.length);
      await player.seek(const Duration(seconds: -5));
      expect(player.position, Duration.zero);
      expect(output.seeks.last, Duration.zero);
    });

    test('seek tells the listeners, so the dial moves while paused', () async {
      var notified = 0;
      player.addListener(() => notified++);
      await player.seek(const Duration(seconds: 10));
      expect(notified, 1);
    });

    test('seek does nothing without a track', () async {
      final empty = PlayerController(SilentTrackOutput(), files);
      await empty.seek(const Duration(seconds: 10));
      expect(empty.position, Duration.zero);
      empty.dispose();
    });

    test(
      'at the end it stops and goes back to the start (RF-PLY-06)',
      () async {
        await player.start();
        await player.seek(output.length - const Duration(seconds: 1));
        var notified = 0;
        player.addListener(() => notified++);
        output.advance(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        expect(player.isPlaying, isFalse);
        expect(player.position, Duration.zero);
        expect(notified, 1);
      },
    );

    test('a track that was playing stops when another is chosen', () async {
      await player.start();
      files.next = _other;
      await player.pick();
      expect(player.isPlaying, isFalse);
      expect(output.playing, isFalse);
      expect(player.position, Duration.zero);
    });

    test('a call or another player is told to the listeners', () async {
      var interrupted = 0;
      player.interruptions.listen((_) => interrupted++);
      output.interrupt();
      await Future<void>.delayed(Duration.zero);
      expect(interrupted, 1);
    });

    test('the message about a file is cleared on demand', () async {
      output.failWith = TrackOpenException(TrackProblem.unreadable);
      await player.open(_other);
      expect(player.problem, isNotNull);
      player.clearProblem();
      expect(player.problem, isNull);
    });
  });

  test('closing lets go of the file and the output', () async {
    await player.pick();
    player.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(output.closed, isTrue);
    expect(files.released, [_song]);
    // tearDown disposes again: a second time must be harmless.
    player = PlayerController(SilentTrackOutput(), files);
  });

  group('the wave of the track (RF-PLY-15)', () {
    Uint16List some(int n) => Uint16List.fromList(List.filled(n, 1000));

    test(
      'there is none before a track, and reading starts when it is ready',
      () async {
        expect(player.peaks, isNull);
        await player.pick();
        expect(files.peaksAsked, [_song]);
        expect(player.peaks, isNotNull);
        expect(player.peaks!.length, 0);
        files.peakStreams.single.add(some(5));
        await Future<void>.delayed(Duration.zero);
        expect(player.peaks!.length, 5);
        await files.peakStreams.single.close();
        await Future<void>.delayed(Duration.zero);
        expect(player.peaks!.complete, isTrue);
      },
    );

    test('a track that cannot be read has no wave and no message', () async {
      await player.pick();
      files.peakStreams.single.addError(StateError('no'));
      await Future<void>.delayed(Duration.zero);
      expect(player.peaks!.failed, isTrue);
      expect(player.problem, isNull);
      expect(player.status, PlayerStatus.ready);
    });

    test('another track stops the first reading before the next begins, and '
        'what the first sends late is not in the second', () async {
      await player.pick();
      final first = player.peaks!;
      files.next = _other;
      await player.pick();
      expect(files.peaksAsked, [_song, _other]);
      expect(files.peaksCancelled, 1);
      expect(identical(player.peaks, first), isFalse);
      files.peakStreams.first.add(some(7));
      files.peakStreams.last.add(some(2));
      await Future<void>.delayed(Duration.zero);
      expect(first.length, 0);
      expect(player.peaks!.length, 2);
    });

    test(
      'a track that fails to open has none, and closing stops reading',
      () async {
        await player.pick();
        output.failWith = TrackOpenException(TrackProblem.unreadable);
        files.next = _other;
        await player.pick();
        expect(player.peaks, isNull);
        expect(files.peaksCancelled, 1);
        files.next = _song;
        await player.pick();
        expect(player.peaks, isNotNull);
        player.dispose();
        expect(files.peaksCancelled, 2);
        // The tearDown disposes again: make a fresh one for it.
        player = PlayerController(output, files);
      },
    );

    test('opening is not held up by the reading', () async {
      // A stream that never says anything.
      await player.pick();
      expect(player.status, PlayerStatus.ready);
      expect(player.peaks!.complete, isFalse);
    });
  });
}

class _Throwing extends SilentTrackOutput {
  @override
  Future<Duration> open(TrackRef track, {Duration at = Duration.zero}) async =>
      throw StateError('no codec');
}
