// The chord shown in a progression follows the piano as it is heard: after
// a change of tempo that carries the loop on just before a bar line it is
// not left a bar behind. On a controlled clock: no real-time waits.
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/loop_transport.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/harmony/drone_controller.dart';
import 'package:low_end/features/metronome/time_signature.dart';

class _Clock extends ChangeNotifier implements BarClock {
  @override
  Duration barLength = const Duration(milliseconds: 400);
  @override
  double? barPhase;
  int bpm = 120;
  @override
  int get soundingBpm => bpm;
  @override
  TimeSignature signature = TimeSignature.fourFour;
  void announce() => notifyListeners();
}

/// A piano whose loop, carrying on, picks up at [carryOnPosition].
class _Piano extends SilentPianoOutput {
  Duration? carryOnPosition;

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
    final started = await super.play(
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
    final at = carryOnPosition;
    if (startAt == null && at != null) {
      return (position: at, delay: Duration.zero);
    }
    return started;
  }
}

void main() {
  test('the chord shown keeps up after a tempo change that lands just '
      'before a bar line', () {
    fakeAsync((async) {
      final clock = _Clock();
      final piano = _Piano();
      final drone = DroneController(
        SilentToneOutput(),
        piano: piano,
        clock: clock,
      )..setVoicing(DroneVoicing.progression);
      final steps = drone.progression.steps.length;
      expect(steps, greaterThan(2));
      drone.start();
      async.flushMicrotasks();
      expect(drone.step, 0);
      // A tempo change: the loop carries on, 20 ms before its second bar.
      piano.carryOnPosition = const Duration(milliseconds: 380);
      clock
        ..bpm = 121
        ..announce();
      async.flushMicrotasks();
      expect(drone.step, 0);
      // 510 ms later the loop is at 380 + 510 = 890 ms: its third bar.
      async.elapse(const Duration(milliseconds: 510));
      expect(drone.step, 2);
      // And a bar later, the fourth.
      async.elapse(const Duration(milliseconds: 400));
      expect(drone.step, 3 % steps);
      drone.stop();
      async.flushMicrotasks();
      drone.dispose();
    });
  });
}
