import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../audio/click_output.dart';
import '../../audio/click_sound.dart';
import '../../audio/latest_request.dart';
import '../../audio/sound_section.dart';
import '../../audio/sound_clock.dart';
import 'bar_clock.dart';
import 'subdivision.dart';
import 'time_signature.dart';

/// State and playback of the metronome.
class MetronomeController extends ChangeNotifier
    implements BarClock, SoundSection {
  MetronomeController(
    this._output, {
    Stopwatch? clock,
    Duration Function()? outputLatency,
  }) : _clock = SoundClock(clock),
       _outputLatency = outputLatency ?? _noLatency {
    _requests = LatestRequest(_apply);
  }

  final ClickOutput _output;

  /// How long after the engine plays a click it is heard (see
  /// AudioRoute.outputLatency): the beat on screen lags that much, so the
  /// light comes with the sound and not before it.
  final Duration Function() _outputLatency;

  static Duration _noLatency() => Duration.zero;

  /// The beat shown on screen, lined up with the sound as it is heard.
  final SoundClock _clock;

  /// Brings the sound in line with the settings, one run at a time.
  late final LatestRequest _requests;

  /// The tempo range, in beats per minute of the figure the tempo counts
  /// (see [TimeSignature.beatUnit]): quarters, or dotted quarters in 6/8.
  static const minBpm = 30;
  static const maxBpm = 250;

  /// In 7/8 the tempo counts eighths, and a fast Balkan bar needs more.
  static const maxEighthBpm = 400;
  static const startBpm = 80;

  /// The fastest tempo in [signature].
  static int maxBpmFor(TimeSignature signature) =>
      signature.beatUnit == BeatUnit.eighth ? maxEighthBpm : maxBpm;

  /// Taps further apart than this start a new count.
  static const _tapTimeout = Duration(seconds: 2);

  /// Intervals averaged by [tap]: enough to smooth a hand, few enough to
  /// follow a change.
  static const _tapsKept = 4;

  int _bpm = startBpm;

  /// The tempo the clicks (and the harmony) play at: [bpm] once the player
  /// has stopped choosing it (see [step], [nudge], [tap]).
  int _heardBpm = startBpm;

  /// Applies a tempo still being chosen, once the hand rests (see [_adjust]).
  Timer? _adjusting;

  /// How long − and + must rest before the tempo they chose is heard.
  static const adjustRest = Duration(milliseconds: 300);

  /// The least time TAP must rest before its tempo is heard.
  static const tapRest = Duration(milliseconds: 600);
  TimeSignature _signature = TimeSignature.fourFour;
  Subdivision _subdivision = Subdivision.quarters;
  bool _backbeat = false;
  bool _playing = false;
  bool _audioFailed = false;
  var _disposed = false;

  // Whether the sound has been asked for and not yet started.
  var _starting = false;

  final _taps = <Duration>[];

  /// True when the next bar must start from its "one", because the sound
  /// has just started or the bar has changed shape.
  bool _fresh = false;

  /// The tempo, in beats of [TimeSignature.beatUnit] per minute: in 6/8,
  /// 60 is a dotted quarter a second, three clicks. While it is being chosen
  /// on − and + or with TAP it may not be heard yet (see [soundingBpm]).
  int get bpm => _bpm;

  /// The tempo heard: [bpm], once the hand rests.
  @override
  int get soundingBpm => _heardBpm;
  @override
  TimeSignature get signature => _signature;

  /// The softer clicks inside each beat (only in bars counted in
  /// quarters).
  Subdivision get subdivision => _subdivision;

  /// True when the click falls on 2 and 4 only (see [backbeatApplies]).
  bool get backbeat => _backbeat;

  /// True when [backbeat] changes the sound: in 2/4 and 4/4.
  bool get backbeatApplies => _signature.hasBackbeat;

  /// True when [subdivision] changes the sound: not in the bars counted in
  /// eighths.
  bool get subdivisionApplies => _signature.denominator != 8;

  /// True when pulse [beat] of the bar is silent: 1 and 3 when the click
  /// falls on 2 and 4.
  bool isSilent(int beat) => _backbeat && backbeatApplies && beat.isEven;

  /// Pulses (segments of the ring, clicks) in a bar.
  int get beatsPerBar => _signature.beats;
  @override
  bool get isPlaying => _playing;

  /// The fastest tempo in the current time signature.
  int get maxTempo => maxBpmFor(_signature);

  /// Clicks per minute as heard: [soundingBpm], or three times it in 6/8.
  int get pulseBpm => _heardBpm * _signature.pulsesPerBeat;

  /// True when the last attempt to start sound failed on this device.
  bool get audioFailed => _audioFailed;

  /// Time from one click to the next.
  Duration get pulseLength => Duration(microseconds: 60000000 ~/ pulseBpm);
  @override
  Duration get barLength => pulseLength * beatsPerBar;

  /// How far into the bar the metronome is, from 0 to just under 1, or null
  /// when stopped.
  @override
  double? get barPhase {
    if (!_playing || _starting) return null;
    // Before the sound comes in, nothing is lit.
    final at = _clock.position;
    if (at == null) return null;
    return at.inMicroseconds / barLength.inMicroseconds % 1;
  }

  /// The pulses until the click comes in, for the countdown in the middle of
  /// the dial; null when it does not wait.
  int? get beatsLeft {
    final left = waitLeft;
    if (left == null) return null;
    return math.max(
      1,
      (left.inMicroseconds / pulseLength.inMicroseconds).ceil(),
    );
  }

  /// How long until the click comes in, when it waits for the piano's next
  /// bar line, or null when it does not wait (or the wait is not known yet).
  Duration? get waitLeft {
    if (!_playing || _starting) return null;
    return _clock.waitLeft;
  }

  /// The pulse now sounding (the segment lit), 0 (the "one") to the last of
  /// the bar, or null when stopped.
  int? get beat {
    final phase = barPhase;
    return phase == null ? null : (phase * beatsPerBar).floor();
  }

  /// Time since the current pulse sounded, or null when stopped.
  Duration? get sinceBeat {
    final phase = barPhase;
    if (phase == null) return null;
    final inBeat = phase * beatsPerBar % 1;
    return pulseLength * inBeat;
  }

  @override
  Future<void> start() {
    if (_playing) return Future.value();
    // A tempo still being chosen is heard from the start.
    _adjusting?.cancel();
    _heardBpm = _bpm;
    _playing = true;
    _audioFailed = false;
    _fresh = true;
    _starting = true;
    _restartClock(Duration.zero);
    _notify();
    return _sync();
  }

  @override
  Future<void> stop() {
    if (!_playing) return Future.value();
    _playing = false;
    _clock.stop();
    _notify();
    return _sync();
  }

  Future<void> toggle() => _playing ? stop() : start();

  /// Sets the tempo, kept within [minBpm] and [maxTempo], and plays it at
  /// once (a tempo typed, a song, an action). While playing, the beat
  /// carries on from where it was.
  void setBpm(int bpm) {
    _adjusting?.cancel();
    final value = bpm.clamp(minBpm, maxTempo);
    if (value == _bpm && value == _heardBpm) return;
    _bpm = value;
    _hear();
  }

  /// Plays [bpm], if it is not what plays already: the beat carries on from
  /// where it was.
  void _hear() {
    _adjusting?.cancel();
    if (_heardBpm == _bpm) {
      _notify();
      return;
    }
    final phase = barPhase;
    _heardBpm = _bpm;
    if (phase != null) _restartClock(barLength * phase);
    _notify();
    if (_playing) _sync();
  }

  /// Shows [bpm] at once and plays it once the hand has rested for [rest]:
  /// holding + runs the number, and the click (and the harmony with it)
  /// moves to the tempo where the finger stops, instead of through every
  /// one on the way (RF-MET-08). Stopped, nothing is heard, so it is set at
  /// once.
  void _adjust(int bpm, Duration rest) {
    final value = bpm.clamp(minBpm, maxTempo);
    if (value == _bpm) return;
    _bpm = value;
    if (!_playing) return _hear();
    _notify();
    _adjusting?.cancel();
    _adjusting = Timer(rest, _hear);
  }

  /// Changes the time signature, keeping the number of the tempo (in 6/8
  /// it then counts dotted quarters) as far as the new bar allows. While
  /// playing, the bar starts again from its "one": the old position means
  /// nothing in the new bar.
  void setSignature(TimeSignature signature) {
    if (signature == _signature) return;
    _signature = signature;
    _adjusting?.cancel();
    _bpm = _heardBpm = _bpm.clamp(minBpm, maxTempo);
    if (_playing) {
      _fresh = true;
      _starting = true;
      _restartClock(Duration.zero);
    }
    _notify();
    if (_playing) _sync();
  }

  /// Sets what fills each beat. While playing, the bar carries on from where
  /// it was; [Subdivision.quarters] is the beat alone.
  void setSubdivision(Subdivision subdivision) {
    if (subdivision == _subdivision) return;
    _subdivision = subdivision;
    _notify();
    if (_playing) _sync();
  }

  /// Puts the click on 2 and 4 only, or back on every beat. It is kept when
  /// the time signature changes, and heard again in 2/4 and 4/4.
  void setBackbeat(bool backbeat) {
    if (backbeat == _backbeat) return;
    _backbeat = backbeat;
    _notify();
    if (_playing) _sync();
  }

  /// Moves the tempo up or down by [delta] BPM, heard once the hand rests.
  void step(int delta) => _adjust(_bpm + delta, adjustRest);

  /// Moves the tempo to the next multiple of [unit] above ([direction] > 0)
  /// or below it, so that holding + or − lands on round numbers.
  void nudge(int direction, int unit) {
    final target = direction > 0
        ? (_bpm ~/ unit + 1) * unit
        : (_bpm - 1) ~/ unit * unit;
    _adjust(target, adjustRest);
  }

  /// One tap of the TAP button: after two taps or more, sets the tempo to
  /// the average of the latest intervals. The taps are beats of the tempo,
  /// as a player taps them: dotted quarters in 6/8, not eighths.
  void tap(Duration now) {
    if (_taps.isNotEmpty && now - _taps.last > _tapTimeout) _taps.clear();
    _taps.add(now);
    if (_taps.length > _tapsKept + 1) _taps.removeAt(0);
    if (_taps.length < 2) return;
    final span = _taps.last - _taps.first;
    final interval = span.inMicroseconds / (_taps.length - 1);
    // Heard once the taps stop: a beat and a half with no tap.
    final rest = Duration(
      microseconds: math.max(tapRest.inMicroseconds, (interval * 1.5).round()),
    );
    _adjust((60000000 / interval).round(), rest);
  }

  void _restartClock(Duration at) => _clock.restartAt(at);

  /// Brings the sound in line with [isPlaying] and [bpm], one call at a
  /// time; changes made meanwhile are applied right after, all at once, so
  /// holding + only rebuilds the bar as often as the engine can follow.
  Future<void> _sync() => _requests.run();

  Future<void> _apply() async {
    try {
      if (!_playing || _disposed) {
        await _output.stop();
        return;
      }
      // The first beat always sounds from its start; after a change of tempo
      // the bar carries on from where it was.
      final fresh = _fresh;
      _fresh = false;
      final started = await _output.play(
        ClickSound.bar(
          bpm: pulseBpm,
          signature: _signature,
          subdivision: _subdivision,
          backbeat: _backbeat,
        ),
        startAt: fresh ? Duration.zero : null,
      );
      // The sound starts now (or on the piano's next bar line): line the
      // screen up with it, as it is heard. A fresh start lights up once the
      // first click comes out; a bar carrying on shows its place as it was
      // that long ago.
      _starting = false;
      _clock.heard(started, latency: _outputLatency(), fresh: fresh);
    } catch (error) {
      debugPrint('Metronome could not start: $error');
      _playing = false;
      _audioFailed = true;
      _starting = false;
      _clock.stop();
      _notify();
      try {
        await _output.stop();
      } catch (_) {}
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _adjusting?.cancel();
    _disposed = true;
    _playing = false;
    _sync();
    super.dispose();
  }
}
