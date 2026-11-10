import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/harmony/harmony.dart';
import 'package:low_end/features/metronome/metronome_controller.dart';
import 'package:low_end/features/metronome/time_signature.dart';

/// RF-ARM-15 (a change of what the piano plays fades the old loop to its
/// bar line, where the new one comes in) and RF-MET-08 (the sound takes a
/// new tempo once the finger rests).
void main() {
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  group('Harmony hands over at the bar line', () {
    late SilentPianoOutput piano;
    late MetronomeController metronome;
    late DroneController drone;

    setUp(() async {
      piano = SilentPianoOutput();
      metronome = MetronomeController(SilentClickOutput());
      drone = DroneController(
        SilentToneOutput(),
        piano: piano,
        clock: metronome,
      );
      drone
        ..setVoicing(DroneVoicing.progression)
        ..setProgression(Progression.oneSixFourFive);
      await drone.start();
      await settle();
      expect(drone.isStarting, isFalse);
    });

    tearDown(() async {
      await drone.stop();
      drone.dispose();
      metronome.dispose();
    });

    test('a new progression waits for the bar line, beats counted', () async {
      final plays = piano.plays;
      drone.setProgression(Progression.blues);
      expect(drone.progression, Progression.blues);
      await settle();
      expect(piano.handOvers, 1);
      expect(piano.handOver, isTrue);
      expect(piano.plays, plays + 1);
      // The old loop goes on meanwhile: nothing stopped, nothing to wait for.
      expect(drone.isPlaying, isTrue);
      expect(drone.isStarting, isFalse);
      // One second at 80 in 4/4: two beats of 0.75 s to go.
      expect(drone.beatsLeft, 2);
    });

    test('several changes at once are one hand-over', () async {
      final plays = piano.plays;
      drone.applyAll(() {
        drone
          ..setPitchClass(2)
          ..setProgression(Progression.blues)
          ..setStyle(DroneStyle.walking);
      });
      await settle();
      expect(piano.handOvers, 1);
      expect(piano.plays, plays + 1);
    });

    test('changes one after the other share the bar line', () async {
      drone.setProgression(Progression.blues);
      drone.setStyle(DroneStyle.arpeggio);
      await settle();
      expect(piano.handOvers, 1);
    });

    test('changed and changed back, the loop goes on as it was', () async {
      final plays = piano.plays;
      drone
        ..setProgression(Progression.blues)
        ..setProgression(Progression.oneSixFourFive);
      await settle();
      // Compared with what plays (step 3): nothing to mix, the fade undone.
      expect(piano.handOvers, 1);
      expect(piano.handOversCancelled, 1);
      expect(piano.plays, plays);
      expect(drone.beatsLeft, isNull);
      expect(drone.isPlaying, isTrue);
    });

    test('a chord in Chord mode still changes on the beat', () async {
      drone.setVoicing(DroneVoicing.chord);
      await settle();
      final handOvers = piano.handOvers;
      drone.setChord(ChordQuality.minor);
      await settle();
      expect(piano.handOvers, handOvers);
      expect(piano.handOver, isFalse);
    });
  });

  group('Harmony when requests overlap', () {
    late _GatedPiano piano;
    late MetronomeController metronome;
    late DroneController drone;

    setUp(() async {
      piano = _GatedPiano();
      metronome = MetronomeController(SilentClickOutput());
      drone = DroneController(
        SilentToneOutput(),
        piano: piano,
        clock: metronome,
      );
      drone
        ..setVoicing(DroneVoicing.progression)
        ..setProgression(Progression.oneSixFourFive);
      await drone.start();
      await settle();
    });

    tearDown(() async {
      piano.open();
      await drone.stop();
      drone.dispose();
      metronome.dispose();
    });

    test('a failure during a hand-over leaves no wait behind', () async {
      piano.failNext = true;
      drone.setProgression(Progression.blues);
      await settle();
      expect(drone.audioFailed, isTrue);
      expect(drone.isPlaying, isFalse);
      expect(drone.showsWait, isFalse);
      await drone.start();
      await settle();
      expect(drone.isPlaying, isTrue);
      expect(drone.showsWait, isFalse);
      expect(drone.beatsLeft, isNull);
    });

    test('the continuous tone during a hand-over shows no wait', () async {
      piano.close();
      metronome.setBpm(100);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      drone.setStyle(DroneStyle.arpeggio);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      drone.setContinuous(true);
      piano.open();
      await settle();
      expect(drone.continuous, isTrue);
      expect(drone.isPlaying, isTrue);
      expect(drone.showsWait, isFalse);
      expect(drone.beatsLeft, isNull);
    });

    test('stopped while the first chord is mixed, no loop starts', () async {
      await drone.stop();
      await settle();
      final plays = piano.plays;
      piano.close();
      final started = drone.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final stopped = drone.stop();
      piano.open();
      await Future.wait([started, stopped]);
      await settle();
      expect(piano.plays, plays);
      expect(piano.chords, isNull);
      expect(drone.isPlaying, isFalse);
      expect(drone.audioFailed, isFalse);
    });

    test('start, stop and start while the first chord is mixed: one '
        'start heard', () async {
      await drone.stop();
      await settle();
      final plays = piano.plays;
      piano.close();
      final first = drone.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final stopped = drone.stop();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final again = drone.start();
      piano.open();
      await Future.wait([first, stopped, again]);
      await settle();
      expect(piano.plays, plays + 1);
      expect(piano.startAt, Duration.zero);
      expect(drone.isPlaying, isTrue);
      expect(drone.isStarting, isFalse);
      expect(drone.audioFailed, isFalse);
    });
  });

  group('the tempo follows the finger, the sound its rest', () {
    late SilentClickOutput click;
    late MetronomeController metronome;

    setUp(() async {
      click = SilentClickOutput();
      metronome = MetronomeController(click);
      metronome.setBpm(100);
      await metronome.start();
      await settle();
    });

    tearDown(() async {
      await metronome.stop();
      metronome.dispose();
    });

    test('+ changes the number now and the sound after a rest', () async {
      final plays = click.plays;
      metronome.step(1);
      metronome.step(1);
      expect(metronome.bpm, 102);
      expect(metronome.soundingBpm, 100);
      await settle();
      expect(click.plays, plays);
      await Future<void>.delayed(MetronomeController.adjustRest);
      expect(metronome.soundingBpm, 102);
      await settle();
      expect(click.plays, plays + 1);
    });

    test('TAP is heard once the taps stop', () async {
      const beat = Duration(milliseconds: 500);
      for (var i = 0; i < 4; i++) {
        metronome.tap(beat * i);
      }
      expect(metronome.bpm, 120);
      expect(metronome.soundingBpm, 100);
      // A beat and a half with no tap: 0.75 s.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(metronome.soundingBpm, 100);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(metronome.soundingBpm, 120);
    });

    test('a typed tempo is heard at once', () {
      metronome.setBpm(90);
      expect(metronome.soundingBpm, 90);
    });

    test('stopped, the tempo applies at once', () async {
      await metronome.stop();
      metronome.step(5);
      expect(metronome.soundingBpm, 105);
    });
  });
}

/// A piano whose loops can be held back while they "mix" ([close], then
/// [open]), or fail.
class _GatedPiano extends SilentPianoOutput {
  Completer<void>? _gate;
  bool failNext = false;

  void close() => _gate ??= Completer<void>();

  void open() {
    _gate?.complete();
    _gate = null;
  }

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
    if (_gate case final gate?) await gate.future;
    if (failNext) {
      failNext = false;
      throw StateError('the piano failed');
    }
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
