import 'package:flutter/foundation.dart';

/// The sections of the app, one per tab, in tab order.
enum AppSection { metronome, drone, tuner }

/// Which section is on screen. Kept outside the widgets so that taps and
/// actions from an assistant (see `lib/actions/`) move the app the same way.
class AppNavigation extends ChangeNotifier {
  /// Opens on [section]: the one the app was left on (see
  /// AppSettings.section), Harmony the first time.
  AppNavigation({this._section = AppSection.drone});

  AppSection _section;
  bool _covered = false;

  AppSection get section => _section;

  /// True while another page (the settings, a dialog) is on top of the
  /// sections, hiding them.
  bool get covered => _covered;

  /// The microphone may only listen while the tuner itself is on screen.
  bool get tunerVisible => _section == AppSection.tuner && !_covered;

  void open(AppSection section) {
    if (section == _section) return;
    _section = section;
    notifyListeners();
  }

  /// True while the sections slide under the finger or to a tab. Work that
  /// would hold the screen up (getting the piano ready) waits for the end.
  final sliding = ValueNotifier<bool>(false);

  @override
  void dispose() {
    sliding.dispose();
    super.dispose();
  }

  void setCovered(bool covered) {
    if (covered == _covered) return;
    _covered = covered;
    notifyListeners();
  }
}
