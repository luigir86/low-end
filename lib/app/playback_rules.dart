import '../audio/sound_section.dart';
import 'background_audio.dart';

/// Why the sound was paused, for the notice that says so.
enum PauseReason { tuner, unplugged, interrupted }

/// What a pause stopped, to play it again from the notice's button.
typedef Paused = ({PauseReason why, bool drone, bool metronome});

/// The media notification that keeps the sound going with the screen off
/// (see [BackgroundAudio]): there while a section plays, and after a pause
/// from it (or from headphones pulled out), paused, to play again from
/// there (RF-BG-01, RF-BG-02).
class NowPlayingNotification {
  NowPlayingNotification({
    required this.drone,
    required this.metronome,
    required this.background,
    required this.describe,
    required this.playingTitle,
    required this.appTitle,
  });

  final SoundSection drone, metronome;
  final BackgroundAudio background;

  /// What plays, one section a line ("Metronome 120 BPM · 4/4").
  final String Function() describe;

  /// The title when nothing can be described, and the second line when
  /// only one section plays: in the player's language at that moment.
  final String Function() playingTitle, appTitle;

  var _shown = MediaState.off;
  var _pausedFromHere = false;
  var _stopping = false;
  var _heldDrone = false, _heldMetronome = false;

  /// What the notification says is playing, kept while it is paused.
  var _nowPlaying = '';
  var _shownText = '';

  MediaState get state => _shown;

  bool get _anyPlaying => drone.isPlaying || metronome.isPlaying;

  /// Brings the notification in line with what plays.
  void update() {
    // Not while its own pause is stopping things: stopping the drone first,
    // with the metronome still sounding, would otherwise look like a
    // restart and forget the pause (and play would do nothing).
    final playing = _anyPlaying;
    if (playing && !_stopping) {
      _pausedFromHere = false;
      _nowPlaying = describe();
    }
    final state = playing
        ? MediaState.playing
        : _pausedFromHere
        ? MediaState.paused
        : MediaState.off;
    // A new tempo, note or chord changes the text, not the state.
    if (state == _shown && _nowPlaying == _shownText) return;
    _shown = state;
    _shownText = _nowPlaying;
    // What plays, and at what tempo, on the first line: that is what the
    // small notification shows beside the play button. The app's name and
    // icon sit in its header, as on a music player.
    final lines = _nowPlaying.split('\n').where((s) => s.isNotEmpty).toList();
    background.show(
      state,
      title: lines.isEmpty ? playingTitle() : lines.first,
      text: lines.length > 1 ? lines[1] : appTitle(),
    );
  }

  /// The language or the note names changed: the text follows.
  void refresh() {
    if (_shown == MediaState.playing) update();
  }

  /// What the notification's buttons (or a headset's) ask for.
  void command(MediaCommand command) {
    switch (command) {
      case MediaCommand.pause:
        if (!_anyPlaying) return;
        pause();
      case MediaCommand.play:
        if (!_pausedFromHere) return;
        if (_heldDrone) drone.start();
        if (_heldMetronome) metronome.start();
      case MediaCommand.stop:
        _pausedFromHere = false;
        drone.stop();
        metronome.stop();
        // Nothing was playing when paused: the notification must go anyway.
        update();
    }
  }

  /// Stops what plays and keeps the notification, paused, to play it again
  /// from there: its pause button, or the headphones pulled out.
  void pause() {
    _heldDrone = drone.isPlaying;
    _heldMetronome = metronome.isPlaying;
    _pausedFromHere = true;
    _stopping = true;
    drone.stop();
    metronome.stop();
    _stopping = false;
    // Shows the paused notification, whatever the stops showed.
    update();
  }
}

/// When the sound pauses by itself: the tuner starts listening (the
/// microphone would hear the click instead of the instrument, RF-ACC-08),
/// the headphones are pulled out (it pauses as a music player does, the
/// notification left paused), or the phone's browser cut the sound (a
/// call, the locked screen).
class PauseRules {
  PauseRules({
    required this.drone,
    required this.metronome,
    required this.notification,
  });

  final SoundSection drone, metronome;
  final NowPlayingNotification notification;

  /// Pauses whatever sounds, for [why]; says what it stopped, to play it
  /// again (see [resume]), or null if nothing was playing.
  Paused? pauseFor(PauseReason why) {
    final d = drone.isPlaying, m = metronome.isPlaying;
    if (!d && !m) return null;
    if (why == PauseReason.unplugged) {
      notification.pause();
    } else {
      if (d) drone.stop();
      if (m) metronome.stop();
    }
    return (why: why, drone: d, metronome: m);
  }

  /// The tuner started or stopped listening: listening, it pauses what
  /// plays.
  Paused? tunerChanged({required bool listening}) =>
      listening ? pauseFor(PauseReason.tuner) : null;

  /// Plays again what [paused] stopped, unless it already plays.
  void resume(Paused paused) {
    if (paused.drone && !drone.isPlaying) drone.start();
    if (paused.metronome && !metronome.isPlaying) metronome.start();
  }
}
