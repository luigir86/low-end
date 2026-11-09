import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audio/mic_input.dart';
import '../../audio/pitch_detector.dart';

enum TunerStatus { idle, starting, listening, permissionDenied, failed }

/// Listens to the microphone and keeps the latest detected frequency.
class TunerController extends ChangeNotifier {
  TunerController(this._mic, {this.sampleRate = 16000});

  final MicInput _mic;
  final int sampleRate;

  late final _detector = PitchDetector(sampleRate: sampleRate);

  /// The highest note listened for (see `TunerTuning.highestHz`).
  double get highestHz => _detector.maxFrequency;
  set highestHz(double hz) => _detector.maxFrequency = hz;

  /// One reading every 50 ms.
  late final _hop = sampleRate ~/ 20;

  /// Readings in a row without a note before the display clears (about two
  /// and a half seconds), so the note stays up while the string dies away.
  static const _holdReadings = 50;

  /// Readings without a note (a third of a second) before the note counts as
  /// held rather than heard, so a gap between two readings does not flicker.
  static const _heldAfter = 6;

  late final _window = Float64List(_detector.windowSize);
  var _filled = 0;
  var _sinceReading = 0;
  final _recent = <double>[];
  var _missed = 0;

  StreamSubscription<Float64List>? _subscription;
  Future<void>? _starting;
  // Counts starts and stops, so a start that finishes late can tell it is
  // out of date.
  var _generation = 0;
  // Whether the microphone may be capturing, so it is stopped exactly once.
  var _micOn = false;
  var _userPaused = false;
  var _disposed = false;
  var _status = TunerStatus.idle;
  double? _frequency;

  TunerStatus get status => _status;
  bool get isListening =>
      _status == TunerStatus.listening || _status == TunerStatus.starting;

  /// The detected frequency in Hz, smoothed, or null when no note is heard.
  double? get frequency => _frequency;

  /// True while the note on screen is only being held: nothing has been heard
  /// for a moment, and the display keeps the last note while the string dies
  /// away (see [_holdReadings]).
  bool get held => _frequency != null && _missed >= _heldAfter;

  /// Starts listening, also after a pause by the player. While a start is
  /// already under way, returns that one, so the caller can wait until the
  /// tuner is listening (or has failed).
  Future<void> start() {
    _userPaused = false;
    if (_disposed || _status == TunerStatus.listening) return Future.value();
    if (_status == TunerStatus.starting) return _starting ?? Future.value();
    return _starting = _start(++_generation);
  }

  /// Asked before the tuner starts by itself, when it comes back on screen:
  /// false keeps it still, for the player to start it (the app says no while
  /// the metronome or the drone plays, which listening would stop).
  bool Function()? autoStartAllowed;

  /// Starts listening unless the player paused the tuner or [autoStartAllowed]
  /// says no: used when the tuner comes back on screen by itself.
  Future<void> resume() => _userPaused || autoStartAllowed?.call() == false
      ? Future.value()
      : start();

  /// Stops listening at the player's request, and remembers it.
  Future<void> pause() {
    _userPaused = true;
    return stop();
  }

  Future<void> _start(int generation) async {
    // A stop, a newer start or dispose while this one waits makes it stale:
    // it must then leave the microphone and the status alone.
    bool stale() => _disposed || generation != _generation;
    _status = TunerStatus.starting;
    _notify();
    try {
      final allowed = await _mic.requestPermission();
      if (stale()) return;
      if (!allowed) {
        _status = TunerStatus.permissionDenied;
        _notify();
        return;
      }
      final samples = await _mic.start(sampleRate);
      _micOn = true;
      if (stale()) {
        // A newer start already waiting for the microphone takes it over;
        // otherwise nobody wants it any more.
        if (_disposed || _status != TunerStatus.starting) await _stopMic();
        return;
      }
      _subscription = samples.listen(_onSamples);
      _status = TunerStatus.listening;
    } catch (error) {
      if (stale()) return;
      debugPrint('Tuner could not start: $error');
      _status = TunerStatus.failed;
      await _stopMic();
    }
    _notify();
  }

  /// Stops listening, without counting as a pause by the player: used when
  /// the tuner leaves the screen.
  Future<void> stop() async {
    // Whatever start is still waiting is no longer wanted.
    _generation++;
    if (_status == TunerStatus.idle) return;
    final subscription = _subscription;
    _subscription = null;
    _status = TunerStatus.idle;
    _reset();
    _notify();
    await _stopMic();
    await subscription?.cancel();
  }

  Future<void> toggle() => isListening ? pause() : start();

  Future<void> _stopMic() async {
    if (!_micOn) return;
    _micOn = false;
    await _mic.stop();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _reset() {
    _filled = 0;
    _sinceReading = 0;
    _recent.clear();
    _missed = 0;
    _frequency = null;
  }

  void _onSamples(Float64List samples) {
    // Slide the window along, keeping the newest samples at its end.
    final size = _window.length;
    if (samples.length >= size) {
      _window.setRange(0, size, samples, samples.length - size);
      _filled = size;
    } else {
      final keep = size - samples.length;
      _window.setRange(0, keep, _window, samples.length);
      _window.setRange(keep, size, samples);
      _filled = (_filled + samples.length).clamp(0, size);
    }
    _sinceReading += samples.length;
    if (_filled < size || _sinceReading < _hop) return;
    _sinceReading = 0;
    _addReading(_detector.detect(_window, expected: _frequency));
  }

  void _addReading(double? hz) {
    final previous = _frequency;
    final wasHeld = held;
    if (hz == null) {
      if (++_missed >= _holdReadings) {
        _recent.clear();
        _frequency = null;
      }
    } else {
      _missed = 0;
      _recent.add(hz);
      if (_recent.length > 3) _recent.removeAt(0);
      // The median of the last readings drops one-off octave jumps.
      final sorted = List.of(_recent)..sort();
      _frequency = sorted[sorted.length ~/ 2];
    }
    if (_frequency != previous || held != wasHeld) _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription?.cancel();
    _subscription = null;
    _stopMic();
    super.dispose();
  }
}
