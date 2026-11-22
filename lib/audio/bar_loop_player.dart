import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
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

  /// When the loop handed over began to go down (see [beginHandOver]), and
  /// from what level: how loud it is at a stop before the bar line.
  ({Duration at, double level})? _handOverFrom;

  /// The meeting this player opened on the transport (see [beginHandOver])
  /// and has not closed yet. Whoever opens a meeting closes it, however
  /// the hand-over ends: the new loop scheduled ([LoopTransport.meet]),
  /// called off, failed, not wanted, or stopped. Otherwise clicks waiting
  /// for it would stay let down for up to [_meetingLimit].
  Object? _meeting;

  /// How loud a loop handed over is at [time] on the engine's clock: from
  /// the level it had when the hand-over began ([from]) down to
  /// [handOverLevel] by the bar line aimed at, linearly, as the engine
  /// fades.
  double _handOverLevelAt(
    ({Duration at, double level}) from,
    Duration aimedAt,
    Duration time,
  ) {
    final down = _volume * handOverLevel;
    final span = aimedAt - from.at;
    if (span <= Duration.zero || time >= aimedAt) return down;
    final done = (time - from.at).inMicroseconds / span.inMicroseconds;
    return from.level + (down - from.level) * done.clamp(0.0, 1.0);
  }

  /// Once [handle] has come in, at [arrives], goes on down with the
  /// hand-over to its bar line [aimedAt] (an engine fade starts from the
  /// level at the call, so it is asked for then, not now).
  void _goOnDown(SoundHandle handle, Duration arrives, Duration aimedAt) {
    final left = arrives - _soloud.getEngineTime();
    Future<void>.delayed(left > Duration.zero ? left : Duration.zero, () {
      if (!identical(_handle, handle) || _handOverAt != aimedAt) return;
      final rest = aimedAt - _soloud.getEngineTime();
      if (rest <= Duration.zero) return;
      _soloud.fadeVolume(handle, _volume * handOverLevel, rest);
    });
  }

  /// Closes the meeting this player opened, if it is still open: nothing
  /// will come in on it.
  void _closeMeeting() {
    if (_meeting == null) return;
    _meeting = null;
    transport.cancelMeeting();
  }

  AudioSource? _source;
  SoundHandle? _handle;
  Duration _length = Duration.zero;
  Duration _bar = Duration.zero;
  double _volume = 1;

  /// The engine time the voice playing was scheduled to come in at, if it
  /// was: until then it reports no position (see [_untilOwnStart]).
  Duration? _startsAt;

  /// How many times [stop] was called: a play that a stop overtook while it
  /// got ready starts nothing (it throws [LoopNotWanted]).
  var _stops = 0;

  /// Ended by [stop]: clicks waiting to meet the piano (see [play] with
  /// atMeeting) stop waiting.
  Completer<void>? _meetingWait;

  /// The engine time a new chord carrying on is heard from (see [play]
  /// with onPulse): until then it plays silent under the old one.
  Duration? _heardFrom;

  /// Whether the voice playing has yet to be heard: scheduled on a bar line
  /// still to come, or a new chord silent until its pulse.
  bool get _unheard {
    if (_untilOwnStart() != null) return true;
    final from = _heardFrom;
    return from != null && _soloud.getEngineTime() < from;
  }

  /// The voices this player started that still sound, or are still to,
  /// besides the loop playing ([_handle]): the loop it replaced, which plays
  /// on until the new one comes in (or fades out under it), and that old
  /// loop's tail. Each is let go by the engine at its own time; this list
  /// only remembers them, so that nothing this player owns is forgotten.
  final _owned = <_Owned>[];

  LoopEngine get _soloud => transport.engine;

  bool get isPlaying => _handle != null;

  /// Every voice this player answers for that has not ended yet: the loop
  /// playing first, then the ones on their way out (see [_owned]).
  @visibleForTesting
  List<SoundHandle> get voices {
    _forgetEnded();
    return [?_handle, for (final v in _owned) v.handle];
  }

  /// Drops the voices of [_owned] that have ended.
  void _forgetEnded() {
    final now = _soloud.getEngineTime();
    _owned.removeWhere(
      (v) => v.until <= now || !_soloud.getIsValidVoiceHandle(v.handle),
    );
  }

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
  ///
  /// [wanted] is asked once the loop is ready, just before it sounds: if
  /// it says no (the sound was stopped, or started again, meanwhile),
  /// nothing starts and the play throws [LoopNotWanted].
  /// The same when this player is stopped meanwhile: clicks waiting to
  /// meet the piano stop waiting then, and a stop never waits behind a play.
  Future<LoopStart> play(
    Uint8List wav,
    Duration bar, {
    Duration? startAt,
    Duration preRoll = Duration.zero,
    Duration? onPulse,
    Future<Uint8List> Function(Duration position)? tailFor,
    bool handOver = false,
    bool atMeeting = false,
    bool Function()? wanted,
  }) async {
    // A stop while this play gets ready overtakes it (see [_stops]).
    final stops = _stops;
    await _soloud.ensure();
    final source = await _soloud.loadMem('$name-loop.wav', wav);
    final length = _soloud.getLength(source);
    final old = _handle != null && _soloud.getIsValidVoiceHandle(_handle!)
        ? _handle
        : null;
    final oldSource = _source;
    final oldLength = _length;
    // The old loop may itself be yet to be heard (a change right after
    // another): from when it is.
    final oldHeardFrom = !_unheard
        ? null
        : _untilOwnStart() != null
        ? _startsAt
        : _heardFrom;
    final carryOn = startAt == null && old != null;
    final handingOver = handOver && !carryOn && old != null;
    final aimedAt = _handOverAt;
    final fadeFrom = _handOverFrom;
    // A new tempo carrying on while a hand-over is under way (asked for
    // before it, ready only now) does not use it up: the loop stays let
    // down, and the hand-over's own loop still comes in on its bar line.
    final keepsHandOver =
        carryOn && !handOver && aimedAt != null && fadeFrom != null;
    if (!keepsHandOver) {
      _handOverAt = null;
      _handOverFrom = null;
    }
    Duration? wait;
    // Meeting the piano's new loop: let down with the piano by the bar line
    // it aims at, as a band changing song, then wait to hear when it
    // really comes in.
    var meeting = false;
    Duration? met;
    if (atMeeting && !carryOn && old != null) {
      final aimed = transport.meetingAt;
      if (aimed != null) {
        meeting = true;
        // Down at once, not along the wait: a click sounds only on the
        // beats, the last one a beat before the bar line, and a slow fade
        // would never be heard.
        _soloud.fadeVolume(old, _volume * meetingLevel, _meetingFade);
        // A stop meanwhile ends the wait at once (see [stop]).
        final stopped = _meetingWait = Completer<void>();
        met = await Future.any([
          transport.meeting.timeout(_meetingLimit, onTimeout: () => null),
          stopped.future.then((_) => null),
        ]);
        if (identical(_meetingWait, stopped)) _meetingWait = null;
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
    // A voice still waiting to come in is that long before its start.
    final oldWaits = old == null ? null : _untilOwnStart();
    final oldThen = old == null
        ? null
        : oldWaits != null
        ? -oldWaits
        : _soloud.getPosition(old);
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
    // None for a voice replaced before it ever sounded.
    if (oldThen != null &&
        !carryOn &&
        tailFor != null &&
        oldThen + (wait ?? Duration.zero) > Duration.zero) {
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
      // gone. The new loop's first chord covers the old one stopping. The
      // same when the tail failed after a while: the wait is gone all the
      // same, and a start in the past would come in at once, off the beat.
      final w = wait;
      if (w != null) {
        final now = _soloud.getEngineTime();
        if (waitedFrom + w - now < _scheduleLead) {
          tail?.dispose();
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
    if (stops != _stops || (wanted != null && !wanted())) {
      tail?.dispose();
      // The hand-over this loop was for ends here: clicks waiting to meet
      // it change on their own (a stop meanwhile has closed it already).
      if (handOver) _closeMeeting();
      await _soloud.disposeSource(source);
      throw const LoopNotWanted();
    }
    if (wait == null) {
      handle = _soloud.play(
        source,
        paused: true,
        looping: true,
        volume: fade || switchAt != null ? 0 : _volume,
      );
      if (seekTo > Duration.zero) _soloud.seek(handle, seekTo);
      _soloud.setPause(handle, false);
      // Coming in at the level the hand-over has reached by then, and on
      // down with it, rather than back at full level.
      final arrives = switchAt != null
          ? switchAt + _switchLead
          : _soloud.getEngineTime() + crossfade;
      final level = keepsHandOver
          ? _handOverLevelAt(fadeFrom, aimedAt, arrives)
          : _volume;
      if (switchAt != null) {
        _soloud.fadeScheduled(handle, switchAt, level, _switchLead);
      }
      if (fade) _soloud.fadeVolume(handle, level, crossfade);
      if (keepsHandOver) _goOnDown(handle, arrives, aimedAt);
      final t = tail?.playNow(_volume);
      if (t != null) _owned.add(t);
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
      final t = tail?.playAt(
        startsAt,
        handingOver ? _volume * handOverLevel : _volume,
      );
      if (t != null) _owned.add(t);
    }
    _forgetEnded();
    _handle = handle;
    _source = source;
    _length = length;
    _bar = bar;
    _startsAt = startsAt;
    _heardFrom = switchAt == null ? null : switchAt + _switchLead;
    transport.unregister(name, old);
    transport.register(name, handle, bar, startsAt: startsAt);
    if (handingOver && startsAt != null) {
      _meeting = null;
      transport.meet(startsAt);
    } else if (handOver) {
      _meeting = null;
      transport.cancelMeeting();
    }
    if (old != null && switchAt != null) {
      // Both run together, silent the new one, until the pulse.
      _soloud.fadeScheduled(old, switchAt, 0, _switchLead, thenStop: true);
      _owned.add(
        _Owned(
          old,
          until: switchAt + _switchLead,
          from: oldHeardFrom,
          length: oldLength,
          tailFor: tailFor,
          level: (_) => _volume,
        ),
      );
      final gone = switchAt - _soloud.getEngineTime() + _switchLead;
      Future<void>.delayed(gone + const Duration(milliseconds: 100), () {
        if (oldSource != null) _soloud.disposeSource(oldSource);
      });
    } else if (old != null && startsAt != null) {
      // The old loop plays on until the new one comes in, and stops at that
      // very sample, so that the two "ones" do not both sound.
      _soloud.stopScheduled(old, startsAt);
      final level = _volume;
      _owned.add(
        _Owned(
          old,
          until: startsAt,
          from: oldHeardFrom,
          length: oldLength,
          tailFor: tailFor,
          // As it was let down: to a third by the bar line handed over at,
          // to a sixth at once for clicks meeting the piano.
          level: meeting
              ? (_) => level * meetingLevel
              : handingOver && fadeFrom != null && aimedAt != null
              ? (now) => _handOverLevelAt(fadeFrom, aimedAt, now)
              : (_) => level,
        ),
      );
      Future<void>.delayed(delay + const Duration(milliseconds: 100), () {
        if (oldSource != null) _soloud.disposeSource(oldSource);
      });
    } else if (old != null && fade) {
      // Carrying on at a new tempo: the two cross over.
      _soloud.fadeVolume(old, 0, crossfade);
      _soloud.scheduleStop(old, crossfade);
      _owned.add(
        _Owned(
          old,
          until: _soloud.getEngineTime() + crossfade,
          length: oldLength,
        ),
      );
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
    // Scheduled and not yet sounding (a change right after another): its
    // bar lines count from its start, as the transport counts the other's.
    final until = _untilOwnStart();
    return LoopTransport.waitForBarLine(
      bar: _bar,
      position: until != null
          ? null
          : Duration(
              microseconds:
                  _soloud.getPosition(old).inMicroseconds %
                  _length.inMicroseconds,
            ),
      untilStart: until,
      minimum: minimum,
    );
  }

  /// How long until the voice playing comes in, while it is scheduled and
  /// not yet sounding; null once it sounds.
  Duration? _untilOwnStart() {
    final at = _startsAt;
    if (at == null) return null;
    final left = at - _soloud.getEngineTime();
    return left > Duration.zero ? left : null;
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
    _handOverFrom = (at: now, level: _volume);
    _meeting = Object();
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
    _handOverFrom = null;
    _closeMeeting();
    if (!_soloud.getIsValidVoiceHandle(handle)) return;
    _soloud.fadeVolume(handle, _volume, const Duration(milliseconds: 300));
  }

  /// Stops the loop at once, with every voice this player started that is
  /// still to end (see [_owned]): the old loop playing on to the bar line
  /// or pulse where the new one comes in, and its tail scheduled there.
  /// With [tailFor], the loop heard is let go where it is (see
  /// PianoSound.tailWav), its tail playing on from that very sample: the
  /// loop playing, or while that one has yet to be heard, the old loop it
  /// was to replace, with the tail given for it to [play]. A tail already
  /// ringing (a chord let go before) rings on.
  Future<void> stop({
    Future<Uint8List> Function(Duration position)? tailFor,
  }) async {
    final handle = _handle, source = _source;
    // Scheduled and not yet sounding (waiting for the other loop's bar
    // line), or a new chord silent until its pulse: it is not let go, and
    // a tail would ring out of a chord never heard. Read before
    // [_startsAt] and [_heardFrom] are forgotten.
    final unheard = _unheard;
    _stops++;
    _meetingWait?.complete();
    _meetingWait = null;
    _closeMeeting();
    _handOverAt = null;
    _handOverFrom = null;
    _handle = null;
    _source = null;
    _startsAt = null;
    _heardFrom = null;
    transport.unregister(name, handle);
    _forgetEnded();
    final owned = [..._owned];
    _owned.clear();
    final now = _soloud.getEngineTime();
    // The loop heard now, which is let go rather than cut.
    ({
      SoundHandle handle,
      Duration length,
      double level,
      Future<Uint8List> Function(Duration)? tailFor,
    })?
    heard;
    if (handle != null && !unheard) {
      heard = (
        handle: handle,
        length: _length,
        level: _volume,
        tailFor: tailFor,
      );
    } else if (tailFor != null) {
      for (final v in owned.reversed) {
        final from = v.from;
        if (v.isTail || v.level == null) continue;
        if (from != null && from > now) continue;
        heard = (
          handle: v.handle,
          length: v.length,
          level: v.level!(now),
          tailFor: v.tailFor,
        );
        break;
      }
    }
    // All the rest at once, before a tail is made: nothing still to come in
    // may come in meanwhile.
    for (final v in owned) {
      if (v.handle == heard?.handle) continue;
      // A tail already ringing is a chord let go: it rings on.
      final from = v.from;
      if (v.isTail && (from == null || from <= now)) continue;
      await _soloud.stop(v.handle);
    }
    if (handle != null && handle != heard?.handle) await _soloud.stop(handle);
    final heardTail = heard?.tailFor;
    if (heard != null &&
        heardTail != null &&
        _soloud.getIsValidVoiceHandle(heard.handle)) {
      try {
        final since = Stopwatch()..start();
        final tail = await _Tail.load(
          heardTail,
          _soloud.getPosition(heard.handle),
          heard.length,
          since,
          _soloud,
        );
        tail.playNow(heard.level);
      } catch (_) {
        // Without its tail the loop is simply cut, as it used to be.
      }
    }
    if (heard != null) await _soloud.stop(heard.handle);
    if (source != null) await _soloud.disposeSource(source);
  }

  /// Sets how loud the loops are. The same level again leaves the voice
  /// alone: the engine's setVolume ends a fade under way, and a hand-over
  /// (see [beginHandOver]) or a new chord waiting for its pulse is one.
  /// During a hand-over the loop let down stays so; the new one comes in at
  /// the new level.
  void setVolume(double volume) {
    if (volume == _volume) return;
    _volume = volume;
    final handle = _handle;
    if (handle != null && _handOverAt == null) {
      _soloud.setVolume(handle, volume);
    }
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

  /// From where the loop is now, which went on while the tail was made;
  /// nothing (null) when making it took longer than it rings: played from
  /// its start, it would sound as if the piano played again.
  _Owned? playNow(double volume) {
    final skip = _clock.elapsed;
    if (skip >= _length) {
      dispose();
      return null;
    }
    final handle = _soloud.play(_source, paused: true, volume: volume);
    _soloud.seek(handle, skip);
    _soloud.setPause(handle, false);
    _disposeAfter(_length);
    return _Owned(
      handle,
      until: _soloud.getEngineTime() + _length - skip,
      length: _length,
      isTail: true,
    );
  }

  /// From its start, at [time] on the engine's clock.
  _Owned playAt(Duration time, double volume) {
    final handle = _soloud.playScheduled(_source, time, volume: volume);
    _disposeAfter(time - _soloud.getEngineTime() + _length);
    return _Owned(
      handle,
      from: time,
      until: time + _length,
      length: _length,
      isTail: true,
    );
  }

  /// Never played after all.
  void dispose() => _soloud.disposeSource(_source);

  void _disposeAfter(Duration wait) => Future<void>.delayed(
    wait + const Duration(milliseconds: 200),
    () => _soloud.disposeSource(_source),
  );
}

/// A voice a [BarLoopPlayer] started besides the loop playing (see
/// BarLoopPlayer._owned).
class _Owned {
  _Owned(
    this.handle, {
    required this.until,
    required this.length,
    this.from,
    this.tailFor,
    this.level,
    this.isTail = false,
  });

  final SoundHandle handle;

  /// The engine time it ends at, at the latest.
  final Duration until;

  /// How long its recording is.
  final Duration length;

  /// The engine time it is heard from, when that was still to come as it
  /// was started (a tail on the bar line the new loop comes in on, an old
  /// loop itself replaced before it was heard); null if it was heard
  /// already.
  final Duration? from;

  /// For a loop replaced: what it sounds like let go at a place in it, as
  /// given to the play that replaced it; null if not known.
  final Future<Uint8List> Function(Duration position)? tailFor;

  /// For a loop replaced that plays on until the new one comes in: how
  /// loud it is at a time on the engine's clock (see BarLoopPlayer.stop).
  final double Function(Duration now)? level;

  /// A tail, rather than a loop replaced.
  final bool isTail;
}
