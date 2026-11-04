import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../actions/app_actions.dart';
import '../audio/audio_route.dart';
import '../audio/audio_scope.dart';
import '../audio/click_output.dart';
import '../audio/mic_input.dart';
import '../audio/piano_output.dart';
import '../audio/pitch.dart';
import '../audio/soloud_engine.dart';
import '../audio/tone_output.dart';
import '../audio/web_audio_engine.dart';
import '../features/metronome/metronome_controller.dart';
import '../features/tuner/drone/drone_controller.dart';
import '../features/tuner/drone/drone_panel.dart'
    show chordSymbol, progressionName;
import '../features/tuner/tuner_controller.dart';
import '../l10n/app_localizations.dart';
import 'app_navigation.dart';
import 'background_audio.dart';
import 'settings.dart';
import 'home_shell.dart';
import 'screen_awake.dart';
import 'theme.dart';

class LowEndApp extends StatefulWidget {
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
    // The double bass is got ready right after the piano, for a walking
    // bass chosen later: reading it takes seconds on a phone's browser.
    prefetchBass: true,
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
  late final _tuner = TunerController(widget.micInput ?? RecordMicInput());
  late final BackgroundAudio _background =
      widget.backgroundAudio ?? MediaNotificationAudio();
  late final ScreenAwake _screenAwake =
      widget.screenAwake ?? WakelockScreenAwake();
  // The app opens on the section it was left on.
  late final _navigation = AppNavigation(section: _settings.section);

  /// Shows the notice that the sound paused for the tuner.
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final _settings = widget.settings ?? AppSettings();
  late final _actions = AppActions(
    drone: _drone,
    metronome: _metronome,
    tuner: _tuner,
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
    _tuner.highestHz = _settings.tuning.highestHz;
    _settings.addListener(_onSettingsChanged);
    _navigation.addListener(_onNavigationChanged);
    _navigation.sliding.addListener(_preparePiano);
    _drone.addListener(_onPlayingChanged);
    _metronome.addListener(_onPlayingChanged);
    // Coming to the tuner starts it only when nothing plays.
    _tuner.autoStartAllowed = () => !_drone.isPlaying && !_metronome.isPlaying;
    _tuner.addListener(_onTunerChanged);
    _commands = _background.commands.listen(_onMediaCommand);
    // Headphones pulled out: the sound stops before it reaches the speaker.
    _unplugged = _route.unplugged.listen((_) => _pauseFor(_Pause.unplugged));
    // The iPhone's browser cut the sound (a call, the locked screen): the
    // app must not look as if it played on, unheard.
    _interrupted = _route.interrupted.listen(
      (_) => _pauseFor(_Pause.interrupted),
    );
    // If the app opens on the tuner (where it was left, or a link), start
    // listening once the first frame is up, so the microphone never delays
    // it; opening on the harmony, its piano is got ready then too (in a
    // browser only its recordings are read: the sound engine waits for a
    // touch, see SoLoudPianoOutput.prepare).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_navigation.tunerVisible) _tuner.resume();
      _preparePiano();
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

  void _onSettingsChanged() {
    _keepScreenOn();
    // The notification names the notes in the player's way.
    if (_shown == MediaState.playing) _onPlayingChanged();
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
    if (_tuner.isListening && (_drone.isPlaying || _metronome.isPlaying)) {
      _pauseFor(_Pause.tuner);
    }
  }

  /// Stops whatever sounds, with a notice that says why and a button to play
  /// it again. Headphones pulled out pause it as a music player does: the
  /// notification stays, paused, with its play button.
  void _pauseFor(_Pause why) {
    final drone = _drone.isPlaying, metronome = _metronome.isPlaying;
    if (!drone && !metronome) return;
    if (why == _Pause.unplugged) {
      _pauseInNotification();
    } else {
      if (drone) _drone.stop();
      if (metronome) _metronome.stop();
    }
    final l10n = _notificationTexts();
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (why) {
            _Pause.tuner => l10n.pausedForTuner,
            _Pause.unplugged => l10n.pausedUnplugged,
            _Pause.interrupted => l10n.pausedInterrupted,
          }),
          persist: false,
          action: SnackBarAction(
            label: l10n.resume,
            onPressed: () {
              if (drone && !_drone.isPlaying) _drone.start();
              if (metronome && !_metronome.isPlaying) _metronome.start();
            },
          ),
        ),
      );
  }

  /// The screen stays on while anything plays or the tuner listens.
  void _keepScreenOn() => _screenAwake.keepOn(
    _settings.keepScreenOn &&
        (_drone.isPlaying || _metronome.isPlaying || _tuner.isListening),
  );

  /// With the screen off or the app in the background, the drone and the
  /// metronome carry on, kept alive by a media notification (see
  /// [BackgroundAudio]) that is there while one of them plays, and after a
  /// pause from the notification, to resume from.
  var _shown = MediaState.off;
  var _pausedFromNotification = false;
  var _stoppingFromNotification = false;
  var _heldDrone = false;
  var _heldMetronome = false;
  StreamSubscription<MediaCommand>? _commands;

  /// What the notification says is playing, kept while it is paused.
  var _nowPlaying = '';
  var _shownText = '';

  void _onPlayingChanged() {
    _keepScreenOn();
    final playing = _drone.isPlaying || _metronome.isPlaying;
    // In a web page the engine sleeps a while after the last sound.
    setWebAudioIdle(!playing);
    final l10n = _notificationTexts();
    // Not while the notification's own pause is stopping things: stopping
    // the drone first, with the metronome still sounding, would otherwise
    // look like a restart and forget the pause (and play would do nothing).
    if (playing && !_stoppingFromNotification) {
      _pausedFromNotification = false;
      _nowPlaying = _describePlaying(l10n);
    }
    final state = playing
        ? MediaState.playing
        : _pausedFromNotification
        ? MediaState.paused
        : MediaState.off;
    // A new tempo, note or chord changes the text, not the state.
    if (state == _shown && _nowPlaying == _shownText) return;
    _shown = state;
    _shownText = _nowPlaying;
    // What plays, and at what tempo, on the first line: that is what the
    // small notification shows beside the play button. The app's name and
    // icon sit in its header, as on a music player.
    final lines = _nowPlaying.split('\n').where((s) => s.isNotEmpty).toList();
    _background.show(
      state,
      title: lines.isEmpty ? l10n.backgroundPlaying : lines.first,
      text: lines.length > 1 ? lines[1] : l10n.appTitle,
    );
  }

  /// "Metronome 120 BPM · 4/4" and "Harmony A major", one per line: what is
  /// playing, for the notification.
  String _describePlaying(AppLocalizations l10n) {
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
          : chordSymbol(l10n, chord, root);
      parts.add('${l10n.harmonyTab} $what');
    }
    return parts.join('\n');
  }

  void _onMediaCommand(MediaCommand command) {
    switch (command) {
      case MediaCommand.pause:
        if (!_drone.isPlaying && !_metronome.isPlaying) return;
        _pauseInNotification();
      case MediaCommand.play:
        if (!_pausedFromNotification) return;
        if (_heldDrone) _drone.start();
        if (_heldMetronome) _metronome.start();
      case MediaCommand.stop:
        _pausedFromNotification = false;
        _drone.stop();
        _metronome.stop();
        // Nothing was playing when paused: the notification must go anyway.
        _onPlayingChanged();
    }
  }

  /// Stops what plays and keeps the notification, paused, to play it again
  /// from there: its pause button, or the headphones pulled out.
  void _pauseInNotification() {
    _heldDrone = _drone.isPlaying;
    _heldMetronome = _metronome.isPlaying;
    _pausedFromNotification = true;
    _stoppingFromNotification = true;
    _drone.stop();
    _metronome.stop();
    _stoppingFromNotification = false;
    // Shows the paused notification, whatever the stops showed.
    _onPlayingChanged();
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
    _drone.removeListener(_onPlayingChanged);
    _drone.removeListener(_rememberDrone);
    _metronome.removeListener(_onPlayingChanged);
    _metronome.removeListener(_rememberMetronome);
    _tuner.removeListener(_onTunerChanged);
    _commands?.cancel();
    _unplugged?.cancel();
    _interrupted?.cancel();
    if (widget.audioRoute == null) _route.dispose();
    _background.show(MediaState.off, title: '');
    _screenAwake.keepOn(false);
    _drone.dispose();
    _metronome.dispose();
    _tuner.dispose();
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

/// Why the sound was stopped by the app rather than by the player.
enum _Pause { tuner, unplugged, interrupted }
