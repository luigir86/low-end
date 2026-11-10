import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'phone_mic.dart';
import 'web_audio_engine.dart';
import 'web_audio_session.dart';

/// Captures sound from the microphone as mono samples from -1 to 1.
///
/// Kept behind an interface so the rest of the app can be tested without a
/// real microphone.
abstract class MicInput {
  /// Asks for microphone access if needed; returns whether it was granted.
  Future<bool> requestPermission();

  /// Starts capturing at [sampleRate] samples per second.
  Future<Stream<Float64List>> start(int sampleRate);

  Future<void> stop();
}

/// [MicInput] backed by the record package.
class RecordMicInput implements MicInput {
  AudioRecorder? _recorder;

  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  /// The plain microphone first: the "unprocessed" source, though meant for
  /// music, is 10 to 20 times fainter on some phones (measured on a Galaxy
  /// S20 FE: room noise at 0.0001 against 0.001 to 0.003), and an acoustic
  /// bass played unamplified then drowns in the noise. Auto gain, echo
  /// cancelling and noise suppression stay off (see [_config]). The
  /// unprocessed source is the fallback.
  static const _sources = [
    AndroidAudioSource.mic,
    AndroidAudioSource.unprocessed,
  ];
  var _source = 0;

  @override
  Future<bool> requestPermission() => _rec.hasPermission();

  @override
  Future<Stream<Float64List>> start(int sampleRate) async {
    // On the iPhone the web app's sound keeps playing while it listens.
    setWebAudioSession(listening: true);
    markWebAudioInUse();
    // In the browser the phone's microphone is named (see phone_mic.dart).
    var phone = kIsWeb ? await phoneMic() : null;
    while (true) {
      try {
        var config = _config(sampleRate);
        if (phone != null) config = config.copyWith(device: (value: phone));
        final bytes = await _rec.startStream(config);
        return bytes.transform(const Pcm16Decoder());
      } catch (error) {
        if (phone != null) {
          // The phone microphone went away: the browser's choice.
          debugPrint('The phone microphone failed: $error');
          phone = null;
          try {
            await _rec.stop();
          } catch (_) {}
          continue;
        }
        if (_source + 1 >= _sources.length) rethrow;
        // Not on this phone: the next source, from now on.
        debugPrint('${_sources[_source].name} microphone failed: $error');
        _source++;
        try {
          await _rec.stop();
        } catch (_) {}
      }
    }
  }

  RecordConfig _config(int sampleRate) =>
      micConfig(sampleRate, _sources[_source]);

  /// How the tuner records. Shown to the tests.
  @visibleForTesting
  static RecordConfig micConfig(int sampleRate, AndroidAudioSource source) =>
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // Phone voice processing would flatten and filter the low notes.
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        // Listening takes no audio focus: with focus, Android stopped
        // Spotify or any other player for good the moment the tuner came on
        // screen, and nothing started it again when the tuner went away.
        // Another app's music keeps playing; our own sound pauses only when
        // the tuner's dial is touched.
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: AndroidRecordConfig(
          audioSource: source,
          manageBluetooth: false,
        ),
      );

  @override
  Future<void> stop() async {
    await _recorder?.stop();
    setWebAudioSession(listening: false);
  }
}

/// Opens the app's page in the phone settings, where the microphone can be
/// allowed after a no. Returns false when it could not, as in the web app:
/// a web page cannot open the phone settings.
Future<bool> openAppSettings() async {
  if (kIsWeb) return false;
  try {
    await const MethodChannel('low_end/app_settings')
        .invokeMethod<void>('open');
    return true;
  } catch (error) {
    debugPrint('App settings could not open: $error');
    return false;
  }
}

/// Turns little-endian 16-bit PCM bytes into samples from -1 to 1, carrying
/// over a byte when a chunk splits a sample in two.
class Pcm16Decoder extends StreamTransformerBase<Uint8List, Float64List> {
  const Pcm16Decoder();

  @override
  Stream<Float64List> bind(Stream<Uint8List> stream) async* {
    int? leftover;
    await for (final chunk in stream) {
      final bytes = leftover == null
          ? chunk
          : (Uint8List(chunk.length + 1)
              ..[0] = leftover
              ..setRange(1, chunk.length + 1, chunk));
      final count = bytes.length ~/ 2;
      leftover = bytes.length.isOdd ? bytes.last : null;
      final data = ByteData.sublistView(bytes);
      final samples = Float64List(count);
      for (var i = 0; i < count; i++) {
        samples[i] = data.getInt16(i * 2, Endian.little) / 32768;
      }
      yield samples;
    }
  }
}

/// [MicInput] fed by hand; used in tests.
@visibleForTesting
class FakeMicInput implements MicInput {
  FakeMicInput({this.allowed = true});

  bool allowed;
  StreamController<Float64List>? _controller;

  bool get isCapturing => _controller != null;

  /// Sends [samples] as if the microphone had captured them.
  void add(Float64List samples) => _controller?.add(samples);

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<Stream<Float64List>> start(int sampleRate) async {
    _controller = StreamController<Float64List>();
    return _controller!.stream;
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    // Not awaited: with the listener already gone, close never completes.
    controller?.close();
  }
}
