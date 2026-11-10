import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../actions/app_actions.dart';
import '../audio/audio_route.dart';
import '../audio/audio_scope.dart';
import '../audio/click_output.dart';
import '../audio/just_audio_track_output.dart';
import '../audio/mic_input.dart';
import '../audio/piano_output.dart';
import '../audio/pitch.dart';
import '../audio/soloud_engine.dart';
import '../audio/system_track_files.dart';
import '../audio/take_recorder.dart';
import '../audio/tone_output.dart';
import '../audio/track_files.dart';
import '../audio/track_output.dart';
import '../audio/web_audio_engine.dart';
import '../features/harmony/drone_controller.dart';
import '../features/harmony/harmony_names.dart'
    show chordSymbol, progressionName;
import '../features/metronome/metronome_controller.dart';
import '../features/player/player_controller.dart';
import '../features/player/recording_controller.dart';
import '../features/player/take_name.dart';
import '../features/tuner/tuner_controller.dart';
import '../l10n/app_localizations.dart';
import 'app_navigation.dart';
import 'background_audio.dart';
import 'home_shell.dart';
import 'playback_rules.dart';
import 'screen_awake.dart';
import 'settings.dart';
import 'theme.dart';

class LowEndApp extends StatefulWidget {
  /// How long after the first frame the harmony's piano is got ready, when
  /// the app opens on it: a touch before then plays all the same.
  @visibleForTesting
  static const prepareAfterLaunch = Duration(milliseconds: 1200);

  const LowEndApp({
    super.key,
    this.toneOutput,
    this.clickOutput,
    this.micInput,
    this.settings,
    this.backgroundAudio,
    this.pianoOutput,
    this.screenAwake,
    this.audioRoute,
    this.trackOutput,
    this.trackFiles,
    this.takeRecorder,
  });

  /// Audio output for the drone; defaults to the device's speakers.
  final ToneOutput? toneOutput;

  /// Audio output for the drone's piano; defaults to the device's speakers.
  final PianoOutput? pianoOutput;

  /// Audio output for the metronome; defaults to the device's speakers.
  final ClickOutput? clickOutput;

  /// Audio input for the tuner; defaults to the device's microphone.
  final MicInput? micInput;

  /// Saved preferences (see [AppSettings.load]); unsaved defaults if null.
  final AppSettings? settings;

  /// Keeps the sound going in the background; the phone's foreground
  /// service by default.
  final BackgroundAudio? backgroundAudio;

  /// Keeps the screen on while something plays or the tuner listens; the
  /// phone's wake lock by default.
  final ScreenAwake? screenAwake;

  /// Where the sound comes out, and when the headphones are unplugged;
  /// Android's audio manager by default, nothing with test outputs.
  final AudioRoute? audioRoute;

  /// The Player's sound; the system's player by default, and a silent one
  /// when a test gives its own tone or click output.
  final TrackOutput? trackOutput;

  /// The Player's files (the file chooser); the system's by default, and
  /// finger-less ones when a test gives its own tone or click output.
  final TrackFiles? trackFiles;

  /// The Player's recorder; the microphone by default, and one that records
  /// nothing when a test gives its own tone or click output.
  final TakeRecorder? takeRecorder;

  @override
  State<LowEndApp> createState() => _LowEndAppState();
}

class _LowEndAppState extends State<LowEndApp> with WidgetsBindingObserver {
  late final _drone = DroneController(
    widget.toneOutput ?? SoLoudToneOutput(),
    // Progressions change chord on the metronome's bars.
    clock: _metronome,
    // With a tone output given (as tests do) there is no piano, unless one
    // is given too: the real one needs the audio engine.
    piano:
        widget.pianoOutput ??
        (widget.toneOutput == null ? SoLoudPianoOutput() : null),
    outputLatency: () => _route.outputLatency,
  );
  late final _metronome = MetronomeController(
    widget.clickOutput ?? SoLoudClickOutput(),
    outputLatency: () => _route.outputLatency,
  );
  // The real route only with the real sound: tests give their own outputs.
  // A web page cannot know it.
  late final AudioRoute _route =
      widget.audioRoute ??
      (widget.toneOutput == null && widget.clickOutput == null
          ? (kIsWeb ? SpeakerAudioRoute() : AndroidAudioRoute())
          : FakeAudioRoute());
  StreamSubscription<void>? _unplugged;
  StreamSubscription<void>? _interrupted;
  StreamSubscription<void>? _playerInterrupted;
  late final _tuner = TunerController(widget.micInput ?? RecordMicInput());
  // The Player makes its system player at the first track, not before
  // (RNF-AVV-01); the tests never touch the real one.
  late final _player = PlayerController(
    widget.trackOutput ??
        (_testOutputs ? SilentTrackOutput() : JustAudioTrackOutput()),
    widget.trackFiles ?? (_testOutputs ? FakeTrackFiles() : systemTrackFiles()),
  );
  // The microphone is opened only when REC is touched.
  late final _recording = RecordingController(
    widget.takeRecorder ??
        (_testOutputs ? FakeTakeRecorder() : RecordTakeRecorder()),
    player: _player,
    navigation: _navigation,
    nameTake: (now) =>
        takeName(_notificationTexts(), _settings.nextTakeNumber(now), now),
  );
  bool get _testOutputs =>
      widget.toneOutput != null || widget.clickOutput != null;
  late final BackgroundAudio _background =
      widget.backgroundAudio ?? MediaNotificationAudio();
  late final ScreenAwake _screenAwake =
      widget.screenAwake ?? WakelockScreenAwake();
  // The app opens on the section it was left on.
  late final _navigation = AppNavigation(section: _settings.section);

  /// With the screen off or the app in the background, the drone and the
  /// metronome carry on, kept alive by a media notification.
  late final _notification = NowPlayingNotification(
    drone: _drone,
    metronome: _metronome,
    player: _player,
    background: _background,
    describe: () => _describePlaying(_notificationTexts()),
    playingTitle: () => _notificationTexts().backgroundPlaying,
    appTitle: () => _notificationTexts().appTitle,
  );
  late final _pauses = PauseRules(
    drone: _drone,
    metronome: _metronome,
    player: _player,
    notification: _notification,
  );

  /// Shows the notice that the sound paused for the tuner.
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final _settings = widget.settings ?? AppSettings();
  late final _actions = AppActions(
    drone: _drone,
    metronome: _metronome,
    tuner: _tuner,
    player: _player,
    recording: _recording,
    navigation: _navigation,
    settings: _settings,
  );

  // The reference A last given to the drone: the settings also change for
  // the language and the note names, which must not retune it.
  late double _droneA4 = _settings.a4;

  @override
  void initState() {
    super.initState();
    // The drone plays at the reference A chosen in the settings.
    _drone.setReferencePitch(_droneA4);
    // The metronome comes back as it was left: time signature first, since
    // the fastest tempo depends on it.
    _metronome.setSignature(_settings.metronomeSignature);
    _metronome.setBpm(_settings.metronomeBpm);
    _metronome.setSubdivision(_settings.metronomeSubdivision);
    _metronome.setBackbeat(_settings.metronomeBackbeat);
    _metronome.addListener(_rememberMetronome);
    // The harmony comes back as it was left; the first time it opens on the
    // piano playing a progression, the mode most played and the most
    // inviting: the giro di Do in A (A F#m D E7, as in Stand by Me), a chord
    // on every beat, with the chord menu on the chord (set before it plays,
    // so nothing starts yet).
    final harmony = _settings.drone;
    if (harmony != null) {
      _drone.restore(harmony);
    } else if (_drone.hasPiano) {
      _drone
        ..setVoicing(DroneVoicing.chord)
        ..setVoicing(DroneVoicing.progression);
    }
    _drone.addListener(_rememberDrone);
    // The Player's track, speed and passage come back too; nothing is asked
    // of the system until the tab is reached.
    final track = _settings.player;
    if (track != null) _player.restore(track);
    _player.addListener(_rememberPlayer);
    _tuner.highestHz = _settings.tuning.highestHz;
    _settings.addListener(_onSettingsChanged);
    _navigation.addListener(_onNavigationChanged);
    _navigation.sliding.addListener(_preparePiano);
    _drone.addListener(_onPlayingChanged);
    _metronome.addListener(_onPlayingChanged);
    _player.addListener(_onPlayerChanged);
    // Coming to the tuner starts it only when nothing plays.
    _tuner.autoStartAllowed = () =>
        !_drone.isPlaying && !_metronome.isPlaying && !_player.isPlaying;
    _tuner.addListener(_onTunerChanged);
    _commands = _background.commands.listen(_notification.command);
    // Headphones pulled out: the sound stops before it reaches the speaker.
    _unplugged = _route.unplugged.listen(
      (_) => _pauseFor(PauseReason.unplugged),
    );
    // The iPhone's browser cut the sound (a call, the locked screen): the
    // app must not look as if it played on, unheard.
    _interrupted = _route.interrupted.listen(
      (_) => _pauseFor(PauseReason.interrupted),
    );
    // A call, or another player, took the Player's sound.
    _playerInterrupted = _player.interruptions.listen(
      (_) => _pauseFor(PauseReason.interrupted),
    );
    // If the app opens on the tuner (where it was left, or a link), start
    // listening once the first frame is up, so the microphone never delays
    // it. Opening on the harmony, its piano is got ready a moment later
    // (RNF-AVV-01): reading the recordings holds the screen's thread, and
    // the first frames, the slide hint among them, must not wait for it.
    // In a browser only the recordings are read: the sound engine waits
    // for a touch (see SoLoudPianoOutput.prepare).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_navigation.tunerVisible) _tuner.resume();
      if (_navigation.section == AppSection.player) _player.activate();
      _prepareAtLaunch = Timer(LowEndApp.prepareAfterLaunch, _preparePiano);
      if (_startsEngineAhead) {
        _engineAhead = Timer(_engineAheadAfter, _startEngineWhenStill);
      }
    });
    // Registered before MaterialApp's own observer, so action links are
    // handled here instead of being treated as pages to open.
    WidgetsBinding.instance.addObserver(this);
    final initial = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (initial != '/') _runLink(Uri.parse(initial));
  }

  void _rememberMetronome() => _settings.rememberMetronome(
    bpm: _metronome.bpm,
    signature: _metronome.signature,
    subdivision: _metronome.subdivision,
    backbeat: _metronome.backbeat,
  );

  void _rememberDrone() => _settings.rememberDrone(_drone.setup);

  void _rememberPlayer() {
    // While a new track opens the old one is gone and the new one not yet
    // there: nothing is written until it is known which stays.
    if (_player.status == PlayerStatus.opening) return;
    _settings.rememberPlayer(_player.setup);
  }

  void _onSettingsChanged() {
    _keepScreenOn();
    // The notification names the notes in the player's way.
    _notification.refresh();
    // The tuner listens as high as the instrument chosen plays.
    _tuner.highestHz = _settings.tuning.highestHz;
    if (_settings.a4 == _droneA4) return;
    _droneA4 = _settings.a4;
    _drone.setReferencePitch(_droneA4);
  }

  /// The tuner listens whenever it is on screen, and only then; coming back
  /// it listens again, unless the player paused it.
  ///
  /// Coming to the Tuner tab, it listens only when nothing plays: a swipe too
  /// far must not stop the click or the drone. Then the player starts it
  /// with a touch (see [_onTunerChanged]). Leaving the tab, nothing starts by
  /// itself: the click must not come back unasked, out of time with the band.
  void _onNavigationChanged() {
    _navigation.tunerVisible ? _tuner.resume() : _tuner.stop();
    if (_navigation.section == AppSection.player) {
      _player.activate();
    }
    _settings.rememberSection(_navigation.section);
    _preparePiano();
    _keepScreenOn();
  }

  /// In a browser the audio engine may sound only after a touch, but it can
  /// start before one, held silent: it does, a moment after the first
  /// frame, so that the first touch only wakes it (web/flutter_bootstrap.js)
  /// and the first sound need not wait for the engine to start (in Safari
  /// that was more than half a second). With the real sound only, and not
  /// on the very first opening, which soon reloads itself.
  bool get _startsEngineAhead =>
      kIsWeb &&
      widget.toneOutput == null &&
      widget.clickOutput == null &&
      webPageIsolated();

  Timer? _engineAhead;

  Timer? _prepareAtLaunch;

  /// Long enough for the first frame's own work to be done.
  static const _engineAheadAfter = Duration(milliseconds: 300);

  /// Starts the engine once the sections stop sliding: starting it takes
  /// the page's thread a moment, which would show in the slide.
  void _startEngineWhenStill() {
    if (!mounted) return;
    if (_navigation.sliding.value) {
      void still() {
        if (_navigation.sliding.value) return;
        _navigation.sliding.removeListener(still);
        _startEngineWhenStill();
      }

      _navigation.sliding.addListener(still);
      return;
    }
    prepareSoLoud().catchError((Object error) {
      debugPrint('The audio engine could not start: $error');
    });
  }

  /// Coming to the harmony, the piano's notes are read before the touch;
  /// once the sections have stopped sliding, since in a browser reading
  /// them holds the screen up for a few seconds.
  void _preparePiano() {
    if (_navigation.section == AppSection.drone && !_navigation.sliding.value) {
      _drone.preparePiano();
    }
  }

  /// Whenever the tuner starts listening, whatever sounds is paused, or the
  /// microphone would hear it instead of the instrument; a notice says so,
  /// with a button to play it again.
  void _onTunerChanged() {
    _keepScreenOn();
    _showPaused(_pauses.tunerChanged(listening: _tuner.isListening));
  }

  void _pauseFor(PauseReason why) => _showPaused(_pauses.pauseFor(why));

  /// A notice that says why the sound paused, with a button to play it
  /// again (see [PauseRules]).
  void _showPaused(Paused? paused) {
    if (paused == null) return;
    final l10n = _notificationTexts();
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (paused.why) {
            PauseReason.tuner => l10n.pausedForTuner,
            PauseReason.unplugged => l10n.pausedUnplugged,
            PauseReason.interrupted => l10n.pausedInterrupted,
            PauseReason.player => l10n.pausedForPlayer,
          }),
          persist: false,
          action: SnackBarAction(
            label: l10n.resume,
            onPressed: () => _pauses.resume(paused),
          ),
        ),
      );
  }

  /// The screen stays on while anything plays or the tuner listens.
  void _keepScreenOn() => _screenAwake.keepOn(
    _settings.keepScreenOn &&
        (_drone.isPlaying ||
            _metronome.isPlaying ||
            _player.isPlaying ||
            _tuner.isListening),
  );

  StreamSubscription<MediaCommand>? _commands;

  /// The Player started: it plays alone, so the metronome and Harmony
  /// pause, with a notice and a button to play them again (RF-PLY-04).
  var _playerWasPlaying = false;

  void _onPlayerChanged() {
    final playing = _player.isPlaying;
    if (playing && !_playerWasPlaying) {
      _showPaused(_pauses.pauseFor(PauseReason.player));
    }
    _playerWasPlaying = playing;
    _onPlayingChanged();
  }

  var _soundWasPlaying = false;

  void _onPlayingChanged() {
    // The metronome or Harmony started: the Player gives way, with no
    // notice (they are what the person just asked for). Only when one of
    // them starts, not while the Player's own start is pausing them.
    final sound = _drone.isPlaying || _metronome.isPlaying;
    if (sound && !_soundWasPlaying && _player.isPlaying) _player.stop();
    _soundWasPlaying = sound;
    _keepScreenOn();
    // In a web page the engine sleeps a while after the last sound.
    setWebAudioIdle(!_drone.isPlaying && !_metronome.isPlaying);
    _notification.update();
  }

  /// "Metronome 120 BPM · 4/4" and "Harmony A major", one per line: what is
  /// playing, for the notification.
  String _describePlaying(AppLocalizations l10n) {
    // The Player plays alone: the track, and then who plays it.
    if (_player.isPlaying) {
      return '${_player.title ?? l10n.playerTab}\n'
          '${_player.artist ?? l10n.playerTab}';
    }
    final parts = <String>[];
    if (_metronome.isPlaying) {
      parts.add(
        '${l10n.metronomeTab} ${l10n.bpmValue('${_metronome.bpm}')} · '
        '${_metronome.signature.label}',
      );
    }
    if (_drone.isPlaying) {
      final names = _settings.noteNames(_locale());
      final root = spell(_drone.rootPitchClass, _drone.rootLetter, names);
      final chord = _drone.currentChord;
      // A progression is named by its key, not by the chord of the moment:
      // the notification would otherwise change at every bar.
      final what = _drone.voicing == DroneVoicing.progression
          ? l10n.progressionInKey(
              progressionName(l10n, _drone.progression),
              spell(_drone.note.pitchClass, _drone.keyLetter, names),
            )
          : chord == null
          ? root
          : chordSymbol(chord, root, names);
      parts.add('${l10n.harmonyTab} $what');
    }
    return parts.join('\n');
  }

  Locale _locale() =>
      _settings.locale ?? WidgetsBinding.instance.platformDispatcher.locale;

  AppLocalizations _notificationTexts() {
    final locale = _locale();
    return AppLocalizations.delegate.isSupported(locale)
        ? lookupAppLocalizations(locale)
        : lookupAppLocalizations(const Locale('en'));
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async =>
      _runLink(info.uri);

  /// Handles every link the app is opened with: runs an action link such as
  /// `lowend://action/drone_play?note=A`, sent by an assistant, a shortcut or
  /// an automation app. In the web app the link is the page's address, such
  /// as `…/low-end/#/action/drone_play?note=A`; it is then put back to the
  /// plain address, so that reloading the page does not run it again.
  bool _runLink(Uri uri) {
    if (kIsWeb && uri.path != '/') {
      SystemNavigator.routeInformationUpdated(
        uri: Uri(path: '/'),
        replace: true,
      );
    }
    final link = AppActions.parseLink(uri);
    if (link == null) {
      // The app has a single page, so there is nothing else to open.
      debugPrint('Ignored link: $uri');
      return true;
    }
    final (name, args) = link;
    _actions.call(name, args, true).then((result) {
      if (result['ok'] != true) debugPrint('Action link failed: $result');
    });
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The settings may come from main() and outlive this state.
    _settings.removeListener(_onSettingsChanged);
    _navigation.removeListener(_onNavigationChanged);
    _navigation.sliding.removeListener(_preparePiano);
    _engineAhead?.cancel();
    _prepareAtLaunch?.cancel();
    _drone.removeListener(_onPlayingChanged);
    _drone.removeListener(_rememberDrone);
    _metronome.removeListener(_onPlayingChanged);
    _metronome.removeListener(_rememberMetronome);
    _player.removeListener(_onPlayerChanged);
    _player.removeListener(_rememberPlayer);
    _tuner.removeListener(_onTunerChanged);
    _commands?.cancel();
    _unplugged?.cancel();
    _interrupted?.cancel();
    _playerInterrupted?.cancel();
    if (widget.audioRoute == null) _route.dispose();
    _background.show(MediaState.off, title: '');
    _screenAwake.keepOn(false);
    _drone.dispose();
    _metronome.dispose();
    _tuner.dispose();
    _recording.dispose();
    _player.dispose();
    _navigation.dispose();
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AudioScope(
      drone: _drone,
      metronome: _metronome,
      tuner: _tuner,
      player: _player,
      recording: _recording,
      navigation: _navigation,
      actions: _actions,
      settings: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => _app(),
      ),
    );
  }

  Widget _app() => MaterialApp(
    scaffoldMessengerKey: _messenger,
    // Null follows the phone's language.
    locale: _settings.locale,
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // Always dark, whatever the phone is set to (docs/tema-bronzo.md).
    theme: LowEndTheme.dark,
    // Always start on the main screen: a launch link is an action, not a
    // page (see _runLink).
    onGenerateRoute: (_) =>
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    onGenerateInitialRoutes: (_) => [
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    ],
  );
}
