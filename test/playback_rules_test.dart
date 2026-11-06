import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/background_audio.dart';
import 'package:low_end/app/playback_rules.dart';
import 'package:low_end/audio/sound_section.dart';

/// The rules between the sections (RF-ACC-08, RF-BG-01, RF-BG-02), without
/// mounting the app: a section is a switch, the notification a list.
void main() {
  late _Section drone, metronome, player;
  late _Shown shown;
  late NowPlayingNotification notification;
  late PauseRules rules;

  setUp(() {
    drone = _Section();
    metronome = _Section();
    player = _Section();
    shown = _Shown();
    notification = NowPlayingNotification(
      drone: drone,
      metronome: metronome,
      player: player,
      background: shown,
      describe: () => [
        if (metronome.isPlaying) 'Metronome 120 BPM · 4/4',
        if (drone.isPlaying) 'Harmony A major',
        if (player.isPlaying) 'Song\nPlayer',
      ].join('\n'),
      playingTitle: () => 'Playing',
      appTitle: () => 'Low End',
    );
    void update() => notification.update();
    drone.onChange = update;
    metronome.onChange = update;
    player.onChange = update;
    rules = PauseRules(
      drone: drone,
      metronome: metronome,
      player: player,
      notification: notification,
    );
  });

  group('the notification', () {
    test('is there while a section plays, with what plays', () {
      metronome.start();
      expect(notification.state, MediaState.playing);
      expect(shown.last, (
        MediaState.playing,
        'Metronome 120 BPM · 4/4',
        'Low End',
      ));
      drone.start();
      expect(shown.last.$3, 'Harmony A major');
      metronome.stop();
      drone.stop();
      expect(notification.state, MediaState.off);
    });

    test('pauses and plays again what it paused', () {
      drone.start();
      metronome.start();
      notification.command(MediaCommand.pause);
      expect(drone.isPlaying || metronome.isPlaying, isFalse);
      expect(notification.state, MediaState.paused);
      // Paused, it keeps saying what played.
      expect(shown.last.$2, 'Metronome 120 BPM · 4/4');
      notification.command(MediaCommand.play);
      expect(drone.isPlaying && metronome.isPlaying, isTrue);
      expect(notification.state, MediaState.playing);
    });

    test('play does nothing unless it paused', () {
      notification.command(MediaCommand.play);
      expect(drone.isPlaying || metronome.isPlaying, isFalse);
      metronome.start();
      metronome.stop();
      notification.command(MediaCommand.play);
      expect(metronome.isPlaying, isFalse);
    });

    test('stop takes it away, paused or not', () {
      drone.start();
      notification.command(MediaCommand.pause);
      notification.command(MediaCommand.stop);
      expect(notification.state, MediaState.off);
      expect(shown.last.$1, MediaState.off);
      notification.command(MediaCommand.play);
      expect(drone.isPlaying, isFalse);
    });

    test('a section started from the app forgets the pause', () {
      drone.start();
      notification.command(MediaCommand.pause);
      metronome.start();
      metronome.stop();
      expect(notification.state, MediaState.off);
    });

    test('a new text shows, the same one does not show again', () {
      metronome.start();
      final count = shown.calls.length;
      notification.update();
      expect(shown.calls.length, count);
      notification.refresh();
      expect(shown.calls.length, count);
    });
  });

  group('the sound pauses by itself', () {
    test('for the tuner, and plays again only what it stopped', () {
      metronome.start();
      final paused = rules.tunerChanged(listening: true)!;
      expect(paused.why, PauseReason.tuner);
      expect((paused.drone, paused.metronome), (false, true));
      expect(metronome.isPlaying, isFalse);
      // Not a pause of the notification: it goes.
      expect(notification.state, MediaState.off);
      rules.resume(paused);
      expect(metronome.isPlaying, isTrue);
      expect(drone.isPlaying, isFalse);
    });

    test('the tuner stopping, or nothing playing, pauses nothing', () {
      expect(rules.tunerChanged(listening: true), isNull);
      drone.start();
      expect(rules.tunerChanged(listening: false), isNull);
      expect(drone.isPlaying, isTrue);
    });

    test('headphones pulled out leave the notification paused', () {
      drone.start();
      final paused = rules.pauseFor(PauseReason.unplugged)!;
      expect(drone.isPlaying, isFalse);
      expect(notification.state, MediaState.paused);
      notification.command(MediaCommand.play);
      expect(drone.isPlaying, isTrue);
      expect(paused.drone, isTrue);
    });

    test('an interruption stops it, the notification goes', () {
      drone.start();
      metronome.start();
      rules.pauseFor(PauseReason.interrupted);
      expect(drone.isPlaying || metronome.isPlaying, isFalse);
      expect(notification.state, MediaState.off);
    });

    test('resume leaves alone what already plays again', () {
      drone.start();
      final paused = rules.pauseFor(PauseReason.tuner)!;
      drone.start();
      final starts = drone.starts;
      rules.resume(paused);
      expect(drone.starts, starts);
    });
  });
  // RF-PLY-04, RF-PLY-05: the Player is the third section.
  group('the Player', () {
    test('is in the notification, with the track and who plays it', () {
      player.start();
      expect(notification.state, MediaState.playing);
      expect(shown.last, (MediaState.playing, 'Song', 'Player'));
      notification.command(MediaCommand.pause);
      expect(player.isPlaying, isFalse);
      expect(notification.state, MediaState.paused);
      notification.command(MediaCommand.play);
      expect(player.isPlaying, isTrue);
      notification.command(MediaCommand.stop);
      expect(player.isPlaying, isFalse);
      expect(notification.state, MediaState.off);
    });

    test('starting pauses the metronome and Harmony, not itself', () {
      drone.start();
      metronome.start();
      player.start();
      final paused = rules.pauseFor(PauseReason.player)!;
      expect(paused.why, PauseReason.player);
      expect(
        (paused.drone, paused.metronome, paused.player),
        (true, true, false),
      );
      expect(drone.isPlaying || metronome.isPlaying, isFalse);
      expect(player.isPlaying, isTrue);
      // The button of the notice plays them again.
      rules.resume(paused);
      expect(drone.isPlaying && metronome.isPlaying, isTrue);
    });

    test('with nothing else playing, starting pauses nothing', () {
      player.start();
      expect(rules.pauseFor(PauseReason.player), isNull);
      expect(player.isPlaying, isTrue);
    });

    test('the tuner listening, a call and headphones pause it too', () {
      player.start();
      var paused = rules.tunerChanged(listening: true)!;
      expect(paused.player, isTrue);
      expect(player.isPlaying, isFalse);
      rules.resume(paused);
      expect(player.isPlaying, isTrue);
      paused = rules.pauseFor(PauseReason.interrupted)!;
      expect(player.isPlaying, isFalse);
      expect(notification.state, MediaState.off);
      rules.resume(paused);
      rules.pauseFor(PauseReason.unplugged);
      expect(player.isPlaying, isFalse);
      expect(notification.state, MediaState.paused);
      notification.command(MediaCommand.play);
      expect(player.isPlaying, isTrue);
    });
  });
}

class _Section implements SoundSection {
  var _playing = false;
  var starts = 0;
  void Function() onChange = () {};

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> start() async {
    starts++;
    _playing = true;
    onChange();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    onChange();
  }
}

class _Shown implements BackgroundAudio {
  final calls = <(MediaState, String, String)>[];

  (MediaState, String, String) get last => calls.last;

  @override
  Stream<MediaCommand> get commands => const Stream.empty();

  @override
  Future<void> show(
    MediaState state, {
    required String title,
    String text = '',
  }) async => calls.add((state, title, text));
}
