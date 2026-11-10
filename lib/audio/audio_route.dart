import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'soloud_engine.dart';
import 'web_audio_engine.dart';

/// Where the phone sends the sound, and the moment the headphones come out.
///
/// Kept behind an interface so the rest of the app can be tested without a
/// phone.
abstract class AudioRoute {
  /// About how long after it is mixed a sound is heard (see
  /// outputLatencyFor): the screen shows the beat that much later.
  Duration get outputLatency;

  /// Fires when the headphones are unplugged (or a Bluetooth headset goes
  /// away) and Android is about to send the sound to the speaker.
  Stream<void> get unplugged;

  /// Fires when a call comes: in the Android app as the phone rings (or a
  /// call app such as WhatsApp starts a call); in the web app when the
  /// browser stops the app's sound by itself, as Safari on the iPhone does
  /// for a call, Siri, an alarm or the locked screen.
  Stream<void> get interrupted;

  /// Whether the metronome, Harmony or the Player plays: older Android
  /// phones are asked about calls only meanwhile (see AudioRoute.kt).
  set playing(bool value);

  void dispose();
}

/// [AudioRoute] from Android's AudioManager, through AudioRoute.kt.
class AndroidAudioRoute implements AudioRoute {
  AndroidAudioRoute() {
    _channel.setMethodCallHandler(_onCall);
    // Where the sound goes now; then Android tells of every change.
    _channel
        .invokeMethod<String>('route')
        .then(_setKind)
        .catchError((Object _) {});
  }

  static const _channel = MethodChannel('low_end/audio_route');
  final _unplugged = StreamController<void>.broadcast();
  final _interrupted = StreamController<void>.broadcast();
  var _kind = AudioOutputKind.speaker;
  var _playing = false;

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'noisy':
        _unplugged.add(null);
      case 'call':
        _interrupted.add(null);
      case 'route':
        _setKind(call.arguments as String?);
    }
  }

  void _setKind(String? name) => _kind = switch (name) {
    'wired' => AudioOutputKind.wired,
    'bluetooth' => AudioOutputKind.bluetooth,
    'ble' => AudioOutputKind.bleAudio,
    _ => AudioOutputKind.speaker,
  };

  @override
  Duration get outputLatency => outputLatencyFor(_kind);

  @override
  Stream<void> get unplugged => _unplugged.stream;

  @override
  Stream<void> get interrupted => _interrupted.stream;

  @override
  set playing(bool value) {
    if (value == _playing) return;
    _playing = value;
    _channel.invokeMethod<void>('watch', value).catchError((Object _) {});
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _unplugged.close();
    _interrupted.close();
  }
}

/// [AudioRoute] where the route cannot be known, as in the web app: the
/// delay the browser gives (else the speaker's), and the headphones never
/// seen coming out.
class SpeakerAudioRoute implements AudioRoute {
  SpeakerAudioRoute() {
    onWebAudioCut(() => _interrupted.add(null));
  }

  final _interrupted = StreamController<void>.broadcast();

  /// The engine's buffer, then the browser's own delay, which on a phone
  /// can be several times the app's (and takes in Bluetooth too).
  @override
  Duration get outputLatency {
    final browser = webOutputLatency();
    if (browser == null) return outputLatencyFor(AudioOutputKind.speaker);
    return engineBufferLatency + browser;
  }

  @override
  Stream<void> get unplugged => const Stream.empty();

  @override
  Stream<void> get interrupted => _interrupted.stream;

  /// The browser says when it cuts the sound: nothing to watch.
  @override
  set playing(bool value) {}

  @override
  void dispose() => _interrupted.close();
}

/// [AudioRoute] for tests: no delay, and headphones unplugged or the sound
/// interrupted on demand.
@visibleForTesting
class FakeAudioRoute implements AudioRoute {
  final _unplugged = StreamController<void>.broadcast();
  final _interrupted = StreamController<void>.broadcast();

  @override
  Duration outputLatency = Duration.zero;

  /// Acts as if the headphones had just been pulled out.
  void unplug() => _unplugged.add(null);

  /// Acts as if a call had just come (or the browser had cut the sound).
  void interrupt() => _interrupted.add(null);

  /// What the app last said about its sound playing.
  @override
  bool playing = false;

  @override
  Stream<void> get unplugged => _unplugged.stream;

  @override
  Stream<void> get interrupted => _interrupted.stream;

  @override
  void dispose() {
    _unplugged.close();
    _interrupted.close();
  }
}
