import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/latest_request.dart';
import 'package:low_end/audio/sound_clock.dart';

void main() {
  group('the latest request', () {
    test('runs at once, then once for everything asked meanwhile', () async {
      var runs = 0;
      var gate = Completer<void>();
      final requests = LatestRequest(() async {
        runs++;
        await gate.future;
      });
      final first = requests.run();
      expect(runs, 1);
      final second = requests.run();
      final third = requests.run();
      expect(requests.busy, isTrue);
      final done = gate;
      gate = Completer<void>()..complete();
      done.complete();
      await first;
      await second;
      await third;
      expect(runs, 2);
      expect(requests.busy, isFalse);
    });
  });

  group('the sound clock', () {
    test('a fresh start lights up once it is heard', () {
      final clock = SoundClock()
        ..heard(
          (position: Duration.zero, delay: const Duration(seconds: 1)),
          latency: const Duration(milliseconds: 100),
          fresh: true,
        );
      expect(clock.position, isNull);
      expect(clock.waitLeft, greaterThan(const Duration(milliseconds: 1000)));
    });

    test('a loop carrying on shows its place as it was heard', () {
      final clock = SoundClock()
        ..heard(
          (position: const Duration(milliseconds: 500), delay: Duration.zero),
          latency: const Duration(milliseconds: 100),
          fresh: false,
        );
      expect(clock.waitLeft, isNull);
      expect(clock.position, lessThan(const Duration(milliseconds: 450)));
      expect(
        clock.position,
        greaterThanOrEqualTo(const Duration(milliseconds: 400)),
      );
    });

    test('stopped, nothing waits', () {
      final clock = SoundClock()
        ..restartAt(Duration.zero)
        ..stop();
      expect(clock.waitLeft, isNull);
    });
  });
}
