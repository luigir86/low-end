import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../audio/piano_output.dart';
import '../../../audio/piano_sound.dart';
import '../../../audio/pitch.dart';
import '../../../audio/tone_output.dart';
import '../../metronome/time_signature.dart';
import 'harmony.dart';

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

/// The length, position, tempo and time signature of the bar a progression
/// follows: the metronome's, so chords change on its "one". It notifies when
/// the tempo or the time signature change.
abstract interface class BarClock implements Listenable {
  /// Beats per minute of the figure the tempo counts: in 6/8, dotted
  /// quarters (see [TimeSignature.pulsesPerBeat]).
  int get bpm;
  TimeSignature get signature;

  Duration get barLength;

  /// How far into the bar it is, 0 to 1, or null when not counting.
  double? get barPhase;
}

/// 4/4 at 80 BPM, for when nothing else keeps time.
class _FixedBar implements BarClock {
  const _FixedBar();

  @override
  int get bpm => 80;

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
class DroneController extends ChangeNotifier {
  DroneController(
    this._output, {
    BarClock? clock,
    this._piano,
    Duration Function()? outputLatency,
    this.prefetchBass = false,
  }) : _clock = clock ?? const _FixedBar(),
       _outputLatency = outputLatency ?? _noLatency {
    _clock.addListener(_onClockChanged);
    _lastBpm = _clock.bpm;
    _lastSignature = _clock.signature;
  }

  final ToneOutput _output;
  final PianoOutput? _piano;

  /// Whether getting the piano ready (see [preparePiano]) also gets the
  /// double bass ready, whatever the style, once the piano is: then the
  /// walking bass, chosen later, starts at once. On the phone, where the
  /// recordings are read away from the screen; not in a browser, where
  /// reading them holds the screen up.
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

  // The piano keeps its own count of bars (see [_scheduleBar]): where in
  // its loop the clock started, and how long it waited for the metronome's
  // next bar line before the first chord.
  final _loopClock = Stopwatch();
  Duration _loopStartedAt = Duration.zero;
  Duration _loopWaiting = Duration.zero;
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

  /// The latest sound change still under way, if any (see [_sync]).
  Future<void>? _pending;

  /// A change waiting for the one under way, if any: later changes join it
  /// rather than queue up behind it (see [_sync]).
  Future<void>? _queued;

  bool get isPlaying => _playing;

  /// True when the last attempt to start sound failed on this device.
  bool get audioFailed => _audioFailed;

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
      quality: _progression.steps[step].quality,
    ),
  };

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

  Future<void> start() {
    _playing = true;
    _audioFailed = false;
    _step = 0;
    _fromTheTop = true;
    _notify();
    _prepareProgression();
    _scheduleBar();
    return _sync();
  }

  Future<void> stop() {
    _playing = false;
    _barTimer?.cancel();
    _loopClock.stop();
    _notify();
    return _sync();
  }

  Future<void> toggle() => _playing ? stop() : start();

  /// How long until the piano comes in, when it waits for the metronome's
  /// next bar line, or null when it does not wait (or is not playing).
  Duration? get waitLeft {
    if (!_playing || !_loopClock.isRunning) return null;
    final left = _loopWaiting - _loopClock.elapsed;
    return left > Duration.zero ? left : null;
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
    );
  }

  void setVoicing(DroneVoicing voicing) {
    if (voicing == _voicing) return;
    _update(() {
      _voicing = voicing;
      if (voicing != DroneVoicing.progression) _chordVoicing = voicing;
    }, restart: true);
  }

  void setChord(ChordQuality chord) {
    if (chord == _chord) return;
    _update(() => _chord = chord, onTheBeat: _keepsTheBeat);
  }

  void setProgression(Progression progression) {
    if (progression == _progression) return;
    _update(() => _progression = progression, restart: true);
  }

  void setStyle(DroneStyle style) {
    // Chosen by the player: no song's style to give back any more.
    _styleBeforeSong = null;
    _setStyle(style);
  }

  void _setStyle(DroneStyle style) {
    if (style == _style) return;
    _update(() => _style = style, restart: true);
  }

  /// The style the player had before a song switched it to the walking
  /// bass, given back by the next song that is not walked; null when no
  /// song changed it, or the player chose a style since.
  DroneStyle? _styleBeforeSong;

  /// The style of an example song: the walking bass if it is [walking] (a
  /// jazz standard), otherwise the style the player had before a walked
  /// song changed it, if one did.
  void setSongStyle({required bool walking}) {
    if (walking) {
      if (_style == DroneStyle.walking) return;
      _styleBeforeSong ??= _style;
      _setStyle(DroneStyle.walking);
    } else if (_styleBeforeSong case final before?) {
      _styleBeforeSong = null;
      _setStyle(before);
    }
  }

  void setReferencePitch(double a4) {
    if (a4 == _a4) return;
    _update(() => _a4 = a4, carryOn: true);
  }

  /// Applies [change]; with [restart], a progression starts again from its
  /// first chord. With [carryOn] the piano carries on from where it is; with
  /// [onTheBeat] too, but the new chord comes in on its next beat.
  void _update(
    VoidCallback change, {
    bool restart = false,
    bool carryOn = false,
    bool onTheBeat = false,
  }) {
    change();
    if (restart) _step = 0;
    if (onTheBeat) _onTheBeat = true;
    if (!carryOn && !onTheBeat) _fromTheTop = true;
    _notify();
    if (!_playing) return;
    _prepareProgression();
    if (restart) _scheduleBar();
    _sync();
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
    final piano = _piano;
    if (piano == null || !usesPiano || _playing) return;
    final chords = _pianoChords;
    final walking =
        _style == DroneStyle.walking && _voicing != DroneVoicing.root;
    piano
        .prepare(chords, bass: walking)
        // The piano first, for the touch that may come now; the double
        // bass after it, for a walking bass chosen later.
        .then((_) {
          if (walking || !prefetchBass || _playing || _disposed) return null;
          return piano.prepare(chords, bass: true);
        })
        .catchError((Object error) {
          debugPrint('Drone could not prepare the piano: $error');
        });
  }

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
    final bar = _clock.barLength;
    Duration wait;
    if (_patterned) {
      final elapsed = _loopClock.elapsed;
      if (elapsed < _loopWaiting) {
        // Still waiting to come in: the first chord is up on the screen.
        wait = _loopWaiting + bar - elapsed;
      } else {
        final at = _loopStartedAt + elapsed - _loopWaiting;
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
    final bpm = _clock.bpm, signature = _clock.signature;
    final changed = bpm != _lastBpm || signature != _lastSignature;
    if (signature != _lastSignature) _fromTheTop = true;
    _lastBpm = bpm;
    _lastSignature = signature;
    if (!changed || !_playing || !_patterned || _disposed) return;
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
    // The change already waiting reads the state when its turn comes, so it
    // takes this one in too.
    if (_queued case final queued?) return queued;
    final previous = _pending;
    final Future<void> done;
    if (previous == null) {
      done = _play();
    } else {
      late final Future<void> next;
      next = previous.then((_) {
        // Its turn: from now on, a change waits for it to finish.
        if (identical(_queued, next)) _queued = null;
        return _play();
      });
      done = _queued = next;
    }
    late final Future<void> tracked;
    tracked = done.whenComplete(() {
      if (identical(_pending, tracked)) _pending = null;
    });
    return _pending = tracked;
  }

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
        _toneSounding = true;
        await _output.play(f, _gainsFor(f.length), _volume);
      }
    } catch (error) {
      debugPrint('Drone could not start: $error');
      _playing = false;
      _audioFailed = true;
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
    final fromTheTop = _fromTheTop;
    final onTheBeat = _onTheBeat;
    _fromTheTop = false;
    _onTheBeat = false;
    final chords = _pianoChords;
    final bpm = _lastBpm = _clock.bpm;
    final signature = _lastSignature = _clock.signature;
    final started = await _piano!.play(
      chords: chords,
      // A note on its own is kept sounding, whatever the style.
      style: _voicing == DroneVoicing.root ? PianoStyle.drone : _style.piano,
      // The piano counts pulses, like the clicks: three a beat in 6/8.
      bpm: bpm * signature.pulsesPerBeat,
      signature: signature,
      a4: _a4,
      volume: _volume,
      startAt: fromTheTop ? Duration.zero : null,
      onTheBeat: onTheBeat,
    );
    if (!_playing || _disposed) return;
    final bar = _clock.barLength;
    // Lined up with the sound as it is heard, as the metronome does.
    final latency = _outputLatency();
    if (fromTheTop) {
      _loopStartedAt = started.position;
      _loopWaiting = started.delay + latency;
    } else {
      _loopStartedAt = started.position - latency;
      _loopWaiting = started.delay;
    }
    _loopClock
      ..reset()
      ..start();
    if (_voicing == DroneVoicing.progression) {
      // Waiting for the metronome, the first chord is still to come.
      _step = started.delay > Duration.zero
          ? 0
          : (_loopStartedAt.inMicroseconds / bar.inMicroseconds).floor() %
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
    _barTimer?.cancel();
    _clock.removeListener(_onClockChanged);
    _sync();
    super.dispose();
  }
}
