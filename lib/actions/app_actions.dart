import 'dart:convert';

import '../app/app_navigation.dart';
import '../app/settings.dart';
import '../audio/pitch.dart';
import '../features/metronome/metronome_controller.dart';
import '../features/metronome/subdivision.dart';
import '../features/metronome/time_signature.dart';
import '../features/tuner/drone/drone_controller.dart';
import '../features/tuner/drone/example_song.dart';
import '../features/tuner/drone/harmony.dart';
import '../features/tuner/tuner_controller.dart';
import '../features/tuner/tuner_reading.dart';
import '../features/tuner/tuner_tuning.dart';

/// One thing the app can do, described so a language model (or any other
/// program) can find it, call it and understand the answer.
///
/// [parameters] is a JSON Schema object, the format used for tools by MCP and
/// by the Claude, Gemini and OpenAI APIs.
class AppAction {
  const AppAction({
    required this.name,
    required this.description,
    this.parameters = const {},
    this.required = const [],
  });

  final String name;
  final String description;
  final Map<String, Map<String, Object?>> parameters;
  final List<String> required;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'input_schema': {
      'type': 'object',
      'properties': parameters,
      if (required.isNotEmpty) 'required': required,
      'additionalProperties': false,
    },
  };
}

/// An action was called with arguments it cannot use.
class ActionError implements Exception {
  ActionError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The app's action layer: everything a player can do on screen, available
/// as named actions with JSON arguments and a JSON answer.
///
/// The screens and the outside world (deep links today; Android App
/// Functions, Siri Shortcuts or an MCP server later) go through the same
/// controllers, so an assistant can do anything a finger can. Every answer
/// carries the full [state], so the caller always knows where things stand.
///
/// Rules every action follows: each sound (metronome, Harmony, tuner) is
/// started and stopped on its own, from its own section; the tabs and the
/// swipes only navigate, and locking the gestures does not affect actions. A
/// start action opens its section, since the sound is played from there; the
/// tuner is the exception that listens only while on screen, and listening
/// pauses the metronome and Harmony (`_pauseForTuner` in low_end_app.dart).
class AppActions {
  AppActions({
    required this.drone,
    required this.metronome,
    required this.tuner,
    required this.navigation,
    required this.settings,
  });

  final DroneController drone;
  final MetronomeController metronome;
  final TunerController tuner;
  final AppNavigation navigation;
  final AppSettings settings;

  static const _note = {
    'type': 'string',
    'description':
        'Note name in English (A, Bb, F#) or Italian (La, Sib, Fa#). The '
        'drone always plays it in octave 3 (A3 = 220 Hz with A4 at 440), so '
        'an octave number, if given, is ignored.',
  };

  static final catalog = <AppAction>[
    const AppAction(
      name: 'get_state',
      description:
          'Returns what the app is doing now, without changing anything: the '
          'section on screen (metronome, drone, tuner); the tuner (status '
          'idle, starting, listening, permissionDenied or failed, and the '
          'last note heard with its cents off); the Harmony section, called '
          'drone (playing, note, voicing, chord, progression, style, held tone, '
          'current step of a progression); the metronome (playing, '
          'tempo, time signature, subdivision, click on 2 and 4) and the '
          'settings (reference A, language, note and octave names, the '
          "tuner's instrument, in-tune zone and transposition, the circle, "
          'screen on, locked gestures). '
          '"playing" is true as soon as a start is asked, also while the '
          "sound waits for the other one's next bar line. Notes are always "
          'written with letters and octave (Bb4), whatever the note names '
          "setting. Loudness follows the phone's media volume.",
    ),
    const AppAction(
      name: 'open_section',
      description:
          'Shows a section of the app (also when the gestures are locked). '
          'Nothing is started or stopped, except by the tuner: leaving it '
          'turns the microphone off, and arriving at it starts listening '
          'only if neither the metronome nor Harmony is playing and it was '
          'not paused with tuner_stop (the sound is never stopped by '
          'arriving; use tuner_start for that).',
      parameters: {
        'section': {
          'type': 'string',
          'enum': ['tuner', 'drone', 'metronome'],
        },
      },
      required: ['section'],
    ),
    const AppAction(
      name: 'tuner_start',
      description:
          'Opens the tuner and starts listening through the microphone: it '
          'recognises any note played. If the metronome or Harmony is '
          'playing, they are paused, as when the dial of the tuner is '
          'touched (the player sees a notice with a "Resume" button; '
          'nothing resumes by itself). The tuner stops by itself when '
          'another section or the settings page opens, or the app goes to '
          'the background. The answer says "listening", or why not '
          '(permissionDenied, failed); read the note with get_state.',
    ),
    const AppAction(
      name: 'tuner_stop',
      description:
          'Pauses the tuner and turns the microphone off. It stays paused, '
          'also when its section or the app comes back, until tuner_start or '
          'a touch on its dial. It does not start anything else.',
    ),
    const AppAction(
      name: 'drone_play',
      description:
          'Opens the Harmony section (so the tuner, if listening, stops '
          'listening) and plays the piano to practise on: a note, a chord or '
          'a progression. Any setting given is applied first. If it is '
          'already playing, only the settings change. If the metronome is '
          "playing, the piano comes in on the metronome's next bar line, "
          'after a countdown shown on screen; "playing" is already true '
          'then.',
      parameters: _droneParameters,
    ),
    const AppAction(
      name: 'drone_stop',
      description:
          'Stops the Harmony piano (also during the countdown before it '
          'comes in). Does not change section.',
    ),
    const AppAction(
      name: 'metronome_start',
      description:
          'Opens the metronome (so the tuner, if listening, stops listening) '
          'and starts it, at the tempo given or the current one; the time '
          'signature, subdivision and backbeat given are applied first. If '
          'it is already playing, only the settings change. If Harmony is '
          "playing, the click comes in on the piano's next bar line, after a "
          'countdown.',
      parameters: _metronomeParameters,
    ),
    const AppAction(
      name: 'metronome_stop',
      description:
          'Stops the metronome (also during the countdown before it comes '
          'in). Does not change section.',
    ),
    const AppAction(
      name: 'metronome_set',
      description:
          'Changes the time signature, the tempo, what sounds inside each '
          'beat or the click on 2 and 4, without starting, stopping or '
          'changing section. Give at least one. The settings are remembered '
          'for the next launch.',
      parameters: _metronomeParameters,
    ),
    const AppAction(
      name: 'drone_set',
      description:
          'Changes the Harmony settings (give any of them) without starting, '
          'stopping or changing section.',
      parameters: _droneParameters,
    ),
    AppAction(
      name: 'set_reference_pitch',
      description:
          'Sets the frequency of A4, shared by the tuner and the drone, '
          'and saves it in the settings. Whole hertz only.',
      parameters: {
        'hz': {
          'type': 'number',
          'minimum': minReferencePitch,
          'maximum': maxReferencePitch,
          'description': 'Frequency of A4 in Hz, a whole number.',
        },
      },
      required: ['hz'],
    ),
    const AppAction(
      name: 'settings_set',
      description:
          'Changes and saves the app settings (give any of them): the '
          'language, how note names and octaves are written, the tuner '
          "(instrument, in-tune zone, the key of a transposing instrument), "
          'the Harmony circle, keeping the screen on and locking the swipes '
          'between sections. All the values are checked first: if one is '
          'wrong, none is applied.',
      parameters: {
        'transposition': {
          'type': 'string',
          'enum': ['c', 'bFlat', 'eFlat', 'f'],
          'description':
              'The chromatic tuner names the written note of an instrument '
              'in this key (B♭ clarinet or trumpet, E♭ alto sax, F horn); '
              '"c" names notes as they sound.',
        },
        'language': {
          'type': 'string',
          'enum': ['system', 'en', 'it'],
          'description': 'App language; "system" follows the phone.',
        },
        'note_names': {
          'type': 'string',
          'enum': ['auto', 'solfege', 'letters'],
          'description':
              '"solfege" is Do Re Mi, "letters" is C D E, "auto" follows the '
              'app language. The octave numbers are set apart, with '
              'octave_numbering.',
        },
        'octave_numbering': {
          'type': 'string',
          'enum': ['scientific', 'italian'],
          'description':
              'How octaves are numbered on screen: scientific (A4 = 440 Hz, '
              'the low E of a bass is E1) or italian (La3 = 440 Hz, Mi0).',
        },
        'tuner_instrument': {
          'type': 'string',
          'enum': [
            'chromatic',
            'guitar',
            'bass',
            'ukulele',
            'violin',
            'viola',
            'cello',
          ],
          'description':
              'What the tuner tunes: any note (chromatic), or the open '
              'strings of an instrument, shown with their string number. '
              'Bass listens up to 700 Hz, the others up to 2800 Hz.',
        },
        'in_tune_cents': {
          'type': 'number',
          'enum': [2, 5, 10],
          'description':
              'How close a note must be, in cents either way, to count as '
              'in tune.',
        },
        'circle_layout': {
          'type': 'string',
          'enum': ['fifths', 'chromatic'],
          'description':
              'How the twelve notes are laid round the Harmony dial: by '
              'fifths, or in semitones as on the fingerboard.',
        },
        'keep_screen_on': {
          'type': 'boolean',
          'description':
              'Keeps the screen on while something plays or the tuner '
              'listens.',
        },
        'lock_gestures': {
          'type': 'boolean',
          'description':
              'Turns off swiping between sections (the tabs and the actions '
              'still work).',
        },
      },
    ),
  ];

  static const _metronomeParameters = {
    'time_signature': {
      'type': 'string',
      'enum': ['1/1', '2/4', '3/4', '4/4', '5/4', '6/8', '7/8', '9/8', '12/8'],
      'description':
          'The bar, with its beats grouped as counted (5/4 as 3+2, 7/8 as '
          '2+2+3). Applied before bpm, which is checked against it.',
    },
    'bpm': {
      'type': 'integer',
      'minimum': MetronomeController.minBpm,
      'maximum': MetronomeController.maxEighthBpm,
      'description':
          'Beats per minute of the note value the tempo counts in the '
          'current time signature: quarter notes in x/4, dotted quarters in '
          '6/8, 9/8 and 12/8, eighth notes in 7/8. At most '
          '${MetronomeController.maxBpm}, or '
          '${MetronomeController.maxEighthBpm} in 7/8.',
    },
    'subdivision': {
      'type': 'string',
      'enum': [
        'quarters',
        'eighths',
        'swing_eighths',
        'triplets',
        'sixteenths',
        'swing_sixteenths',
      ],
      'description':
          'What fills each beat, with softer clicks: quarters (the beat '
          'alone), eighths, swing_eighths, triplets, sixteenths or '
          'swing_sixteenths. The swung ones are written straight and played '
          'long-short, as MuseScore plays "Swing" (the second note at 60% of '
          'the pair). With the click on 2 and 4, only beats 2 and 4 are '
          'subdivided. Only heard in bars counted in quarter notes.',
    },
    'backbeat': {
      'type': 'boolean',
      'description':
          'Clicks on beats 2 and 4 only, beats 1 and 3 silent, as a jazz '
          'hi-hat. Only heard in 2/4 and 4/4.',
    },
  };

  static const _droneParameters = {
    'note': _note,
    'voicing': {
      'type': 'string',
      'enum': ['root', 'chord', 'progression'],
      'description':
          'The note alone, the chord built on it, or a progression in its '
          'key (one chord per bar, at the metronome tempo). On screen the '
          'note alone is the first entry of the chord menu.',
    },
    'chord': {
      'type': 'string',
      'enum': [
        'major',
        'minor',
        'dominant',
        'major7',
        'minor7',
        'halfDiminished',
        'diminished',
        'sus4',
      ],
      'description':
          'The chord played when voicing is "chord": major, minor, dominant '
          '(7), major7 (maj7), minor7 (m7), halfDiminished (m7b5), diminished '
          '(dim) or sus4.',
    },
    'progression': {
      'type': 'string',
      'enum': [
        'oneSixFourFive',
        'oneFiveSixFour',
        'andalusian',
        'blues',
        'minorBlues',
        'twoFiveOne',
        'minorTwoFiveOne',
        'oneSixTwoFive',
        'circleOfFifths',
      ],
      'description':
          'The progression played when voicing is "progression", one chord a '
          'bar, each 4, 8 or 12 bars long, from the easiest: pop and rock '
          '(I-VI-IV-V, I-V-VI-IV or the Andalusian cadence, '
          'minor), blues (12-bar blues, minor blues) and jazz (II-V-I as '
          'Dm7 G7 Cmaj7 Cmaj7, minor II-V-I, I-VI-II-V, circle of fifths in '
          '8 bars as in Autumn Leaves). I-VI-IV-V, the "giro di Do", is the one '
          'chosen first.',
    },
    'style': {
      'type': 'string',
      'enum': ['held', 'beat', 'arpeggio', 'walking'],
      'description':
          'How the piano plays the note, chord or progression: struck once a bar '
          '(held), on every beat, as an '
          'arpeggio, one note a beat, or as a walking bass: a jazz line on a '
          'plucked double bass, one note a beat, with the piano comping '
          'lightly above (the sound follows the tempo and time signature of '
          'the metronome).',
    },
    'held_tone': {
      'type': 'boolean',
      'description':
          'true for a steady tone instead of the piano struck again and '
          'again (the style then does not apply); false for the piano.',
    },
    'flat': {
      'type': 'boolean',
      'description':
          'Writes the note, if it is C# or F#, as Db or Gb (true) or back '
          '(false), on the dial and in the chord names. The sound is the '
          'same.',
    },
    'song': {
      'type': 'string',
      'enum': [
        'Stand by Me',
        'With or Without You',
        'Hit the Road Jack',
        'Sweet Home Chicago',
        'Mr. P.C.',
        'Tune Up',
        'Blue Bossa',
        'Autumn Leaves',
      ],
      'description':
          'An example song: sets its key, its progression and its tempo '
          '(the metronome goes to 4/4 at that tempo), as touching it in the '
          'list of example songs does. A note or progression given too is '
          'applied after it.',
    },
  };

  /// Actions that change the saved settings. A `lowend://` link is open to
  /// any web page, so it may not use them: only a caller that talks to the
  /// app directly (an assistant through the action layer, the screens) may.
  static const settingsActions = {'set_reference_pitch', 'settings_set'};

  /// Runs the action [name] and returns `{ok: true, state: …}`, or
  /// `{ok: false, error: …}` when the name or the arguments are wrong.
  ///
  /// [fromLink] is true for an action that arrives as a `lowend://` link.
  Future<Map<String, Object?>> call(
    String name, [
    Map<String, Object?> args = const {},
    bool fromLink = false,
  ]) async {
    try {
      final action = catalog.where((a) => a.name == name).firstOrNull;
      if (action == null) throw ActionError('Unknown action "$name".');
      if (fromLink && settingsActions.contains(name)) {
        throw ActionError(
          '"$name" changes the saved settings, so it cannot be run from a '
          'link: change them in the app\'s Settings, or call the action '
          'directly instead of through a lowend:// link.',
        );
      }
      for (final key in args.keys) {
        if (!action.parameters.containsKey(key)) {
          throw ActionError('"$name" has no parameter "$key".');
        }
      }
      for (final key in action.required) {
        if (args[key] == null) throw ActionError('"$name" needs "$key".');
      }
      await _run(name, args);
      return {'ok': true, 'state': state()};
    } on ActionError catch (error) {
      return {'ok': false, 'error': error.message};
    }
  }

  Future<void> _run(String name, Map<String, Object?> args) async {
    switch (name) {
      case 'get_state':
        break;
      case 'open_section':
        navigation.open(_enum(AppSection.values, args['section']));
      case 'tuner_start':
        navigation.open(AppSection.tuner);
        // Opening the tab starts the tuner only when nothing plays and it was
        // not paused; asking for it here also clears that pause, and the app
        // then pauses whatever plays (see low_end_app.dart). Waiting for the
        // start means the answer says "listening" (or why not).
        await tuner.start();
      case 'tuner_stop':
        // Like the Pause button: the tuner stays paused when its tab or the
        // app comes back.
        await tuner.pause();
      case 'drone_play':
        final change = _droneChange(args);
        // Each sound plays from its own section; on the tuner it would
        // pause again at once.
        navigation.open(AppSection.drone);
        change();
        if (!drone.isPlaying) await drone.start();
      case 'metronome_start':
        final change = _metronomeChange(args);
        navigation.open(AppSection.metronome);
        change();
        await metronome.start();
      case 'metronome_stop':
        await metronome.stop();
      case 'metronome_set':
        if (args.values.every((v) => v == null)) {
          throw ActionError(
            '"metronome_set" needs "time_signature", "bpm", "subdivision" '
            'or "backbeat".',
          );
        }
        _metronomeChange(args)();
      case 'drone_stop':
        await drone.stop();
      case 'drone_set':
        _droneChange(args)();
      case 'set_reference_pitch':
        final hz = _number(args['hz'], 'hz');
        if (!isReferencePitch(hz)) {
          throw ActionError('"hz" must be a whole number from 415 to 445.');
        }
        settings.setReferencePitch(hz);
      case 'settings_set':
        // Everything is checked before anything changes, so a call refused
        // for one argument leaves the others as they were.
        final language = args['language'];
        final code = switch (language) {
          null || 'system' => null,
          'en' || 'it' => language as String,
          _ => throw ActionError('"language" must be system, en or it.'),
        };
        final naming = args['note_names'] == null
            ? null
            : _enum(NoteNaming.values, args['note_names']);
        final transposition = args['transposition'] == null
            ? null
            : _enum(Transposition.values, args['transposition']);
        final numbering = args['octave_numbering'] == null
            ? null
            : _enum(OctaveNumbering.values, args['octave_numbering']);
        final instrument = args['tuner_instrument'] == null
            ? null
            : _enum(TunerTuning.values, args['tuner_instrument']);
        final inTune = switch (args['in_tune_cents']) {
          null => null,
          final num c when AppSettings.inTuneChoices.contains(c.toDouble()) =>
            c.toDouble(),
          _ => throw ActionError('"in_tune_cents" must be 2, 5 or 10.'),
        };
        final layout = args['circle_layout'] == null
            ? null
            : _enum(CircleLayout.values, args['circle_layout']);
        final screenOn = _bool(args, 'keep_screen_on');
        final locked = _bool(args, 'lock_gestures');
        if (language != null) settings.setLanguage(code);
        if (naming != null) settings.setNaming(naming);
        if (transposition != null) settings.setTransposition(transposition);
        if (numbering != null) settings.setOctaveNumbering(numbering);
        if (instrument == TunerTuning.chromatic) {
          settings.setTunerChromatic(true);
        } else if (instrument != null) {
          settings.setTunerInstrument(instrument);
        }
        if (inTune != null) settings.setInTuneCents(inTune);
        if (layout != null) settings.setCircleLayout(layout);
        if (screenOn != null) settings.setKeepScreenOn(screenOn);
        if (locked != null) settings.setGesturesLocked(locked);
    }
  }

  /// Checks the metronome arguments and returns the change they ask for,
  /// to be made only once all of them are known to be good.
  void Function() _metronomeChange(Map<String, Object?> args) {
    final signature = switch (args['time_signature']) {
      null => null,
      final Object label =>
        TimeSignature.all.where((s) => s.label == label).firstOrNull ??
            (throw ActionError(
              '"time_signature" must be one of '
              '${TimeSignature.all.map((s) => s.label).join(', ')}.',
            )),
    };
    final bpm = _bpm(args, signature ?? metronome.signature);
    final subdivision = switch (args['subdivision']) {
      null => null,
      final Object name =>
        Subdivision.values.where((s) => s.id == name).firstOrNull ??
            (throw ActionError(
              '"$name" must be one of '
              '${Subdivision.values.map((s) => s.id).join(', ')}.',
            )),
    };
    final backbeat = switch (args['backbeat']) {
      null => null,
      final bool b => b,
      _ => throw ActionError('"backbeat" must be true or false.'),
    };
    return () {
      if (signature != null) metronome.setSignature(signature);
      if (bpm != null) metronome.setBpm(bpm);
      if (subdivision != null) metronome.setSubdivision(subdivision);
      if (backbeat != null) metronome.setBackbeat(backbeat);
    };
  }

  /// Checks the drone arguments and returns the change they ask for, to be
  /// made only once all of them are known to be good.
  void Function() _droneChange(Map<String, Object?> args) {
    int? pitchClass;
    if (args['note'] case final Object note) {
      pitchClass =
          parseNote('$note')?.pitchClass ??
          (throw ActionError('Unknown note "$note".'));
    }
    final voicing = args['voicing'] == null
        ? null
        : _enum(DroneVoicing.values, args['voicing']);
    final progression = args['progression'] == null
        ? null
        : _enum(Progression.values, args['progression']);
    final chord = args['chord'] == null
        ? null
        : _enum(ChordQuality.values, args['chord']);
    final style = args['style'] == null
        ? null
        : _enum(DroneStyle.values, args['style']);
    final heldTone = _bool(args, 'held_tone');
    final flat = _bool(args, 'flat');
    final song = switch (args['song']) {
      null => null,
      final Object title =>
        exampleSongs.where((s) => s.title == title).firstOrNull ??
            (throw ActionError(
              '"song" must be one of '
              '${exampleSongs.map((s) => s.title).join(', ')}.',
            )),
    };
    return () {
      if (song != null) {
        applySong(song, drone: drone, metronome: metronome);
      }
      if (pitchClass != null) drone.setPitchClass(pitchClass);
      if (voicing != null) drone.setVoicing(voicing);
      if (chord != null) drone.setChord(chord);
      if (progression != null) drone.setProgression(progression);
      if (style != null) drone.setStyle(style);
      if (heldTone != null) drone.setContinuous(heldTone);
      final key = drone.note.pitchClass;
      if (flat != null && flat != drone.spelledFlat(key)) {
        drone.toggleSpelling(key);
      }
    };
  }

  /// The boolean argument [key], or null when not given.
  static bool? _bool(Map<String, Object?> args, String key) =>
      switch (args[key]) {
        null => null,
        final bool b => b,
        _ => throw ActionError('"$key" must be true or false.'),
      };

  /// Everything an assistant needs to know about the app right now.
  Map<String, Object?> state() {
    final hz = tuner.frequency;
    final reading = hz == null
        ? null
        : TunerReading.of(
            hz,
            a4: settings.a4,
            tolerance: settings.inTuneCents,
            tuning: settings.tuning,
          );
    // As on screen: a transposing instrument reads its own notes only in the
    // chromatic tuner; the strings of the instruments sound as written.
    final transposition = settings.tuning.isChromatic
        ? settings.transposition
        : Transposition.c;
    return {
      'section': navigation.section.name,
      'settings': {
        'reference_pitch_hz': settings.a4,
        'language': settings.languageCode ?? 'system',
        'note_names': settings.naming.name,
        'transposition': settings.transposition.name,
        'octave_numbering': settings.octaveNumbering.name,
        'tuner_instrument': settings.tuning.name,
        'in_tune_cents': settings.inTuneCents,
        'circle_layout': settings.circleLayout.name,
        'keep_screen_on': settings.keepScreenOn,
        'lock_gestures': settings.gesturesLocked,
      },
      'tuner': {
        'status': tuner.status.name,
        'reading': reading == null
            ? null
            : {
                'target': noteId(reading.target),
                'played': noteId(reading.played),
                // What a transposing instrument reads, in the chromatic
                // tuner (see settings.transposition).
                'written': noteId(transposition.written(reading.target)),
                'frequency_hz': _round(reading.frequency),
                'cents': _round(reading.cents),
                'in_tune': reading.inTune,
              },
      },
      'drone': {
        'playing': drone.isPlaying,
        'note': noteId(drone.note),
        'frequency_hz': _round(drone.frequency),
        'voicing': drone.voicing.name,
        'chord': drone.chord.name,
        'progression': drone.progression.name,
        'style': drone.style.name,
        'held_tone': drone.continuous,
        'flat': drone.spelledFlat(drone.note.pitchClass),
        'progression_step': drone.voicing == DroneVoicing.progression
            ? drone.step
            : null,
        'audio_failed': drone.audioFailed,
      },
      'metronome': {
        'playing': metronome.isPlaying,
        'bpm': metronome.bpm,
        'time_signature': metronome.signature.label,
        'subdivision': metronome.subdivision.id,
        'backbeat': metronome.backbeat,
      },
    };
  }

  /// Turns `lowend://action/drone_play?note=A` (or just its path,
  /// `/drone_play?note=A`, as Flutter hands deep links over) into an
  /// action name and its arguments, or null when it isn't an action link.
  static (String, Map<String, Object?>)? parseLink(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final name = segments.last;
    final action = catalog.where((a) => a.name == name).firstOrNull;
    if (action == null) return null;
    return (
      name,
      {
        for (final MapEntry(:key, :value) in uri.queryParameters.entries)
          key: switch (action.parameters[key]?['type']) {
            'integer' || 'number' => num.tryParse(value) ?? value,
            'boolean' => switch (value) {
              'true' || '1' || 'yes' => true,
              'false' || '0' || 'no' => false,
              _ => value,
            },
            _ => value,
          },
      },
    );
  }

  static double _round(double v) => (v * 10).round() / 10;

  static T _enum<T extends Enum>(List<T> values, Object? name) =>
      values.where((v) => v.name == name).firstOrNull ??
      (throw ActionError(
        '"$name" must be one of ${values.map((v) => v.name).join(', ')}.',
      ));

  /// The `bpm` argument, checked against [signature], or null when not
  /// given.
  int? _bpm(Map<String, Object?> args, TimeSignature signature) {
    final v = args['bpm'];
    if (v == null) return null;
    final bpm = _number(v, 'bpm');
    final max = MetronomeController.maxBpmFor(signature);
    if (bpm != bpm.roundToDouble() ||
        bpm < MetronomeController.minBpm ||
        bpm > max) {
      throw ActionError(
        '"bpm" must be a whole number from ${MetronomeController.minBpm} '
        'to $max in ${signature.label}.',
      );
    }
    return bpm.round();
  }

  static double _number(Object? v, String key) =>
      v is num ? v.toDouble() : (throw ActionError('"$key" must be a number.'));
}

const _sharpNames = [
  'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B', //
];

/// A note as plain ASCII, such as "Bb1", easy for programs to read.
String noteId(Note n) => '${_sharpNames[n.pitchClass]}${n.octave}';

const _letters = {'c': 0, 'd': 2, 'e': 4, 'f': 5, 'g': 7, 'a': 9, 'b': 11};
const _solfege = {
  'do': 0,
  're': 2,
  'mi': 4,
  'fa': 5,
  'sol': 7,
  'la': 9,
  'si': 11,
};

/// Reads a note name in English or Italian, with an optional sharp or flat
/// and octave: "A", "Bb2", "F♯", "La", "Sib1", "do#". The octave is null when
/// not given.
({int pitchClass, int? octave})? parseNote(String text) {
  final match = RegExp(
    r'^\s*(do|re|mi|fa|sol|la|si|[a-g])\s*(#|♯|b|♭)?\s*(-?\d)?\s*$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  final name = match[1]!.toLowerCase();
  var pitchClass = _solfege[name] ?? _letters[name]!;
  pitchClass += switch (match[2]) {
    '#' || '♯' => 1,
    'b' || '♭' => -1,
    _ => 0,
  };
  final octave = match[3] == null ? null : int.parse(match[3]!);
  return (pitchClass: pitchClass % 12, octave: octave);
}

/// The action catalog as JSON, published in `docs/llm-actions.json` for
/// assistants and the people who connect them.
String exportActions() =>
    '${const JsonEncoder.withIndent('  ').convert([for (final a in AppActions.catalog) a.toJson()])}\n';
