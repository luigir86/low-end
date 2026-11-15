// A start, a stop or a start again while the first start is still under
// way: what the first one ends with (it fails, or it succeeds) belongs to
// it, never to the session the player opened since.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/metronome/time_signature.dart';

/// Holds the next play until [release], then lets it fail or go on.
class _Gate {
  Completer<void>? _armed;
  Completer<void>? _held;
  var entered = Completer<void>();
  var fail = false;

  void arm({required bool fail}) {
    _armed = Completer<void>();
    entered = Completer<void>();
    this.fail = fail;
  }

  void release() => _held?.complete();

  Future<void> pass() async {
    final g = _armed;
    if (g == null) return;
    _armed = null;
    _held = g;
    entered.complete();
    await g.future;
    _held = null;
    if (fail) {
      fail = false;
      throw StateError('the old preparation failed');
    }
  }
}

class _Piano extends SilentPianoOutput {
  final gate = _Gate();

  @override
  Future<LoopStart> play({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required double a4,
    required double volume,
    Duration? startAt,
    bool onTheBeat = false,
    bool patient = false,
    bool handOver = false,
  }) async {
    await gate.pass();
    return super.play(
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
      volume: volume,
      startAt: startAt,
      onTheBeat: onTheBeat,
      patient: patient,
      handOver: handOver,
    );
  }
}

class _Click implements ClickOutput {
  final gate = _Gate();
  var plays = 0;
  var stops = 0;

  @override
  Future<LoopStart> play(
    Uint8List barWav, {
    Duration? startAt,
    bool atMeeting = false,
  }) async {
    await gate.pass();
    plays++;
    return (position: startAt ?? Duration.zero, delay: Duration.zero);
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  group('Harmony', () {
    DroneController chord(_Piano piano) =>
        DroneController(SilentToneOutput(), piano: piano)
          ..setVoicing(DroneVoicing.chord);

    test('a failure of an older start does not stop a newer one', () async {
      final piano = _Piano()..gate.arm(fail: true);
      final drone = chord(piano);
      final first = drone.start();
      await piano.gate.entered.future;
      final stopped = drone.stop();
      final second = drone.start();
      piano.gate.release();
      await Future.wait([first, stopped, second]);
      expect(drone.isPlaying, isTrue);
      expect(drone.audioFailed, isFalse);
      expect(piano.plays, 1);
    });

    test('a failure of a start already stopped shows no error', () async {
      final piano = _Piano()..gate.arm(fail: true);
      final drone = chord(piano);
      final first = drone.start();
      await piano.gate.entered.future;
      final stopped = drone.stop();
      piano.gate.release();
      await Future.wait([first, stopped]);
      expect(drone.isPlaying, isFalse);
      expect(drone.audioFailed, isFalse);
    });

    test('a failure of the current start is still shown', () async {
      final piano = _Piano()..gate.arm(fail: true);
      final drone = chord(piano);
      final first = drone.start();
      await piano.gate.entered.future;
      piano.gate.release();
      await first;
      expect(drone.isPlaying, isFalse);
      expect(drone.audioFailed, isTrue);
    });
  });

  group('Metronome', () {
    test('a failure of an older start does not stop a newer one', () async {
      final click = _Click()..gate.arm(fail: true);
      final metronome = MetronomeController(click);
      final first = metronome.start();
      await click.gate.entered.future;
      final stopped = metronome.stop();
      final second = metronome.start();
      click.gate.release();
      await Future.wait([first, stopped, second]);
      expect(metronome.isPlaying, isTrue);
      expect(metronome.audioFailed, isFalse);
      expect(click.plays, 1);
    });

    test('a failure of a start already stopped shows no error', () async {
      final click = _Click()..gate.arm(fail: true);
      final metronome = MetronomeController(click);
      final first = metronome.start();
      await click.gate.entered.future;
      final stopped = metronome.stop();
      click.gate.release();
      await Future.wait([first, stopped]);
      expect(metronome.isPlaying, isFalse);
      expect(metronome.audioFailed, isFalse);
    });

    test('a failure of the current start is still shown', () async {
      final click = _Click()..gate.arm(fail: true);
      final metronome = MetronomeController(click);
      final first = metronome.start();
      await click.gate.entered.future;
      click.gate.release();
      await first;
      expect(metronome.isPlaying, isFalse);
      expect(metronome.audioFailed, isTrue);
    });
  });
}
