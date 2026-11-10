import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'loop_engine.dart';

/// Which looping bar is playing, so that a second one starting while the
/// first plays comes in on its "one" instead of at a random point: the
/// metronome's clicks and the piano's chords are two loops of the same
/// length (or of a whole number of bars), and must stay together.
class LoopTransport {
  /// A transport of its own, on [engine]: for tests on a fake engine.
  LoopTransport({this.engine = LoopEngine.soloud});

  /// The one the app's loops share.
  static final instance = LoopTransport();

  final LoopEngine engine;

  final _loops = <String, _Loop>{};

  /// The engine time of the bar line a hand-over aims at (see
  /// BarLoopPlayer.beginHandOver), while one is under way, and once the
  /// piano's new loop is scheduled, the time it really comes in: a new
  /// song changes the piano and the clicks together there, and the
  /// metronome keeps going at its old tempo, let down, until then
  /// (RF-ARM-15).
  Duration? meetAt;

  Completer<Duration?>? _meeting;

  /// A hand-over aims at [at]: the clicks wait for the piano's new loop.
  void beginMeeting(Duration at) {
    meetAt = at;
    _meeting ??= Completer<Duration?>();
  }

  /// The piano's new loop is scheduled to come in at [startsAt] (later than
  /// aimed when its mix took longer than the wait): the clicks come in
  /// there too.
  void meet(Duration startsAt) {
    meetAt = startsAt;
    _meeting?.complete(startsAt);
    _meeting = null;
  }

  /// The hand-over was called off, or the piano stopped: nothing to wait
  /// for.
  void cancelMeeting() {
    meetAt = null;
    _meeting?.complete(null);
    _meeting = null;
  }

  /// The bar line clicks asked to meet the piano (see BarLoopPlayer.play
  /// with atMeeting) aim at: while a hand-over is under way, or its new
  /// loop is still to come in. Null once it has come in: a later change
  /// that the piano does not hand over has nothing to meet.
  Duration? get meetingAt {
    final at = meetAt;
    if (at == null) return null;
    if (_meeting != null || at > engine.getEngineTime()) return at;
    return null;
  }

  /// When the piano's new loop comes in, once it is known; null if the
  /// hand-over was called off.
  Future<Duration?> get meeting => _meeting?.future ?? Future.value(meetAt);

  LoopEngine get _soloud => engine;

  /// Notes that the loop [name], playing as [handle], has bars of [bar].
  /// [startsAt], the engine time (see SoLoud.getEngineTime) it was
  /// scheduled to start at, if it was: until then the voice reports no
  /// position, and its bar lines are counted from that time instead.
  void register(
    String name,
    SoundHandle handle,
    Duration bar, {
    Duration? startsAt,
  }) => _loops[name] = _Loop(handle, bar, startsAt);

  void unregister(String name, SoundHandle? handle) {
    if (handle != null && _loops[name]?.handle == handle) _loops.remove(name);
  }

  /// Time until the next bar line of a loop other than [name], or null if
  /// no other loop is playing. Never less than [minimum], so that there is
  /// time to schedule a start: a bar line too close is skipped.
  Duration? untilBarLine(
    String name, {
    Duration minimum = const Duration(milliseconds: 60),
  }) {
    final place = _placeOfOther(name);
    if (place == null) return null;
    return waitForBarLine(
      bar: place.bar,
      position: place.position,
      untilStart: place.untilStart,
      minimum: minimum,
    );
  }

  /// How far into its bar a loop other than [name] is, from 0 to just under
  /// 1, or null if no other loop is playing.
  double? phaseOf(String name) {
    final place = _placeOfOther(name);
    if (place == null) return null;
    final bar = place.bar.inMicroseconds;
    final at = place.untilStart != null
        ? -place.untilStart!.inMicroseconds
        : place.position!.inMicroseconds;
    return (at % bar) / bar;
  }

  /// Where the other loop is: its bar, and either its position in the loop
  /// or, when it is scheduled and not yet sounding, the time until it does.
  ({Duration bar, Duration? position, Duration? untilStart})? _placeOfOther(
    String name,
  ) {
    for (final e in _loops.entries) {
      if (e.key == name) continue;
      final loop = e.value;
      try {
        if (!_soloud.getIsValidVoiceHandle(loop.handle)) continue;
        final startsAt = loop.startsAt;
        if (startsAt != null) {
          final until = startsAt - _soloud.getEngineTime();
          if (until > Duration.zero) {
            return (bar: loop.bar, position: null, untilStart: until);
          }
        }
        return (
          bar: loop.bar,
          position: _soloud.getPosition(loop.handle),
          untilStart: null,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Time until the next bar line of a loop with bars of [bar], [position]
  /// into it, or [untilStart] away from starting; at least [minimum].
  static Duration waitForBarLine({
    required Duration bar,
    Duration? position,
    Duration? untilStart,
    Duration minimum = const Duration(milliseconds: 60),
  }) {
    var wait =
        untilStart ??
        Duration(
          microseconds:
              bar.inMicroseconds -
              position!.inMicroseconds % bar.inMicroseconds,
        );
    while (wait < minimum) {
      wait += bar;
    }
    return wait;
  }

  /// Where a loop of [bars] bars of [bar] picks up when it replaces one with
  /// bars of [oldBar] that is [oldPosition] in, while the loop it follows
  /// is [leaderPhase] into its bar: in the same bar as before (or the next
  /// or the one before, when the two had drifted across a bar line), at the
  /// leader's place in it. So after a change of tempo the piano comes back
  /// on the click's beat, however long it took to get ready.
  static Duration followerPosition({
    required Duration oldPosition,
    required Duration oldBar,
    required Duration bar,
    required int bars,
    required double leaderPhase,
  }) {
    final inBars = oldPosition.inMicroseconds / oldBar.inMicroseconds;
    var index = inBars.floor();
    final own = inBars - index;
    // Nearer the leader's bar line on the other side: that bar is meant.
    if (leaderPhase - own > 0.5) index -= 1;
    if (own - leaderPhase > 0.5) index += 1;
    index %= bars;
    return Duration(
      microseconds: ((index + leaderPhase) * bar.inMicroseconds).round(),
    );
  }
}

class _Loop {
  const _Loop(this.handle, this.bar, this.startsAt);

  final SoundHandle handle;
  final Duration bar;
  final Duration? startsAt;
}

/// Where a loop actually began: `position` into the loop at the moment it
/// started to sound, and `delay`, how long from the call that was, when it
/// had to wait for the other loop's next bar line.
typedef LoopStart = ({Duration position, Duration delay});
