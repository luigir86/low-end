import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/pitch.dart';
import '../features/metronome/metronome_controller.dart';
import '../features/metronome/subdivision.dart';
import '../features/metronome/time_signature.dart';
import '../features/tuner/drone/drone_controller.dart';
import '../features/tuner/drone/harmony.dart';
import '../features/tuner/tuner_tuning.dart';
import 'app_navigation.dart';

/// How note names are chosen: from the app language, or fixed.
enum NoteNaming { auto, solfege, letters }

/// How the twelve notes are laid round the harmony circle: by fifths, or in
/// semitones, as on the fingerboard.
enum CircleLayout { fifths, chromatic }

/// The player's preferences, kept on the phone between launches.
class AppSettings extends ChangeNotifier {
  /// Settings that are not saved anywhere; used in tests.
  AppSettings() : _prefs = null;

  AppSettings._(this._prefs) {
    final prefs = _prefs!;
    // Each value is checked for its type as well: one saved by another
    // build or edited by hand must fall back to the default, not stop the
    // app from opening.
    final language = _read<String>(prefs, _languageKey);
    _languageCode = supportedLanguages.contains(language) ? language : null;
    _naming =
        NoteNaming.values.asNameMap()[_read<String>(prefs, _namingKey)] ??
        NoteNaming.auto;
    final a4 = _read<num>(prefs, _a4Key)?.toDouble();
    _a4 = a4 != null && isReferencePitch(a4) ? a4 : 440;
    _circleLayout =
        CircleLayout.values.asNameMap()[_read<String>(
          prefs,
          _circleLayoutKey,
        )] ??
        CircleLayout.fifths;
    // Nothing saved (every install before this setting existed) means the
    // scientific numbering, whatever the note names are.
    _octaveNumbering =
        OctaveNumbering.values.asNameMap()[_read<String>(
          prefs,
          _octaveNumberingKey,
        )] ??
        OctaveNumbering.scientific;
    final instrument = TunerTuning.values
        .asNameMap()[_read<String>(prefs, _tuningKey)];
    _instrument = instrument == null || instrument.isChromatic
        ? TunerTuning.guitar
        : instrument;
    _chromatic = _read<bool>(prefs, _chromaticKey) ?? true;
    _keepScreenOn = _read<bool>(prefs, _keepScreenOnKey) ?? true;
    _seenGuide = _read<bool>(prefs, _seenGuideKey) ?? false;
    _gesturesLocked = _read<bool>(prefs, _gesturesLockedKey) ?? false;
    _seenSwipeHint = _read<bool>(prefs, _seenSwipeHintKey) ?? false;
    final tolerance = _read<num>(prefs, _inTuneKey)?.toDouble();
    _inTuneCents = inTuneChoices.contains(tolerance) ? tolerance! : 5;
    final label = _read<String>(prefs, _signatureKey);
    _signature = TimeSignature.all.firstWhere(
      (s) => s.label == label,
      orElse: () => TimeSignature.fourFour,
    );
    _subdivision =
        Subdivision.values.asNameMap()[_read<String>(prefs, _subdivisionKey)] ??
        Subdivision.quarters;
    _backbeat = _read<bool>(prefs, _backbeatKey) ?? false;
    _transposition =
        Transposition.values.asNameMap()[_read<String>(
          prefs,
          _transpositionKey,
        )] ??
        Transposition.c;
    final bpm = _read<num>(prefs, _bpmKey);
    _bpm = bpm != null && bpm.isFinite
        ? bpm.round().clamp(
            MetronomeController.minBpm,
            MetronomeController.maxBpmFor(_signature),
          )
        : MetronomeController.startBpm;
    _section =
        AppSection.values.asNameMap()[_read<String>(prefs, _sectionKey)] ??
        AppSection.metronome;
    _drone = _readDrone(prefs);
  }

  /// The harmony as it was left, or null if nothing was kept (the first
  /// launch) or it cannot be read: each part falls back to its default.
  static DroneSetup? _readDrone(SharedPreferences prefs) {
    final note = _read<int>(prefs, _droneNoteKey);
    if (note == null || note < 0 || note > 11) return null;
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.asNameMap()[_read<String>(prefs, key)] ?? fallback;
    final flats = _read<List<Object?>>(prefs, _droneFlatsKey) ?? const [];
    return (
      pitchClass: note,
      voicing: pick(DroneVoicing.values, _droneVoicingKey, DroneVoicing.chord),
      chordVoicing: pick(
        DroneVoicing.values,
        _droneChordVoicingKey,
        DroneVoicing.chord,
      ),
      chord: pick(ChordQuality.values, _droneChordKey, ChordQuality.major),
      progression: pick(
        Progression.values,
        _droneProgressionKey,
        Progression.values.first,
      ),
      style: pick(DroneStyle.values, _droneStyleKey, DroneStyle.beat),
      continuous: _read<bool>(prefs, _droneContinuousKey) ?? false,
      flats: {
        for (final f in flats)
          if (f is String && int.tryParse(f) != null) int.parse(f),
      },
    );
  }

  /// Reads the saved settings.
  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  static const supportedLanguages = ['en', 'it'];
  static const _languageKey = 'language';
  static const _namingKey = 'note_names';
  static const _a4Key = 'reference_pitch';
  static const _keepScreenOnKey = 'keep_screen_on';
  static const _seenGuideKey = 'seen_guide';
  static const _gesturesLockedKey = 'gestures_locked';
  static const _seenSwipeHintKey = 'seen_swipe_hint';
  static const _inTuneKey = 'in_tune_cents';
  static const _octaveNumberingKey = 'octave_numbering';
  static const _tuningKey = 'tuner_tuning';
  static const _chromaticKey = 'tuner_chromatic';

  /// The widths of the "in tune" zone the player can choose, in cents on
  /// each side of the note.
  static const inTuneChoices = [2.0, 5.0, 10.0];
  static const _circleLayoutKey = 'circle_layout';
  static const _bpmKey = 'metronome_bpm';
  static const _signatureKey = 'time_signature';
  static const _subdivisionKey = 'metronome_subdivision';
  static const _backbeatKey = 'metronome_backbeat';
  static const _transpositionKey = 'tuner_transposition';
  static const _sectionKey = 'section';
  static const _droneNoteKey = 'harmony_note';
  static const _droneVoicingKey = 'harmony_voicing';
  static const _droneChordVoicingKey = 'harmony_chord_voicing';
  static const _droneChordKey = 'harmony_chord';
  static const _droneProgressionKey = 'harmony_progression';
  static const _droneStyleKey = 'harmony_style';
  static const _droneContinuousKey = 'harmony_continuous';
  static const _droneFlatsKey = 'harmony_flats';

  final SharedPreferences? _prefs;
  String? _languageCode;
  NoteNaming _naming = NoteNaming.auto;
  double _a4 = 440;

  /// The value saved under [key] if it has type [T], otherwise null.
  static T? _read<T>(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    return value is T ? value : null;
  }

  /// Saves in the background: the setting already applies, and a failed
  /// write only means it is forgotten at the next launch.
  void _save(Future<bool>? write) {
    write?.catchError((Object error) {
      debugPrint('Settings could not be saved: $error');
      return false;
    });
  }

  /// 'en' or 'it', or null to follow the phone.
  String? get languageCode => _languageCode;
  NoteNaming get naming => _naming;

  /// Frequency of A4 in Hz, shared by the tuner and the drone.
  double get a4 => _a4;

  /// The locale to show the app in, or null to follow the phone.
  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);

  /// The note names to use when the app shows [appLocale].
  NoteNames noteNames(Locale appLocale) => switch (_naming) {
    NoteNaming.solfege => NoteNames.solfege,
    NoteNaming.letters => NoteNames.letters,
    NoteNaming.auto =>
      appLocale.languageCode == 'it' ? NoteNames.solfege : NoteNames.letters,
  };

  void setLanguage(String? code) {
    assert(code == null || supportedLanguages.contains(code));
    _languageCode = code;
    _save(
      code == null
          ? _prefs?.remove(_languageKey)
          : _prefs?.setString(_languageKey, code),
    );
    notifyListeners();
  }

  void setNaming(NoteNaming naming) {
    _naming = naming;
    _save(_prefs?.setString(_namingKey, naming.name));
    notifyListeners();
  }

  var _octaveNumbering = OctaveNumbering.scientific;

  /// How octave numbers are written, apart from the note names: scientific
  /// (A4 = 440 Hz, the low E of a bass is E1) or Italian (La3, Mi0).
  OctaveNumbering get octaveNumbering => _octaveNumbering;

  void setOctaveNumbering(OctaveNumbering numbering) {
    if (numbering == _octaveNumbering) return;
    _octaveNumbering = numbering;
    _save(_prefs?.setString(_octaveNumberingKey, numbering.name));
    notifyListeners();
  }

  var _instrument = TunerTuning.guitar;
  var _chromatic = true;

  /// What the tuner compares notes with: any note, or the open strings of
  /// the chosen instrument.
  TunerTuning get tuning => _chromatic ? TunerTuning.chromatic : _instrument;

  /// The instrument chosen last, kept while the tuner is chromatic.
  TunerTuning get tunerInstrument => _instrument;

  bool get tunerChromatic => _chromatic;

  void setTunerChromatic(bool chromatic) {
    if (chromatic == _chromatic) return;
    _chromatic = chromatic;
    _save(_prefs?.setBool(_chromaticKey, chromatic));
    notifyListeners();
  }

  /// Chooses an instrument and tunes to its strings.
  void setTunerInstrument(TunerTuning instrument) {
    assert(!instrument.isChromatic);
    if (instrument == _instrument && !_chromatic) return;
    _instrument = instrument;
    _chromatic = false;
    _save(_prefs?.setString(_tuningKey, instrument.name));
    _save(_prefs?.setBool(_chromaticKey, false));
    notifyListeners();
  }

  var _transposition = Transposition.c;

  /// The key of the instrument the tuner names notes for: concert pitch, or
  /// the written notes of a B♭, E♭ or F instrument. Only the chromatic tuner
  /// uses it: the strings of the instruments in the menu sound as written.
  Transposition get transposition => _transposition;

  void setTransposition(Transposition transposition) {
    if (transposition == _transposition) return;
    _transposition = transposition;
    _save(_prefs?.setString(_transpositionKey, transposition.name));
    notifyListeners();
  }

  void setReferencePitch(double hz) {
    assert(isReferencePitch(hz));
    _a4 = hz;
    _save(_prefs?.setDouble(_a4Key, hz));
    notifyListeners();
  }

  CircleLayout _circleLayout = CircleLayout.fifths;
  bool _keepScreenOn = true;

  // Unsaved settings (tests) have nothing to teach: the guide is for the
  // first launch of the real app.
  bool _seenGuide = true;

  /// Whether the guide to the gestures has been shown once already.
  bool get seenGuide => _seenGuide;

  void markGuideSeen() {
    if (_seenGuide) return;
    _seenGuide = true;
    _save(_prefs?.setBool(_seenGuideKey, true));
  }

  // Unsaved settings (tests) have nothing to teach here either.
  bool _seenSwipeHint = true;

  /// Whether the hint to swipe between sections, shown the first time the
  /// phone is turned sideways, has been shown.
  bool get seenSwipeHint => _seenSwipeHint;

  void markSwipeHintSeen() {
    if (_seenSwipeHint) return;
    _seenSwipeHint = true;
    _save(_prefs?.setBool(_seenSwipeHintKey, true));
  }

  var _gesturesLocked = false;

  /// Whether the swipes between sections are turned off, for a rehearsal:
  /// only taps are left, so nothing changes by accident with a bow in the
  /// hand.
  bool get gesturesLocked => _gesturesLocked;

  void setGesturesLocked(bool value) {
    if (value == _gesturesLocked) return;
    _gesturesLocked = value;
    _save(_prefs?.setBool(_gesturesLockedKey, value));
    notifyListeners();
  }

  var _inTuneCents = 5.0;

  /// How many cents either side of a note still count as in tune.
  double get inTuneCents => _inTuneCents;

  void setInTuneCents(double cents) {
    assert(inTuneChoices.contains(cents));
    if (cents == _inTuneCents) return;
    _inTuneCents = cents;
    _save(_prefs?.setDouble(_inTuneKey, cents));
    notifyListeners();
  }

  /// Whether the screen stays on while something plays or the tuner
  /// listens.
  bool get keepScreenOn => _keepScreenOn;

  /// The order of the notes on the harmony circle.
  CircleLayout get circleLayout => _circleLayout;

  void setCircleLayout(CircleLayout layout) {
    if (layout == _circleLayout) return;
    _circleLayout = layout;
    _save(_prefs?.setString(_circleLayoutKey, layout.name));
    notifyListeners();
  }

  void setKeepScreenOn(bool value) {
    if (value == _keepScreenOn) return;
    _keepScreenOn = value;
    _save(_prefs?.setBool(_keepScreenOnKey, value));
    notifyListeners();
  }

  var _bpm = MetronomeController.startBpm;
  var _signature = TimeSignature.fourFour;
  var _subdivision = Subdivision.quarters;
  var _backbeat = false;

  /// The tempo, time signature, subdivision and click on 2 and 4 the
  /// metronome had last time.
  int get metronomeBpm => _bpm;
  TimeSignature get metronomeSignature => _signature;
  Subdivision get metronomeSubdivision => _subdivision;
  bool get metronomeBackbeat => _backbeat;

  /// Keeps the metronome's tempo, time signature, subdivision and
  /// click on 2 and 4 for the next launch. Nothing on screen listens to
  /// them, so nobody is told.
  void rememberMetronome({
    required int bpm,
    required TimeSignature signature,
    Subdivision subdivision = Subdivision.quarters,
    bool backbeat = false,
  }) {
    if (subdivision != _subdivision) {
      _subdivision = subdivision;
      _save(_prefs?.setString(_subdivisionKey, subdivision.name));
    }
    if (backbeat != _backbeat) {
      _backbeat = backbeat;
      _save(_prefs?.setBool(_backbeatKey, backbeat));
    }
    if (bpm != _bpm) {
      _bpm = bpm;
      _save(_prefs?.setInt(_bpmKey, bpm));
    }
    if (signature != _signature) {
      _signature = signature;
      _save(_prefs?.setString(_signatureKey, signature.label));
    }
  }

  var _section = AppSection.metronome;

  /// The section on screen when the app was left: it opens there again, so
  /// that whoever plays along with the harmony need not pass the metronome.
  AppSection get section => _section;

  /// Keeps [section] for the next launch; nothing listens to it.
  void rememberSection(AppSection section) {
    if (section == _section) return;
    _section = section;
    _save(_prefs?.setString(_sectionKey, section.name));
  }

  DroneSetup? _drone;

  /// The harmony as it was left, or null the first time.
  DroneSetup? get drone => _drone;

  /// Keeps the harmony's choices for the next launch, as the metronome's
  /// are; nothing listens to them.
  void rememberDrone(DroneSetup setup) {
    final was = _drone;
    _drone = setup;
    final prefs = _prefs;
    if (prefs == null) return;
    if (was?.pitchClass != setup.pitchClass) {
      _save(prefs.setInt(_droneNoteKey, setup.pitchClass));
    }
    if (was?.voicing != setup.voicing) {
      _save(prefs.setString(_droneVoicingKey, setup.voicing.name));
    }
    if (was?.chordVoicing != setup.chordVoicing) {
      _save(prefs.setString(_droneChordVoicingKey, setup.chordVoicing.name));
    }
    if (was?.chord != setup.chord) {
      _save(prefs.setString(_droneChordKey, setup.chord.name));
    }
    if (was?.progression != setup.progression) {
      _save(prefs.setString(_droneProgressionKey, setup.progression.name));
    }
    if (was?.style != setup.style) {
      _save(prefs.setString(_droneStyleKey, setup.style.name));
    }
    if (was?.continuous != setup.continuous) {
      _save(prefs.setBool(_droneContinuousKey, setup.continuous));
    }
    if (!setEquals(was?.flats, setup.flats)) {
      _save(
        prefs.setStringList(_droneFlatsKey, [
          for (final f in setup.flats) '$f',
        ]),
      );
    }
  }
}
