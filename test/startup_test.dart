import 'package:flutter/widgets.dart' show Key;
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/audio/track_files.dart';
import 'package:low_end/audio/track_output.dart';

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
    final track = SilentTrackOutput();
    final files = FakeTrackFiles();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: output,
        micInput: mic,
        trackOutput: track,
        trackFiles: files,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Touch a note to play it. Touch it again to stop.'),
      findsOneWidget,
    );
    expect(mic.askedDuring, isNull);
    expect(output.used, isFalse);
    // The Player opens no file and makes no system player (RNF-AVV-01).
    expect(track.openCount, 0);
    expect(files.picks, 0);

    // The tuner asks for the microphone only once it is opened.
    await tester.tap(find.text('Tuner'));
    await tester.pumpAndSettle();
    expect(mic.askedDuring, isNotNull);
    expect(find.byKey(const Key('tunerHub')), findsOneWidget);
    expect(output.used, isFalse);

    // Not even on the Player's tab: only a touch asks for a file.
    await tester.tap(find.text('Player'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('playerHub')), findsOneWidget);
    expect(track.openCount, 0);
    expect(files.picks, 0);
  });
}
