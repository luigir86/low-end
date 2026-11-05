import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'loop_engine.dart';
import 'loop_transport.dart';

/// Plays one looping recording of whole bars with the SoLoud engine: the
/// metronome's clicks, or the piano's chords. Two of them (see [name])
/// keep together through the [LoopTransport].
///
/// Calls are expected one at a time (the controllers wait for each one to
/// finish before the next).
class BarLoopPlayer {
  BarLoopPlayer(
    this.name, {
    this.follows = false,
    this.crossfade = Duration.zero,
    LoopTransport? transport,
  }) : transport = transport ?? LoopTransport.instance;

  /// Keeps this loop with the other one, and holds the engine both play on.
  final LoopTransport transport;

  /// 'click' or 'piano': how the other loop knows this one.
  final String name;

  /// True when this loop keeps to the other's beat after a change of
  /// tempo, rather than carrying on from its own place: the piano, which
  /// takes a moment to get ready, follows the clicks, which change at once.
  final bool follows;

  /// How long a loop replacing another fades in over it when it carries on
  /// (a change of tempo): the piano's ringing notes then pass from one to
  /// the other without a jump. Zero for the clicks, which are short.
  final Duration crossfade;

  /// How long before a pulse the old loop gives way to the new one (see
  /// [play]): enough for no click, short enough to be heard as the beat.
  static const _switchLead = Duration(milliseconds: 10);

  /// How loud a loop handed over to another (see [beginHandOver]) is by the
  /// bar line where the other comes in: it dies away under it from there.
  static const handOverLevel = 1 / 3;

  /// How loud clicks waiting to meet the piano (see [play] with atMeeting)
  /// are let down to: lower than the piano, as a short click stands out
  /// more than a held chord at the same level, so that both are heard to
  /// fade alike (about -15 dB).
  static const meetingLevel = 1 / 6;

  /// The engine time of the bar line a hand-over (see [beginHandOver])
  /// aims at, while one is under way.
  Duration? _handOverAt;

  AudioSource? _source;
  SoundHandle? _handle;
  Duration _length = Duration.zero;
  Duration _bar = Duration.zero;
  double _volume = 1;

  LoopEngine get _soloud => transport.engine;

  bool get isPlaying => _handle != null;

  /// Loops [wav], whose bars last [bar] (the loop is a whole number of
  /// them), replacing the loop already playing, if any.
  ///
  /// With no [startAt], a loop replacing another carries on from where the
  /// old one is, scaled to its own length, as a tempo change should; one
  /// that [follows] picks up at the other loop's place in the bar, if it is
  /// playing. With a [startAt] (or when nothing was playing), it starts
  /// that far in; if the other loop is playing it then waits for that
  /// loop's next bar line, so that the two stay together. Says where and
  /// when it began.
  ///
  /// [preRoll], for a loop that starts on its own, is that much of the end
  /// of the loop, which must be silent, played first: the output comes up
  /// during it, and the first sound is not softened. It counts in the
  /// delay.
  ///
  /// [tailFor], when a new loop replaces one from its start, gives what the
  /// old loop sounds like let go at a place in it (see [stop]); it plays
  /// from the moment the old one stops.
  ///
  /// [onPulse], for a loop that carries on, is the length of its pulse: the
  /// old loop then plays to its next pulse and gives way there, so that a
  /// new chord is struck on the beat instead of fading in between two.
  ///
  /// [handOver], for a loop that starts from [startAt] while another plays,
  /// brings it in on the bar line [beginHandOver] aimed at (or, if that is
  /// too close or gone, on the next one), the old loop let go there at the
  /// level it was let down to.
  ///
  /// [atMeeting], for a loop that starts from [startAt] while the other
  /// one hands over (see [beginHandOver]), comes in where the other's new
  /// loop does, this loop playing on until then, let down with it: the
  /// clicks of a new song change with the piano, not before it, even when
  /// the piano's new loop takes longer than a bar to get ready.
  Future<LoopStart> play(
    Uint8List wav,
    Duration bar, {
    Duration? startAt,
    Duration preRoll = Duration.zero,
    Duration? onPulse,
    Future<Uint8List> Function(Duration position)? tailFor,
    bool handOver = false,
    bool atMeeting = false,
  }) async {
    await _soloud.ensure();
    final source = await _soloud.loadMem('$name-loop.wav', wav);
    final length = _soloud.getLength(source);
    final old = _handle != null && _soloud.getIsValidVoiceHandle(_handle!)
        ? _handle
        : null;
    final oldSource = _source;
    final carryOn = startAt == null && old != null;
    final handingOver = handOver && !carryOn && old != null;
    final aimedAt = _handOverAt;
    _handOverAt = null;
    Duration? wait;
    // Meeting the piano's new loop: let down with the piano by the bar line
    // it aims at, as a band changing song, then wait to hear when it
    // really comes in.
    var meeting = false;
    Duration? met;
    if (atMeeting && !carryOn && old != null) {
      final aimed = transport.meetAt;
      if (aimed != null) {
        meeting = true;
        // Down at once, not along the wait: a click sounds only on the
        // beats, the last one a beat before the bar line, and a slow fade
        // would never be heard.
        _soloud.fadeVolume(old, _volume * meetingLevel, _meetingFade);
        met = await transport.meeting.timeout(
          _meetingLimit,
          onTimeout: () => null,
        );
      }
    }
    final metLeft = met == null ? null : met - _soloud.getEngineTime();
    if (carryOn) {
      wait = null;
    } else if (meeting && metLeft != null && metLeft >= _scheduleLead) {
      wait = metLeft;
    } else if (handingOver) {
      final left = aimedAt == null ? null : aimedAt - _soloud.getEngineTime();
      wait = left != null && left >= _scheduleLead
          ? left
          : _nextBarLine(old, _scheduleLead);
    } else {
      wait = transport.untilBarLine(name);
    }
    // The moment [wait] counts from, and where the old loop was then.
    var waitedFrom = _soloud.getEngineTime();
    final oldThen = old == null ? null : _soloud.getPosition(old);
    final since = Stopwatch()..start();
    var position = startAt ?? Duration.zero;
    var delay = Duration.zero;
    if (carryOn) {
      final was = Duration(
        microseconds:
            _soloud.getPosition(old).inMicroseconds % _length.inMicroseconds,
      );
      final leader = follows ? transport.phaseOf(name) : null;
      if (_bar > Duration.zero) {
        // Back on the other loop's beat: the old loop went on at the old
        // tempo while the new one was made, and drifted from it. With no
        // other loop, the old loop's own place in its bar: the new loop may
        // hold another number of bars (an arpeggio that runs on over
        // several), and must keep the beat all the same.
        position = LoopTransport.followerPosition(
          oldPosition: was,
          oldBar: _bar,
          bar: bar,
          bars: math.max(
            1,
            (length.inMicroseconds / bar.inMicroseconds).round(),
          ),
          leaderPhase:
              leader ??
              (was.inMicroseconds % _bar.inMicroseconds) / _bar.inMicroseconds,
        );
      } else {
        // The old loop's place, as a fraction of its length.
        position = Duration(
          microseconds:
              (was.inMicroseconds *
                      length.inMicroseconds /
                      _length.inMicroseconds)
                  .round(),
        );
      }
    }
    // The silence before the first sound of a loop that starts by itself.
    var seekTo = position;
    if (wait == null &&
        !carryOn &&
        position == Duration.zero &&
        preRoll > Duration.zero &&
        preRoll < length) {
      seekTo = length - preRoll;
      delay = preRoll;
    }
    final SoundHandle handle;
    Duration? startsAt;
    // The old loop let go where the new one takes over: a ringing piano
    // dies away as under a pianist's hands rather than being cut.
    _Tail? tail;
    if (oldThen != null && !carryOn && tailFor != null) {
      try {
        tail = await _Tail.load(
          tailFor,
          oldThen + (wait ?? Duration.zero),
          _length,
          since,
          _soloud,
        );
      } catch (_) {
        // Without its tail the old loop is simply cut, as it used to be.
      }
      // Making the tail took longer than the wait (a slow phone, a page):
      // the next bar line instead, without the tail, made for the one
      // gone. The new loop's first chord covers the old one stopping.
      final w = wait;
      if (tail != null && w != null) {
        final now = _soloud.getEngineTime();
        if (waitedFrom + w - now < _scheduleLead) {
          tail.dispose();
          tail = null;
          waitedFrom = now;
          wait =
              transport.untilBarLine(name) ?? _nextBarLine(old!, _scheduleLead);
        }
      }
    }
    // A new chord carrying on: the engine time at which the old loop gives
    // way, just before the next pulse, the new one then sounding whole.
    Duration? switchAt;
    if (carryOn && onPulse != null && onPulse > Duration.zero) {
      var wait =
          onPulse -
          Duration(
            microseconds: position.inMicroseconds % onPulse.inMicroseconds,
          );
      while (wait < _switchLead + const Duration(milliseconds: 50)) {
        wait += onPulse;
      }
      switchAt = _soloud.getEngineTime() + wait - _switchLead;
    }
    final fade = carryOn && crossfade > Duration.zero && switchAt == null;
    if (wait == null) {
      handle = _soloud.play(
        source,
        paused: true,
        looping: true,
        volume: fade || switchAt != null ? 0 : _volume,
      );
      if (seekTo > Duration.zero) _soloud.seek(handle, seekTo);
      _soloud.setPause(handle, false);
      if (switchAt != null) {
        _soloud.fadeScheduled(handle, switchAt, _volume, _switchLead);
      }
      if (fade) _soloud.fadeVolume(handle, _volume, crossfade);
      tail?.playNow(_volume);
    } else {
      // The other loop is playing: come in on its next "one", on the
      // engine's own clock, read once for the start and the stop below.
      delay = wait;
      position = Duration.zero;
      startsAt = waitedFrom + wait;
      handle = _soloud.playScheduled(
        source,
        startsAt,
        looping: true,
        volume: _volume,
      );
      tail?.playAt(startsAt, handingOver ? _volume * handOverLevel : _volume);
    }
    _handle = handle;
    _source = source;
    _length = length;
    _bar = bar;
    transport.unregister(name, old);
    transport.register(name, handle, bar, startsAt: startsAt);
    if (handingOver && startsAt != null) {
      transport.meet(startsAt);
    } else if (handOver) {
      transport.cancelMeeting();
    }
    if (old != null && switchAt != null) {
      // Both run together, silent the new one, until the pulse.
      _soloud.fadeScheduled(old, switchAt, 0, _switchLead, thenStop: true);
      final gone = switchAt - _soloud.getEngineTime() + _switchLead;
      Future<void>.delayed(gone + const Duration(milliseconds: 100), () {
        if (oldSource != null) _soloud.disposeSource(oldSource);
      });
    } else if (old != null && startsAt != null) {
      // The old loop plays on until the new one comes in, and stops at that
      // very sample, so that the two "ones" do not both sound.
      _soloud.stopScheduled(old, startsAt);
      Future<void>.delayed(delay + const Duration(milliseconds: 100), () {
        if (oldSource != null) _soloud.disposeSource(oldSource);
      });
    } else if (old != null && fade) {
      // Carrying on at a new tempo: the two cross over.
      _soloud.fadeVolume(old, 0, crossfade);
      _soloud.scheduleStop(old, crossfade);
      Future<void>.delayed(crossfade + const Duration(milliseconds: 100), () {
        if (oldSource != null) _soloud.disposeSource(oldSource);
      });
    } else {
      if (old != null) await _soloud.stop(old);
      if (oldSource != null) await _soloud.disposeSource(oldSource);
    }
    if (startsAt != null) {
      // Counted from now, not from when the wait was read: making the old
      // loop's tail took a while, and whoever lines the screen up with the
      // sound starts counting when this returns.
      delay = delay - since.elapsed;
      if (delay < Duration.zero) delay = Duration.zero;
    }
    return (position: position, delay: delay);
  }

  /// How long the clicks wait for the piano's new loop at most (see
  /// [play] with atMeeting): past it they change on their own.
  static const _meetingLimit = Duration(seconds: 30);

  /// How fast clicks waiting to meet the piano go down: before the next
  /// click at any tempo the app plays.
  static const _meetingFade = Duration(milliseconds: 150);

  /// The least time a start can be scheduled ahead on the engine's clock.
  static const _scheduleLead = Duration(milliseconds: 60);

  /// Time until the next bar line at least [minimum] away: the other loop's
  /// when it plays (this one follows it), otherwise this loop's own, [old]
  /// playing.
  Duration _nextBarLine(SoundHandle old, Duration minimum) {
    final other = transport.untilBarLine(name, minimum: minimum);
    if (other != null) return other;
    return LoopTransport.waitForBarLine(
      bar: _bar,
      position: Duration(
        microseconds:
            _soloud.getPosition(old).inMicroseconds % _length.inMicroseconds,
      ),
      minimum: minimum,
    );
  }

  /// Starts handing this loop over to another, as a band changes song: it
  /// goes down to [handOverLevel] by the next bar line at least [lead]
  /// away, where [play] with `handOver` brings the new one in. Says how long
  /// until that bar line, or null when nothing plays (the new loop then
  /// simply starts).
  Duration? beginHandOver({required Duration lead}) {
    final handle = _handle;
    if (handle == null || _bar <= Duration.zero) return null;
    if (!_soloud.getIsValidVoiceHandle(handle)) return null;
    final now = _soloud.getEngineTime();
    // Already under way: the same bar line, if it is still to come.
    final aimed = _handOverAt;
    if (aimed != null && aimed - now >= _scheduleLead) return aimed - now;
    final wait = _nextBarLine(handle, lead);
    _handOverAt = now + wait;
    transport.beginMeeting(now + wait);
    _soloud.fadeVolume(handle, _volume * handOverLevel, wait);
    return wait;
  }

  /// Calls off a hand-over under way (see [beginHandOver]): the loop
  /// playing stays, back up to its level.
  void cancelHandOver() {
    final handle = _handle;
    if (_handOverAt == null || handle == null) return;
    _handOverAt = null;
    transport.cancelMeeting();
    if (!_soloud.getIsValidVoiceHandle(handle)) return;
    _soloud.fadeVolume(handle, _volume, const Duration(milliseconds: 300));
  }

  /// Stops the loop. With [tailFor], what the loop sounds like let go
  /// where it is (see PianoSound.tailWav) plays on from that very sample.
  Future<void> stop({
    Future<Uint8List> Function(Duration position)? tailFor,
  }) async {
    final handle = _handle, source = _source;
    if (_handOverAt != null) transport.cancelMeeting();
    _handOverAt = null;
    _handle = null;
    _source = null;
    transport.unregister(name, handle);
    if (handle != null &&
        tailFor != null &&
        _soloud.getIsValidVoiceHandle(handle)) {
      try {
        final since = Stopwatch()..start();
        final tail = await _Tail.load(
          tailFor,
          _soloud.getPosition(handle),
          _length,
          since,
          _soloud,
        );
        tail.playNow(_volume);
      } catch (_) {
        // Without its tail the loop is simply cut, as it used to be.
      }
    }
    if (handle != null) await _soloud.stop(handle);
    if (source != null) await _soloud.disposeSource(source);
  }

  void setVolume(double volume) {
    _volume = volume;
    final handle = _handle;
    if (handle != null) _soloud.setVolume(handle, volume);
  }
}

/// What a loop sounds like let go at a place in it, ready to play from
/// that place on.
class _Tail {
  _Tail._(this._soloud, this._source, this._clock, this._length);

  /// Makes the tail of a loop of [length] let go at [position] (taken
  /// round the loop) and loads it. [clock] runs from when [position] was
  /// read, so that a tail played at once starts where the loop is by then.
  static Future<_Tail> load(
    Future<Uint8List> Function(Duration position) tailFor,
    Duration position,
    Duration length,
    Stopwatch clock,
    LoopEngine engine,
  ) async {
    final at = length > Duration.zero
        ? Duration(
            microseconds: position.inMicroseconds % length.inMicroseconds,
          )
        : position;
    final wav = await tailFor(at);
    final source = await engine.loadMem('tail.wav', wav);
    return _Tail._(engine, source, clock, engine.getLength(source));
  }

  final AudioSource _source;
  final Stopwatch _clock;
  final Duration _length;
  final LoopEngine _soloud;

  /// From where the loop is now, which went on while the tail was made.
  void playNow(double volume) {
    final handle = _soloud.play(_source, paused: true, volume: volume);
    final skip = _clock.elapsed;
    if (skip < _length) _soloud.seek(handle, skip);
    _soloud.setPause(handle, false);
    _disposeAfter(_length);
  }

  /// From its start, at [time] on the engine's clock.
  void playAt(Duration time, double volume) {
    _soloud.playScheduled(_source, time, volume: volume);
    _disposeAfter(time - _soloud.getEngineTime() + _length);
  }

  /// Never played after all.
  void dispose() => _soloud.disposeSource(_source);

  void _disposeAfter(Duration wait) => Future<void>.delayed(
    wait + const Duration(milliseconds: 200),
    () => _soloud.disposeSource(_source),
  );
}
