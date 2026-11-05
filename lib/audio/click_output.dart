import 'package:flutter/foundation.dart';

import 'bar_loop_player.dart';
import 'click_sound.dart';
import 'loop_transport.dart';

/// Loops one bar of metronome clicks.
///
/// Kept behind an interface so the rest of the app can be tested without a
/// real audio device.
abstract class ClickOutput {
  /// Starts looping [barWav] (see ClickSound.bar), replacing the bar
  /// already playing, if any.
  ///
  /// With no [startAt], a bar replacing another carries on from where the
  /// old one was (scaled to its own length), as a tempo change should, and
  /// the piano does the same. With one, it starts that far into the bar; if
  /// the piano is playing it then waits for the piano's next bar line, so
  /// the two stay together. Says where and when it began.
  ///
  /// [atMeeting], with a [startAt], while the piano hands over to a new
  /// loop: the new bar comes in on the bar line where the piano's does, the
  /// old one clicking on until then.
  Future<LoopStart> play(
    Uint8List barWav, {
    Duration? startAt,
    bool atMeeting = false,
  });

  Future<void> stop();
}

/// [ClickOutput] backed by the SoLoud audio engine.
class SoLoudClickOutput implements ClickOutput {
  final _player = BarLoopPlayer('click');

  @override
  Future<LoopStart> play(
    Uint8List barWav, {
    Duration? startAt,
    bool atMeeting = false,
  }) {
    // The loop is one bar long.
    final bar = Duration(
      microseconds:
          (barWav.length - 44) ~/ 2 * 1000000 ~/ ClickSound.sampleRate,
    );
    return _player.play(
      barWav,
      bar,
      startAt: startAt,
      preRoll: preRollFor(barWav),
      atMeeting: atMeeting,
    );
  }

  /// How long of the silence at the end of the bar to play before its first
  /// stroke when starting: the phone's speaker takes a moment to come up at
  /// the start of a sound, and a first beat that begins at once is
  /// sometimes too soft. At most 120 ms, and never into a stroke.
  @visibleForTesting
  static Duration preRollFor(Uint8List barWav) {
    var silent = 0;
    // 16-bit samples, from the end; the first bytes are the header.
    for (var i = barWav.length - 2; i >= 44; i -= 2) {
      if (barWav[i] != 0 || barWav[i + 1] != 0) break;
      silent++;
    }
    final room = Duration(
      microseconds: silent * 1000000 ~/ ClickSound.sampleRate,
    );
    final usable = room - const Duration(milliseconds: 20);
    const most = Duration(milliseconds: 120);
    if (usable <= Duration.zero) return Duration.zero;
    return usable < most ? usable : most;
  }

  @override
  Future<void> stop() => _player.stop();
}

/// [ClickOutput] that makes no sound; used where audio is unavailable.
@visibleForTesting
class SilentClickOutput implements ClickOutput {
  /// The bar playing now, or null when stopped.
  Uint8List? bar;
  Duration? startAt;
  var plays = 0;

  /// Whether the last bar was asked to come in with the piano's new loop.
  var atMeeting = false;

  /// How long the next start waits, as if the piano were playing.
  Duration delay = Duration.zero;

  @override
  Future<LoopStart> play(
    Uint8List barWav, {
    Duration? startAt,
    bool atMeeting = false,
  }) async {
    bar = barWav;
    this.startAt = startAt;
    this.atMeeting = atMeeting;
    plays++;
    return (position: startAt ?? Duration.zero, delay: delay);
  }

  @override
  Future<void> stop() async => bar = null;
}
