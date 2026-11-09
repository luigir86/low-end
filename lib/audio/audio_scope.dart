import 'package:flutter/widgets.dart';

import '../actions/app_actions.dart';
import '../app/app_navigation.dart';
import '../app/settings.dart';
import '../features/harmony/drone_controller.dart';
import '../features/metronome/metronome_controller.dart';
import '../features/player/player_controller.dart';
import '../features/player/recording_controller.dart';
import '../features/tuner/tuner_controller.dart';

/// Makes the app's sound sources, the tuner listening to the microphone,
/// the Player and its recording, the navigation, the action layer and the settings available to every
/// screen.
class AudioScope extends InheritedWidget {
  const AudioScope({
    super.key,
    required this.drone,
    required this.metronome,
    required this.tuner,
    required this.player,
    required this.recording,
    required this.navigation,
    required this.actions,
    required this.settings,
    required super.child,
  });

  final DroneController drone;
  final MetronomeController metronome;
  final TunerController tuner;
  final PlayerController player;

  /// The Player's recording (REC).
  final RecordingController recording;
  final AppNavigation navigation;
  final AppActions actions;
  final AppSettings settings;

  static AudioScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AudioScope>();
    assert(scope != null, 'No AudioScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AudioScope oldWidget) =>
      drone != oldWidget.drone ||
      metronome != oldWidget.metronome ||
      tuner != oldWidget.tuner ||
      player != oldWidget.player ||
      recording != oldWidget.recording ||
      navigation != oldWidget.navigation ||
      actions != oldWidget.actions ||
      settings != oldWidget.settings;
}
