import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../audio/latest_request.dart';
import '../../audio/piano_output.dart';
import '../../audio/piano_sound.dart';
import '../../audio/pitch.dart';
import '../../audio/sound_clock.dart';
import '../../audio/sound_section.dart';
import '../../audio/tone_output.dart';
import '../metronome/bar_clock.dart';
import '../metronome/time_signature.dart';
import 'harmony.dart';

export '../metronome/bar_clock.dart';

/// What the drone plays on its note: the note alone, a chord built on it,
/// or a progression in its key.
enum DroneVoicing { root, chord, progression }

/// How the drone plays on the piano, in time with the metronome's tempo and
/// time signature: the chord struck once a bar, on every beat, one note of
/// it on every beat (an arpeggio), or a double bass walking under it with
/// the piano comping above.
enum DroneStyle {
  /// Struck on the "one" and left to ring.
  held(PianoStyle.bar),
  beat(PianoStyle.beat),
  arpeggio(PianoStyle.arpeggio),
  walking(PianoStyle.walking);

  const DroneStyle(this.piano);

  final PianoStyle piano;
}

/// 4/4 at 80 BPM, for when nothing else keeps time.
class _FixedBar implements BarClock {
  const _FixedBar();

  @override
  int get soundingBpm => 80;

  @override
  TimeSignature get signature => TimeSignature.fourFour;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  Duration get barLength => const Duration(seconds: 3);

  @override
  double? get barPhase => null;
}

/// A chord as the drone plays it.
typedef DroneChord = ({int root, ChordQuality quality});

/// What the player chose in the harmony, kept between launches as the
/// metronome's tempo is: the note, what is played on it and how, and the
/// black keys written with a flat. Whether it plays and where a progression
/// is are not part of it: the app never starts a sound by itself.
typedef DroneSetup = ({
  int pitchClass,
  DroneVoicing voicing,
  DroneVoicing chordVoicing,
  ChordQuality chord,
  Progression progression,
  DroneStyle style,
  bool continuous,
  Set<int> flats,
});

/// State and playback of the drone: the piano playing a note, a chord or a
/// progression, in time with the metronome, to practise on.
///
/// Without a piano (in tests) it falls back to a sustained tone.
class DroneController extends ChangeNotifier implements SoundSection {
  DroneController(
    this._output, {
    BarClock? clock,
    this._piano,
    Duration Function()? outputLatency,
    this.prefetchBass = false,
  }) : _clock = clock ?? const _FixedBar(),
       _outputLatency = outputLatency ?? _noLatency {
    _clock.addListener(_onClockChanged);
    _lastBpm = _clock.soundingBpm;
    _lastSignature = _clock.signature;
  }

  final ToneOutput _output;
  final PianoOutput? _piano;

  /// Whether getting the piano ready (see [preparePiano]) also gets the
  /// double bass ready, whatever the style, once the piano is: then the
  /// walking bass, chosen later, starts at once.
  final bool prefetchBass;
  final BarClock _clock;

  /// How long after the engine plays a sound it is heard (see
  /// AudioRoute.outputLatency): the chord on screen changes that much
  /// later, with the sound.
  final Duration Function() _outputLatency;

  static Duration _noLatency() => Duration.zero;

  /// The one octave the root is played in (scientific numbering: A3 is
  /// 220 Hz, C3 131 Hz): low enough to sit with a bass or a cello, high
  /// enough for a guitar, a voice or a wind, and above what a phone speaker
  /// can hardly play (about 120 Hz).
  static const rootOctave = 3;

  /// Loudness at full level.
  static const _fullVolume = 0.8;

  /// How loud it all is, the phone's volume buttons aside.
  double get _volume => _fullVolume;

  bool _playing = false;
  bool _audioFailed = false;
  Note _note = const Note(9, rootOctave);
  DroneVoicing _voicing = DroneVoicing.root;

  /// The last of [DroneVoicing.root] and [DroneVoicing.chord] chosen, to
  /// come back to from a progression.
  DroneVoicing _chordVoicing = DroneVoicing.root;
  ChordQuality _chord = ChordQuality.major;
  Progression _progression = Progression.values.first;
  DroneStyle _style = DroneStyle.beat;
  int _step = 0;
  Timer? _barTimer;

  /// Whether the app has asked for the piano to be ready (see
  /// [preparePiano]): a change made while nothing plays then gets the new
  /// loop ready too, once the player has stopped changing things.
  var _readyWanted = false;
  Timer? _readyAgain;

  // The piano keeps its own count of bars (see [_scheduleBar]): where in
  // its loop the clock started, and how long it waited for the metronome's
  // next bar line before the first chord.
  final _loopClock = SoundClock();
  late int _lastBpm;
  late TimeSignature _lastSignature;

  /// True when the next piano loop must start from its first chord, because
  /// what it plays has changed; false when only the tempo did, and it
  /// carries on from where it was.
  var _fromTheTop = true;

  /// True when the next piano loop, carrying on, must come in on the next
  /// beat: a new note or chord, struck as the old one would have been.
  var _onTheBeat = false;
  double _a4 = 440;
  var _disposed = false;

  /// Sound changes, one at a time (see [_sync]).
  late final _requests = LatestRequest(_play);

  @override
  bool get isPlaying => _playing;

  /// True when the last attempt to start sound failed on this device.
  bool get audioFailed => _audioFailed;

  /// Whether the first sound since [start] has yet to be heard: the
  /// recordings, or in a browser the audio engine itself, are still being
  /// read or downloaded. Meanwhile a progression stays on its first chord.
  bool get isStarting => _playing && !_soundStarted;

  /// Whether the hub says to wait: the first sound has taken longer than
  /// [waitShownAfter], so that a start that takes a moment does not flash.
  /// Also when a change waits on its bar line, the bar line has come and
  /// the new loop is not ready yet: the old one goes on, faded, meanwhile.
  bool get showsWait =>
      (isStarting && _waitShown) || (_handingOver && waitLeft == null);

  /// Whether the first sound has been on its way for a while (see
  /// [slowStart]): over a slow network, in a browser.
  bool get startsSlowly => isStarting && _slow;

  static const waitShownAfter = Duration(milliseconds: 400);

  /// How long the first sound may take before the hub says it is slow.
  static const slowStart = Duration(seconds: 5);
  var _soundStarted = false;
  var _waitShown = false;
  var _slow = false;
  Timer? _slowTimer;

  /// The note touched: the root, or the key of a progression.
  Note get note => _note;

  /// The octave the root is played in: always [rootOctave].
  int get octave => rootOctave;

  DroneVoicing get voicing => _voicing;

  /// What the chord menu holds: the note alone or a chord, the last chosen
  /// of the two, also while a progression is selected.
  DroneVoicing get chordVoicing => _chordVoicing;
  ChordQuality get chord => _chord;
  Progression get progression => _progression;

  DroneStyle get style => _style;

  /// What the player chose, to keep for the next launch.
  DroneSetup get setup => (
    pitchClass: _note.pitchClass,
    voicing: _voicing,
    chordVoicing: _chordVoicing,
    chord: _chord,
    progression: _progression,
    style: _style,
    continuous: _continuous,
    flats: Set.unmodifiable(_flats),
  );

  /// Comes back to [setup], as kept at the last launch; only while nothing
  /// plays, as the app opens.
  void restore(DroneSetup setup) {
    if (_playing) return;
    _note = Note(setup.pitchClass % 12, rootOctave);
    _voicing = setup.voicing;
    _chordVoicing = setup.chordVoicing == DroneVoicing.progression
        ? DroneVoicing.chord
        : setup.chordVoicing;
    _chord = setup.chord;
    _progression = setup.progression;
    _style = setup.style;
    _continuous = setup.continuous;
    _flats
      ..clear()
      ..addAll(setup.flats.where(respellable.contains));
    _step = 0;
    _fromTheTop = true;
    _notify();
  }

  /// True when the piano plays: always, except in tests and when the player
  /// chose a continuous tone (see the class).
  bool get _patterned => usesPiano;

  /// True when a new note or chord should keep the piano's place in the
  /// bar: struck on every beat (or arpeggiated), the pulse carries on and
  /// the new chord comes in on it, rather than the bar starting over (or
  /// waiting for the metronome's "one") with a stumble in the beat. Struck
  /// once a bar, or as a progression, it starts from the top.
  bool get _keepsTheBeat =>
      _voicing == DroneVoicing.chord && _style != DroneStyle.held;

  /// Whether the piano can play at all (the styles are offered only then).
  bool get hasPiano => _piano != null;

  var _continuous = false;

  /// Whether the player chose a continuous tone instead of the piano struck
  /// again and again.
  bool get continuous => _continuous;

  /// True when the sound is the piano, false when it is the sustained tone.
  bool get usesPiano => _piano != null && !_continuous;

  /// Whether the tone (not the piano) has been started and may still sound.
  var _toneSounding = false;

  /// Chooses between the piano struck again and again, and a tone that
  /// holds on.
  void setContinuous(bool continuous) {
    if (continuous == _continuous) return;
    _update(() => _continuous = continuous, restart: true);
  }

  /// The chord of the progression playing now, 0 for the first.
  int get step => _step;
  double get a4 => _a4;

  /// The chord sounding (or that would sound), or null for the note alone.
  DroneChord? get currentChord => _chordAt(_step);

  /// The Roman numerals of the progression by the pitch class of the root
  /// they stand on ("II" on E in D, or "I · IV" where two chords share a
  /// root); empty outside a progression. They stay put while it plays: the
  /// circle shows where to go, not what is coming.
  Map<int, String> get degreeLabels {
    if (_voicing != DroneVoicing.progression) return const {};
    final labels = <int, List<String>>{};
    for (final step in _progression.steps) {
      final root = (_note.pitchClass + step.offset) % 12;
      final list = labels.putIfAbsent(root, () => []);
      if (!list.contains(step.numeral)) list.add(step.numeral);
    }
    return {for (final e in labels.entries) e.key: e.value.join(' · ')};
  }

  DroneChord? _chordAt(int step) => switch (_voicing) {
    DroneVoicing.root => null,
    DroneVoicing.chord => (root: _note.pitchClass, quality: _chord),
    DroneVoicing.progression => (
      root: (_note.pitchClass + _progression.steps[step].offset) % 12,
      quality: _heldTone(_progression.steps[step].quality),
    ),
  };

  /// The chord a progression plays as the held tone: the 7♭9 without its
  /// ♭9, which held on is a half step that beats against the root and gets
  /// in the way of tuning. The piano plays it whole.
  ChordQuality _heldTone(ChordQuality quality) =>
      !usesPiano && quality == ChordQuality.dominantFlat9
      ? ChordQuality.dominant
      : quality;

  /// The letter (0 = C … 6 = B) the key is written with: C♯ or D♭, F♯ or
  /// G♭ as chosen (see [toggleSpelling]), the usual one for the others.
  int get keyLetter =>
      letterOf(_note.pitchClass, flat: spelledFlat(_note.pitchClass));

  /// The letter of the chord root at [step], counted up the scale from the
  /// key, so that each chord of a progression is spelled as in its key: in
  /// C♯ minor, II–V–I is D♯ø G♯7 C♯m, not E♭ø A♭7 C♯m.
  int letterAt(int step) => _voicing == DroneVoicing.progression
      ? (keyLetter + _progression.steps[step].degree) % 7
      : keyLetter;

  /// The letter of the root sounding now.
  int get rootLetter => letterAt(_step);

  /// The black keys that may be written either way, C♯/D♭ and F♯/G♭, and
  /// which of them are written with a flat.
  static const respellable = {1, 6};
  final _flats = <int>{};

  /// True when [pitchClass] is written with a flat (D♭, G♭).
  bool spelledFlat(int pitchClass) => _flats.contains(pitchClass);

  /// Writes [pitchClass] the other way, C♯ as D♭ and back, if it can be.
  void toggleSpelling(int pitchClass) {
    if (!respellable.contains(pitchClass)) return;
    if (!_flats.remove(pitchClass)) _flats.add(pitchClass);
    _notify();
  }

  static const _majorScale = [0, 2, 4, 5, 7, 9, 11];
  static const _minorScale = [0, 2, 3, 5, 7, 8, 10];

  /// Whether the circle shows the key: with a progression selected, the
  /// note chosen is its key, playing or not.
  bool get showsKey => _voicing == DroneVoicing.progression;

  /// The key is minor (see [Progression.minor]).
  bool get keyIsMinor => _progression.minor;

  /// The seven notes of the key (natural minor for a minor key), as pitch
  /// classes; empty when the circle shows no key.
  Set<int> get keyNotes => showsKey
      ? {
          for (final s in keyIsMinor ? _minorScale : _majorScale)
            (_note.pitchClass + s) % 12,
        }
      : const {};

  /// The letter (0 = C … 6 = B) [pitchClass] is written with in the key, so
  /// that each letter is used once (G♭ major has C♭, not B), or null if the
  /// note is not in the key.
  int? keyLetterOf(int pitchClass) {
    if (!showsKey) return null;
    final degree = (keyIsMinor ? _minorScale : _majorScale).indexOf(
      (pitchClass - _note.pitchClass + 12) % 12,
    );
    return degree < 0 ? null : (keyLetter + degree) % 7;
  }

  /// The root sounding now: the note, or the root of the current chord.
  int get rootPitchClass => currentChord?.root ?? _note.pitchClass;

  /// Frequency of the root sounding, in Hz.
  double get frequency => Note(rootPitchClass, rootOctave).frequency(a4: _a4);

  /// The pitch classes of the other notes of the chord sounding.
  Set<int> get chordTones {
    final c = currentChord;
    if (c == null) return const {};
    return {for (final s in c.quality.semitones) (c.root + s) % 12};
  }

  /// Frequencies currently sounding: the root, then the rest of the chord.
  List<double> get frequencies => _frequenciesOf(currentChord);

  List<double> _frequenciesOf(DroneChord? c) {
    final root = Note(
      c?.root ?? _note.pitchClass,
      rootOctave,
    ).frequency(a4: _a4);
    final ratios = c == null ? [1.0] : c.quality.ratios;
    return [for (final r in ratios) root * r];
  }

  /// The root a little louder than the notes above it.
  static List<double> _gainsFor(int voices) => [
    for (var i = 0; i < voices; i++) i == 0 ? 1.0 : 0.7,
  ];

  @override
  Future<void> start() {
    _playing = true;
    _audioFailed = false;
    _step = 0;
    _fromTheTop = true;
    // The chords move on once the first one is heard (see [_soundStarts]).
    _soundStarted = false;
    _waitShown = _slow = false;
    _slowTimer?.cancel();
    _slowTimer = Timer(waitShownAfter, () {
      _waitShown = true;
      _notify();
      _slowTimer = Timer(slowStart - waitShownAfter, () {
        _slow = true;
        _notify();
      });
    });
    _notify();
    _prepareProgression();
    return _sync();
  }

  /// Applies [changes] (settings of this controller, and of the metronome
  /// it follows) all at once, as a song does: the piano gets one loop ready,
  /// for all of them, instead of one for each setting in turn. Playing, the
  /// change is made as one (see [_update]): a new song comes in on the bar
  /// line, the old one dying away under it.
  void applyAll(VoidCallback changes) {
    final wasPlaying = _playing;
    _batching++;
    try {
      changes();
    } finally {
      _batching--;
    }
    if (_batching > 0 || !wasPlaying || !_playing || _disposed) return;
    if (!_changed) return;
    _changed = false;
    _apply(restart: _restartWanted);
  }

  /// Whether the next loop is awaited by the player (a hand-over, see
  /// [_handOver]): in a page it is mixed a slice at a time.
  var _patient = false;

  /// How many [applyAll] are under way: each setting waits for the others.
  var _batching = 0;

  /// Whether a setting changed during [applyAll], and whether one of them
  /// starts a progression again from its first chord.
  var _changed = false;
  var _restartWanted = false;

  /// True when the next piano loop comes in on a bar line, the one playing
  /// let down under it (see PianoOutput.beginHandOver): a new song,
  /// progression, style or key, as a band changes them.
  var _handOverWanted = false;

  /// True from such a change until the new loop is scheduled: the time to
  /// its bar line then counts down on [_handOverClock].
  var _handingOver = false;
  final _handOverClock = Stopwatch();
  Duration _handOverWait = Duration.zero;

  /// True while a sound change waits for the end of the current event, so
  /// that the settings changed together in it make one change.
  var _syncSoon = false;

  /// The first sound since [start] is on its way out: a held progression
  /// counts its bars from now (the piano counts its own, see [_playPiano]).
  void _soundStarts() {
    if (_soundStarted) return;
    _soundStarted = true;
    _slowTimer?.cancel();
    if (!_patterned) _scheduleBar();
    _notify();
  }

  @override
  Future<void> stop() {
    _playing = false;
    _patient = false;
    _handOverWanted = _handingOver = false;
    _handOverClock.stop();
    _slowTimer?.cancel();
    _barTimer?.cancel();
    _loopClock.stop();
    _notify();
    return _sync();
  }

  Future<void> toggle() => _playing ? stop() : start();

  /// How long until the piano comes in, when it waits for the metronome's
  /// next bar line, or null when it does not wait (or is not playing).
  Duration? get waitLeft {
    if (!_playing) return null;
    if (_handingOver) {
      final left = _handOverWait - _handOverClock.elapsed;
      return left > Duration.zero ? left : null;
    }
    return _loopClock.waitLeft;
  }

  /// What a note key does: plays [pitchClass], switches to it if another
  /// note is playing, or stops it if it is the one already playing.
  Future<void> tapNote(int pitchClass) {
    if (_playing && _note.pitchClass == pitchClass) return stop();
    setPitchClass(pitchClass);
    return _playing ? Future.value() : start();
  }

  void setPitchClass(int pitchClass) {
    if (pitchClass == _note.pitchClass) return;
    _update(
      () => _note = Note(pitchClass, rootOctave),
      restart: true,
      onTheBeat: _keepsTheBeat,
      // A progression's key: a new tune, on the bar line.
      atBarLine: _voicing == DroneVoicing.progression,
    );
  }

  void setVoicing(DroneVoicing voicing) {
    if (voicing == _voicing) return;
    _update(
      () {
        _voicing = voicing;
        if (voicing != DroneVoicing.progression) _chordVoicing = voicing;
      },
      restart: true,
      atBarLine: true,
    );
  }

  void setChord(ChordQuality chord) {
    if (chord == _chord) return;
    _update(() => _chord = chord, onTheBeat: _keepsTheBeat);
  }

  void setProgression(Progression progression) {
    if (progression == _progression) return;
    _update(
      () => _progression = progression,
      restart: true,
      atBarLine: _voicing == DroneVoicing.progression,
    );
  }

  void setStyle(DroneStyle style) {
    if (style == _style) return;
    _update(() => _style = style, restart: true, atBarLine: true);
  }

  void setReferencePitch(double a4) {
    if (a4 == _a4) return;
    _update(() => _a4 = a4, carryOn: true);
  }

  /// Applies [change]; with [restart], a progression starts again from its
  /// first chord. With [carryOn] the piano carries on from where it is; with
  /// [onTheBeat] too, but the new chord comes in on its next beat. With
  /// [atBarLine], while the piano plays, the new loop comes in on the next
  /// bar line (at least a beat away), the old one let down under it
  /// meanwhile, with the beats to go counted (see [beatsLeft]).
  void _update(
    VoidCallback change, {
    bool restart = false,
    bool carryOn = false,
    bool onTheBeat = false,
    bool atBarLine = false,
  }) {
    change();
    if (restart) _step = 0;
    if (atBarLine && _playing && _patterned && _soundStarted) {
      _handOverWanted = true;
    } else if (onTheBeat) {
      _onTheBeat = true;
    }
    if (!carryOn && !onTheBeat) _fromTheTop = true;
    _notify();
    if (!_playing) {
      _prepareAgain();
      return;
    }
    if (_batching > 0) {
      _changed = true;
      _restartWanted |= restart;
      return;
    }
    _apply(restart: restart);
  }

  /// Brings the sound in line with a change made while playing.
  void _apply({required bool restart}) {
    _restartWanted = false;
    if (_handOverWanted && _patterned) {
      _handOver();
      return;
    }
    _prepareProgression();
    if (restart) _scheduleBar();
    _sync();
  }

  /// A change that comes in on the bar line: the old loop is let down by
  /// it, the chords stay on the first one of the new, and the new loop is
  /// mixed once the event that made the change is over, so that the
  /// settings changed together (a song, an action) make one loop.
  void _handOver() {
    _barTimer?.cancel();
    _step = 0;
    _patient = true;
    if (!_handingOver) {
      final clock = _clock;
      final beat = clock.barLength ~/ clock.signature.beats;
      final wait = _piano?.beginHandOver(lead: beat);
      if (wait != null) {
        _handingOver = true;
        _handOverWait = wait;
        _handOverClock
          ..reset()
          ..start();
      } else {
        // Nothing heard yet to hand over from: it simply starts.
        _handOverWanted = false;
      }
    }
    _notify();
    if (_syncSoon) return;
    _syncSoon = true;
    scheduleMicrotask(() {
      _syncSoon = false;
      if (_playing && !_disposed) _sync();
    });
  }

  /// The beats (pulses of the bar) until a waiting sound comes in, for the
  /// countdown in the middle of the dial; null when nothing waits.
  int? get beatsLeft {
    final left = waitLeft;
    if (left == null) return null;
    final pulse = _clock.barLength.inMicroseconds / _clock.signature.beats;
    return math.max(1, (left.inMicroseconds / pulse).ceil());
  }

  /// Gets every chord of the progression ready, so each change of chord
  /// sounds on time.
  void _prepareProgression() {
    if (_voicing != DroneVoicing.progression || _patterned) return;
    final chords = [
      for (var i = 0; i < _progression.steps.length; i++)
        _frequenciesOf(_chordAt(i)),
    ];
    _output
        .prepare([for (final f in chords) (f, _gainsFor(f.length))])
        .catchError((Object error) {
          debugPrint('Drone could not prepare the progression: $error');
        });
  }

  /// Gets the piano ready, while nothing plays, for what a touch would play
  /// now: the first chord then starts sooner.
  void preparePiano() {
    _readyWanted = true;
    _readyAgain?.cancel();
    final piano = _piano;
    if (piano == null || !usesPiano || _playing) return;
    final chords = _pianoChords;
    final walking =
        _style == DroneStyle.walking && _voicing != DroneVoicing.root;
    final signature = _clock.signature;
    // The piano first, and its loop mixed, for the touch that may come now
    // (which then waits for this loop rather than mixing its own); the
    // double bass after it, for a walking bass chosen later.
    Future.wait([
          piano.prepare(chords, bass: walking),
          piano.prerender(
            chords: chords,
            style: _pianoStyle,
            bpm: _clock.soundingBpm * signature.pulsesPerBeat,
            signature: signature,
            a4: _a4,
          ),
        ])
        .then((_) {
          if (walking || !prefetchBass || _playing || _disposed) return null;
          return piano.prepare(chords, bass: true);
        })
        .catchError((Object error) {
          debugPrint('Drone could not prepare the piano: $error');
        });
  }

  /// After a change made while nothing plays, gets the piano ready again
  /// for the new settings, if it was asked to be ready (see [preparePiano]);
  /// once the changes stop, so that trying chords does not mix every one.
  void _prepareAgain() {
    if (!_readyWanted || _disposed) return;
    _readyAgain?.cancel();
    _readyAgain = Timer(const Duration(milliseconds: 400), preparePiano);
  }

  /// How the piano plays the loop: a note on its own is kept sounding,
  /// whatever the style.
  PianoStyle get _pianoStyle =>
      _voicing == DroneVoicing.root ? PianoStyle.drone : _style.piano;

  /// Gets the double bass of the walking bass ready (a few megabytes, read
  /// the first time only), as the list of songs opens: a walked song then
  /// starts without waiting for it, playing or not.
  void prepareBass() {
    final piano = _piano;
    if (piano == null || !usesPiano) return;
    piano.prepare(_pianoChords, bass: true).catchError((Object error) {
      debugPrint('Drone could not prepare the double bass: $error');
    });
  }

  /// Moves to the next chord at the next bar line.
  ///
  /// Held as one tone, the bar line is the metronome's "one" when it is
  /// counting, otherwise a bar of its tempo from now. On the piano, it is
  /// the loop's own: its first chord sounds on a bar line of the metronome
  /// (when it plays), and one chord follows each bar from there.
  void _scheduleBar() {
    _barTimer?.cancel();
    if (!_playing || _voicing != DroneVoicing.progression) return;
    // Not yet heard: the first chord stays until it is.
    if (!_soundStarted) return;
    final bar = _clock.barLength;
    Duration wait;
    if (_patterned) {
      final at = _loopClock.position;
      if (at == null) {
        // Still waiting to come in: the first chord is up on the screen.
        wait = (_loopClock.waitLeft ?? Duration.zero) + bar;
      } else {
        wait =
            bar -
            Duration(microseconds: at.inMicroseconds % bar.inMicroseconds);
      }
      if (wait < const Duration(milliseconds: 40)) wait += bar;
    } else {
      final phase = _clock.barPhase;
      wait = phase == null ? bar : bar * (1 - phase);
      // Just after a bar line, wait for the next one rather than cut short
      // the chord that has only just started.
      if (wait < const Duration(milliseconds: 150)) wait += bar;
    }
    _barTimer = Timer(wait, () {
      if (!_playing || _disposed) return;
      _step = (_step + 1) % _progression.steps.length;
      _notify();
      if (!_patterned) _sync();
      _scheduleBar();
    });
  }

  /// The metronome changed its tempo, its time signature: the
  /// piano follows, carrying on from where it was for a change of tempo,
  /// from the top of the bar for another time signature.
  void _onClockChanged() {
    final bpm = _clock.soundingBpm, signature = _clock.signature;
    final changed = bpm != _lastBpm || signature != _lastSignature;
    if (signature != _lastSignature) _fromTheTop = true;
    _lastBpm = bpm;
    _lastSignature = signature;
    if (!changed || !_playing || !_patterned || _disposed || _batching > 0) {
      return;
    }
    _sync();
  }

  /// The chords of the loop, one per bar, as the piano plays them.
  List<PianoChord> get _pianoChords {
    // MIDI numbers: the root in its octave, and the octave of keys from C4
    // up where the rest of every chord sits, clear of the root.
    const bass = (rootOctave + 1) * 12;
    const floor = bass + 12;

    // The root as the bass, the other notes close together above it, in one
    // place on the keyboard whatever the chord: from one chord to the next
    // they move as little as they can, as a pianist's hand does.
    List<int> notes(DroneChord? c) {
      // A single note: the piano plays the root alone.
      if (c == null) return [bass + _note.pitchClass];
      final upper = [
        for (final s in c.quality.semitones) floor + (c.root + s - floor) % 12,
      ]..sort();
      return [bass + c.root, ...upper];
    }

    return [
      if (_voicing == DroneVoicing.progression)
        for (var i = 0; i < _progression.steps.length; i++) notes(_chordAt(i))
      else
        notes(_chordAt(0)),
    ];
  }

  /// Brings the sound in line with [isPlaying] and the current settings.
  ///
  /// Starts and retunes run one after the other, each reading the state
  /// when its turn comes, so two quick changes never mix their voices; the
  /// first one starts at once, so sound begins without delay. Stopping
  /// happens at once too, and a start still under way stops again as soon
  /// as it is done, so a stop pressed while the audio engine is starting
  /// really silences it. Never throws: a failure shows in [audioFailed].
  ///
  /// Changes made while one is under way are applied all at once when it is
  /// done, as the metronome does: holding + renders the piano only as often
  /// as it can, always with the latest tempo, instead of catching up with
  /// every step in turn.
  Future<void> _sync() {
    if (!_playing || _disposed) return _silence();
    return _requests.run();
  }

  /// What the piano's loop is mixed from: two loops with the same are the
  /// same sound.
  String _loopKey(List<PianoChord> chords, int bpm, TimeSignature signature) =>
      '$chords ${_pianoStyle.name} $bpm ${signature.numerator}/'
      '${signature.denominator} ${signature.groups} $_a4';

  /// The loop the piano plays now (see [_loopKey]), or null when it plays
  /// nothing, or something being replaced.
  String? _sounding;

  Future<void> _play() async {
    if (!_playing || _disposed) return;
    try {
      if (_patterned) {
        await _playPiano();
      } else {
        // Not awaited when there is no piano: sound starts without delay.
        final piano = _piano;
        if (piano != null) await piano.stop();
        final f = frequencies;
        _sounding = null;
        _toneSounding = true;
        await _output.play(f, _gainsFor(f.length), _volume);
        if (_playing && !_disposed) _soundStarts();
      }
    } catch (error) {
      debugPrint('Drone could not start: $error');
      _playing = false;
      _audioFailed = true;
      _slowTimer?.cancel();
      _barTimer?.cancel();
      _notify();
    }
    // Stopped (or failed) while starting: voices that only started now
    // must not keep sounding unseen.
    if (!_playing || _disposed) await _silence();
  }

  /// Starts (or replaces) the piano's loop, and lines the chord shown up
  /// with it.
  Future<void> _playPiano() async {
    // Coming from the sustained tone: it must not go on under the piano.
    if (_toneSounding) {
      _toneSounding = false;
      await _output.stop();
    }
    final handOver = _handOverWanted;
    final fromTheTop = _fromTheTop || handOver;
    final onTheBeat = _onTheBeat && !handOver;
    final patient = _patient;
    _fromTheTop = false;
    _onTheBeat = false;
    _patient = false;
    _handOverWanted = false;
    final chords = _pianoChords;
    final bpm = _lastBpm = _clock.soundingBpm;
    final signature = _lastSignature = _clock.signature;
    // What the change asks for is what already plays (changed and changed
    // back, or set to what it was): the loop goes on, not mixed again.
    final wanted = _loopKey(chords, bpm, signature);
    if (wanted == _sounding && !(fromTheTop && !handOver)) {
      if (handOver) {
        _piano!.cancelHandOver();
        _handingOver = false;
        _handOverClock.stop();
        // The chords shown go back to the one the loop is on.
        final at = _loopClock.position;
        if (_voicing == DroneVoicing.progression && at != null) {
          _step =
              (at.inMicroseconds ~/ _clock.barLength.inMicroseconds) %
              chords.length;
        }
        _scheduleBar();
      }
      _notify();
      return;
    }
    _sounding = null;
    final started = await _piano!.play(
      chords: chords,
      style: _pianoStyle,
      // The piano counts pulses, like the clicks: three a beat in 6/8.
      bpm: bpm * signature.pulsesPerBeat,
      signature: signature,
      a4: _a4,
      volume: _volume,
      startAt: fromTheTop ? Duration.zero : null,
      onTheBeat: onTheBeat,
      patient: patient,
      handOver: handOver,
    );
    _sounding = wanted;
    // Scheduled: from now on the wait is the loop's own (see [waitLeft]).
    if (handOver) {
      _handingOver = false;
      _handOverClock.stop();
    }
    if (!_playing || _disposed) return;
    final bar = _clock.barLength;
    // Lined up with the sound as it is heard, as the metronome does.
    _loopClock.heard(started, latency: _outputLatency(), fresh: fromTheTop);
    _soundStarted = true;
    _slowTimer?.cancel();
    if (_voicing == DroneVoicing.progression) {
      // Waiting for the metronome, the first chord is still to come.
      _step = started.delay > Duration.zero
          ? 0
          : (_loopClock.startedAt.inMicroseconds / bar.inMicroseconds).floor() %
                chords.length;
      _notify();
      _scheduleBar();
    } else {
      // Whoever shows the countdown (see [waitLeft]) hears of it now: the wait
      // is only known once the piano is scheduled.
      _notify();
    }
  }

  Future<void> _silence() async {
    _sounding = null;
    try {
      _toneSounding = false;
      await _output.stop();
      final piano = _piano;
      if (piano != null) await piano.stop();
    } catch (error) {
      debugPrint('Drone could not stop: $error');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _playing = false;
    _slowTimer?.cancel();
    _barTimer?.cancel();
    _readyAgain?.cancel();
    _clock.removeListener(_onClockChanged);
    _sync();
    super.dispose();
  }
}
