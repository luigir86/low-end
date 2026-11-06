// The Player's rules (RF-PLY-01, RF-PLY-02, RF-PLY-06, RF-PLY-07), without
// a phone: a silent output that plays by being told the time, and a chooser
// that gives what it is told to.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';
import 'package:low_end/features/player/player_controller.dart';
import 'package:low_end/features/player/player_setup.dart';

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

  test(
    'closing lets go of the output, and keeps the right to the file',
    () async {
      await player.pick();
      player.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(output.closed, isTrue);
      // The track is remembered for the next launch (RF-PLY-13).
      expect(files.released, isEmpty);
      // tearDown disposes again: a second time must be harmless.
      player = PlayerController(SilentTrackOutput(), files);
    },
  );

  group('a track remembered from the last launch (RF-PLY-13)', () {
    final setup = PlayerSetup(
      track: _song,
      duration: const Duration(minutes: 5),
      speed: 70,
      loopStart: const Duration(seconds: 60),
      loopEnd: const Duration(seconds: 90),
      looping: true,
      title: 'Blue Bossa',
      artist: 'Kenny Dorham',
    );

    test('comes back with its speed and passage, and asks nothing of the '
        'system', () {
      player.restore(setup);
      expect(player.status, PlayerStatus.ready);
      expect(player.track, _song);
      expect(player.duration, const Duration(minutes: 5));
      expect(player.speed, 70);
      expect(player.loopStart, const Duration(seconds: 60));
      expect(player.looping, isTrue);
      expect(player.title, 'Blue Bossa');
      expect(player.artist, 'Kenny Dorham');
      expect(player.position, Duration.zero);
      expect(output.openCount, 0);
      expect(files.canReadAsked, isEmpty);
      expect(files.tagsAsked, isEmpty);
      expect(files.peaksAsked, isEmpty);
      expect(player.peaks, isNull);
    });

    test('is what the player gives back as its setup', () {
      expect(player.setup, isNull);
      player.restore(setup);
      final back = player.setup!;
      expect(back.toJson(), setup.toJson());
    });

    test('is not restored over a track already there', () async {
      await player.pick();
      player.restore(setup);
      expect(player.track, _song);
      expect(player.speed, 100);
      expect(output.openCount, 1);
    });

    test('is looked at once, when the tab is reached', () async {
      player.restore(setup);
      await player.activate();
      await player.activate();
      expect(files.canReadAsked, [_song]);
      expect(player.status, PlayerStatus.ready);
      // The wave and the tags are read now, the output is still untouched.
      expect(files.peaksAsked, [_song]);
      expect(files.tagsAsked, [_song]);
      expect(output.openCount, 0);
    });

    test('that is gone says so, is let go and forgotten', () async {
      files.readable = false;
      player.restore(setup);
      await player.activate();
      expect(player.status, PlayerStatus.empty);
      expect(player.problem, TrackProblem.missing);
      expect(player.track, isNull);
      expect(player.setup, isNull);
      expect(files.released, [_song]);
      expect(output.openCount, 0);
    });

    test('opens at the first play, at A, with its speed and loop', () async {
      player.restore(setup);
      await player.activate();
      await player.start();
      expect(output.openCount, 1);
      expect(output.opened, _song);
      expect(output.seeks, isEmpty);
      expect(output.speed, 0.7);
      expect(output.loop, (
        const Duration(seconds: 60),
        const Duration(seconds: 90),
      ));
      expect(output.playing, isTrue);
      expect(player.position, const Duration(seconds: 60));
      // A second play does not open it again.
      await player.stop();
      await player.start();
      expect(output.openCount, 1);
    });

    test('opens at the start when there is no loop', () async {
      player.restore(
        PlayerSetup(track: _song, duration: const Duration(minutes: 5)),
      );
      await player.start();
      expect(output.openCount, 1);
      expect(player.position, Duration.zero);
      expect(output.loop, isNull);
    });

    test('opens when the listening point is moved, at that point', () async {
      player.restore(setup);
      await player.seek(const Duration(seconds: 200));
      expect(output.openCount, 1);
      // Outside the loop: the loop goes off, as with any track.
      expect(player.looping, isFalse);
      expect(player.position, const Duration(seconds: 200));
      expect(output.playing, isFalse);
    });

    test('takes the passage and the speed before it is opened, and tells '
        'them when it opens', () async {
      player.restore(
        PlayerSetup(track: _song, duration: const Duration(minutes: 5)),
      );
      player.setSpeed(60);
      await player.setLoop(
        const Duration(seconds: 10),
        const Duration(seconds: 20),
      );
      player.moveEdge(LoopEdge.end, const Duration(seconds: 25));
      expect(output.openCount, 0);
      expect(output.loop, isNull);
      await player.start();
      expect(output.speed, 0.6);
      expect(output.loop, (
        const Duration(seconds: 10),
        const Duration(seconds: 25),
      ));
      expect(player.position, const Duration(seconds: 10));
    });

    test(
      'that cannot be opened at the first play leaves the Player empty',
      () async {
        player.restore(setup);
        output.failWith = TrackOpenException(TrackProblem.unreadable);
        await player.start();
        expect(player.status, PlayerStatus.empty);
        expect(player.problem, TrackProblem.unreadable);
        expect(player.isPlaying, isFalse);
        expect(player.setup, isNull);
      },
    );

    test('a pause while it opens keeps it from playing', () async {
      player.restore(setup);
      final play = player.start();
      await player.stop();
      await play;
      expect(output.playing, isFalse);
    });

    test('a new track starts again at 100% with no loop', () async {
      player.restore(setup);
      await player.pick();
      expect(player.speed, 100);
      expect(player.hasLoop, isFalse);
      expect(player.title, 'Blue Bossa');
      expect(files.released, isEmpty);
    });

    test('a different track lets the remembered one go', () async {
      player.restore(setup);
      files.next = _other;
      await player.pick();
      expect(files.released, [_song]);
    });
  });

  group('the title and the artist (RF-PLY-14)', () {
    test('are the name of the file until the tags say otherwise', () async {
      final gate = Completer<TrackTags>();
      files.tagsFor = (_) => gate.future;
      await player.pick();
      expect(player.title, 'Blue Bossa');
      expect(player.artist, isNull);
      gate.complete((title: ' Blue Bossa (live) ', artist: 'Kenny Dorham'));
      await Future<void>.delayed(Duration.zero);
      expect(player.title, 'Blue Bossa (live)');
      expect(player.artist, 'Kenny Dorham');
    });

    test('tell the listeners, and are kept in the setup', () async {
      var told = 0;
      player.addListener(() => told++);
      files.tagsAnswer = (title: 'Song', artist: null);
      await player.pick();
      await Future<void>.delayed(Duration.zero);
      expect(player.title, 'Song');
      expect(player.setup!.title, 'Song');
      expect(player.setup!.artist, isNull);
      expect(told, greaterThan(1));
    });

    test('empty ones are as none', () async {
      files.tagsAnswer = (title: '  ', artist: '');
      await player.pick();
      await Future<void>.delayed(Duration.zero);
      expect(player.title, 'Blue Bossa');
      expect(player.artist, isNull);
    });

    test('that arrive late for an old track are ignored', () async {
      final gates = <String, Completer<TrackTags>>{};
      files.tagsFor = (track) =>
          (gates[track.uri] = Completer<TrackTags>()).future;
      await player.pick();
      files.next = _other;
      await player.pick();
      gates[_song.uri]!.complete((title: 'Old', artist: 'Old artist'));
      await Future<void>.delayed(Duration.zero);
      expect(player.title, 'Other');
      gates[_other.uri]!.complete((title: 'New', artist: null));
      await Future<void>.delayed(Duration.zero);
      expect(player.title, 'New');
    });

    test('that cannot be read leave the name of the file', () async {
      files.tagsFor = (_) async => throw StateError('no tags');
      await player.pick();
      await Future<void>.delayed(Duration.zero);
      expect(player.title, 'Blue Bossa');
    });
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
