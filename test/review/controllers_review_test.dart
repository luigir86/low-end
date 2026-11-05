import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:low_end/features/tuner/tuner_controller.dart';

/// A microphone whose answers the test releases by hand.
class SlowMic implements MicInput {
  final permissions = <Completer<bool>>[];
  final starts = <Completer<void>>[];
  StreamController<Float64List>? controller;
  var startCalls = 0;
  var stopCalls = 0;
  Object? startError;
  Object? permissionError;

  bool get isCapturing => controller != null;

  @override
  Future<bool> requestPermission() {
    if (permissionError != null) return Future.error(permissionError!);
    final c = Completer<bool>();
    permissions.add(c);
    return c.future;
  }

  @override
  Future<Stream<Float64List>> start(int sampleRate) async {
    startCalls++;
    final c = Completer<void>();
    starts.add(c);
    await c.future;
    if (startError != null) throw startError!;
    // Like the record plugin: a new stream replaces the previous one.
    controller?.close();
    controller = StreamController<Float64List>();
    return controller!.stream;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    final c = controller;
    controller = null;
    c?.close();
  }

  void add(Float64List s) => controller?.add(s);
}

Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Float64List _sine(double hz, int length, {int chunk = 0, int rate = 16000}) =>
    Float64List.fromList([
      for (var i = chunk * length; i < (chunk + 1) * length; i++)
        0.3 * math.sin(2 * math.pi * hz * i / rate),
    ]);

/// Behaves like SoLoudToneOutput: play needs time the first time (engine
/// init), and only then do the voices start sounding.
class SlowToneOutput implements ToneOutput {
  final pending = <Completer<void>>[];
  List<double> sounding = const [];
  var playCalls = 0;
  bool failNextPlay = false;

  @override
  Future<void> prepare(List<(List<double>, List<double>)> sounds) async {}

  @override
  Future<void> play(List<double> f, List<double> gains, double v) async {
    playCalls++;
    if (failNextPlay) {
      failNextPlay = false;
      throw StateError('audio engine failed');
    }
    final c = Completer<void>();
    pending.add(c);
    await c.future;
    sounding = f;
  }

  @override
  Future<void> stop() async => sounding = const [];

  void releaseAll() {
    for (final c in pending) {
      if (!c.isCompleted) c.complete();
    }
  }
}

void main() {
  group('TunerController start/stop races', () {
    test('stop before the permission answer leaves the mic off', () async {
      final mic = SlowMic();
      final tuner = TunerController(mic);
      final starting = tuner.start();
      expect(tuner.status, TunerStatus.starting);
      await tuner.stop();
      expect(tuner.status, TunerStatus.idle);
      mic.permissions.single.complete(true);
      await _flush();
      // A start no longer wanted does not even open the microphone.
      for (final s in mic.starts) {
        s.complete();
      }
      expect(mic.startCalls, 0);
      await starting;
      expect(tuner.status, TunerStatus.idle);
      expect(mic.isCapturing, isFalse);
    });

    test('stop before a refusal does not show the refusal', () async {
      final mic = SlowMic();
      final tuner = TunerController(mic);
      final starting = tuner.start();
      await tuner.stop();
      mic.permissions.single.complete(false);
      await starting;
      // The player paused (or left the tab): the tuner should stay idle.
      expect(tuner.status, TunerStatus.idle);
    });

    test('start, stop, start again before the mic answers ends listening '
        'with a working microphone', () async {
      final mic = SlowMic();
      final tuner = TunerController(mic);
      final first = tuner.start();
      await tuner.stop();
      final second = tuner.start();
      for (final p in mic.permissions) {
        p.complete(true);
      }
      await _flush();
      for (final s in mic.starts) {
        s.complete();
      }
      await Future.wait([first, second]);
      await _flush();
      expect(tuner.status, TunerStatus.listening);
      expect(
        mic.isCapturing,
        isTrue,
        reason: 'tuner says listening, so the microphone must be on',
      );
      for (var i = 0; i < 5; i++) {
        mic.add(_sine(55, 1600, chunk: i));
        await _flush();
      }
      expect(tuner.frequency, isNotNull);
    });

    test('a permission request that throws reports failure', () async {
      final mic = SlowMic()..permissionError = Exception('no plugin');
      final tuner = TunerController(mic);
      await tuner.start();
      expect(tuner.status, TunerStatus.failed);
      expect(tuner.isListening, isFalse);
    });

    test('a mic that fails to start reports failure, and can retry', () async {
      final mic = SlowMic()..startError = Exception('busy');
      final tuner = TunerController(mic);
      final f = tuner.start();
      mic.permissions.single.complete(true);
      await _flush();
      mic.starts.single.complete();
      await f;
      expect(tuner.status, TunerStatus.failed);

      mic.startError = null;
      final g = tuner.start();
      mic.permissions.last.complete(true);
      await _flush();
      mic.starts.last.complete();
      await g;
      expect(tuner.status, TunerStatus.listening);
      expect(mic.isCapturing, isTrue);
      await tuner.stop();
      expect(mic.isCapturing, isFalse);
    });

    test('disposing while the mic is starting does not throw and leaves the '
        'mic off', () async {
      final mic = SlowMic();
      final tuner = TunerController(mic);
      final f = tuner.start();
      tuner.dispose();
      mic.permissions.single.complete(true);
      await _flush();
      // A start no longer wanted does not even open the microphone.
      for (final s in mic.starts) {
        s.complete();
      }
      expect(mic.startCalls, 0);
      Object? error;
      try {
        await f;
      } catch (e) {
        error = e;
      }
      expect(error, isNull, reason: 'notifyListeners after dispose');
      expect(mic.isCapturing, isFalse);
    });

    test('toggle twice quickly ends idle', () async {
      final mic = FakeMicInput();
      final tuner = TunerController(mic);
      final a = tuner.toggle();
      final b = tuner.toggle();
      await Future.wait([a, b]);
      await _flush();
      expect(tuner.status, TunerStatus.idle);
      expect(mic.isCapturing, isFalse);
    });

    test('note disappears about 2.5 s after silence and never jumps on '
        'a single octave glitch', () async {
      final mic = FakeMicInput();
      final tuner = TunerController(mic);
      await tuner.start();
      for (var i = 0; i < 10; i++) {
        mic.add(_sine(41.2, 800, chunk: i));
        await _flush();
      }
      expect(tuner.frequency, closeTo(41.2, 0.3));
      // One chunk an octave up, then back.
      mic.add(_sine(82.4, 800, chunk: 10));
      await _flush();
      for (var i = 11; i < 13; i++) {
        mic.add(_sine(41.2, 800, chunk: i));
        await _flush();
      }
      expect(tuner.frequency, closeTo(41.2, 0.3));
      // Silence: 50 ms per reading, about 50 readings to clear.
      for (var i = 0; i < 20; i++) {
        mic.add(Float64List(800));
        await _flush();
      }
      expect(tuner.frequency, isNotNull);
      for (var i = 0; i < 60; i++) {
        mic.add(Float64List(800));
        await _flush();
      }
      expect(tuner.frequency, isNull);
      await tuner.stop();
    });

    test(
      'a whistle after a note does not keep the old note on screen',
      () async {
        final mic = FakeMicInput();
        final tuner = TunerController(mic);
        await tuner.start();
        for (var i = 0; i < 10; i++) {
          mic.add(_sine(55, 800, chunk: i));
          await _flush();
        }
        expect(tuner.frequency, closeTo(55, 0.3));
        // Three seconds of an 880 Hz whistle (above the 700 Hz limit).
        for (var i = 10; i < 70; i++) {
          mic.add(_sine(880, 800, chunk: i));
          await _flush();
        }
        expect(
          tuner.frequency,
          isNull,
          reason: 'still shows ${tuner.frequency}',
        );
        await tuner.stop();
      },
    );

    test('one huge chunk and many tiny chunks both give a reading', () async {
      final mic = FakeMicInput();
      final tuner = TunerController(mic);
      await tuner.start();
      mic.add(_sine(98, 16000));
      await _flush();
      expect(tuner.frequency, closeTo(98, 0.3));
      await tuner.stop();

      await tuner.start();
      for (var i = 0; i < 400; i++) {
        mic.add(_sine(98, 7, chunk: i));
        await Future<void>.delayed(Duration.zero);
      }
      await _flush();
      expect(tuner.frequency, closeTo(98, 0.3));
      await tuner.stop();
    });
  });

  group('DroneController', () {
    test('changes while stopped make no sound', () async {
      final out = SilentToneOutput();
      final d = DroneController(out);
      d.setVoicing(DroneVoicing.chord);
      d.setChord(ChordQuality.dominant);
      d.setPitchClass(0);
      d.setReferencePitch(438);
      expect(out.frequencies, isEmpty);
      expect(d.frequencies, hasLength(4));
      expect(d.frequency, closeTo(438 / 2 * math.pow(2, -9 / 12), 1e-9));
    });

    test(
      'stop pressed while the engine is still starting leaves it silent',
      () async {
        final out = SlowToneOutput();
        final d = DroneController(out);
        final starting = d.tapNote(9);
        expect(d.isPlaying, isTrue);
        // Second tap on the same key, before the engine answered.
        await d.tapNote(9);
        expect(d.isPlaying, isFalse);
        out.releaseAll();
        await starting;
        await _flush();
        expect(
          out.sounding,
          isEmpty,
          reason: 'UI says stopped but the tone is sounding',
        );
      },
    );

    test('a failing retune while playing is reported, not thrown', () async {
      final out = SlowToneOutput();
      final d = DroneController(out);
      final f = d.tapNote(9);
      out.releaseAll();
      await f;
      out.failNextPlay = true;
      final errors = <Object>[];
      await runZonedGuarded(() async {
        d.setVoicing(DroneVoicing.chord);
        await _flush();
      }, (e, _) => errors.add(e));
      expect(errors, isEmpty, reason: 'unhandled async error from _update');
    });

    test('audio failure is reported and cleared on a later success', () async {
      final out = SlowToneOutput()..failNextPlay = true;
      final d = DroneController(out);
      await d.tapNote(9);
      expect(d.isPlaying, isFalse);
      expect(d.audioFailed, isTrue);
      final f = d.tapNote(9);
      expect(d.audioFailed, isFalse);
      out.releaseAll();
      await f;
      expect(d.isPlaying, isTrue);
    });
  });
}
