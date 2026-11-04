import 'package:flutter/widgets.dart' show Key;
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';

/// Records whether anything touched the sound output.
class _WatchedToneOutput extends SilentToneOutput {
  var used = false;

  @override
  Future<void> play(List<double> f, List<double> gains, double v) {
    used = true;
    return super.play(f, gains, v);
  }
}

/// Records when the microphone was first asked for.
class _WatchedMic extends FakeMicInput {
  SchedulerPhase? askedDuring;

  @override
  Future<bool> requestPermission() {
    askedDuring ??= SchedulerBinding.instance.schedulerPhase;
    return super.requestPermission();
  }
}

void main() {
  // Opening the app must stay instant: the first time it opens on Harmony,
  // with the microphone off, and nothing sounds until the first touch.
  testWidgets('opening the app starts neither the microphone nor the audio', (
    tester,
  ) async {
    final output = _WatchedToneOutput();
    final mic = _WatchedMic();
    await tester.pumpWidget(LowEndApp(toneOutput: output, micInput: mic));
    await tester.pumpAndSettle();

    expect(
      find.text('Touch a note to play it. Touch it again to stop.'),
      findsOneWidget,
    );
    expect(mic.askedDuring, isNull);
    expect(output.used, isFalse);

    // The tuner asks for the microphone only once it is opened.
    await tester.tap(find.text('Tuner'));
    await tester.pumpAndSettle();
    expect(mic.askedDuring, isNotNull);
    expect(find.byKey(const Key('tunerHub')), findsOneWidget);
    expect(output.used, isFalse);
  });
}
