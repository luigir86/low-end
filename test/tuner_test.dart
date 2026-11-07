import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/pitch.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/features/tuner/tuner_controller.dart';
import 'package:low_end/features/tuner/tuner_reading.dart';
import 'package:record/record.dart';

/// Chunk number [chunk] of a continuous sine, as the microphone would send it.
Float64List _sine(double hz, int length, {int chunk = 0, int rate = 16000}) =>
    Float64List.fromList([
      for (var i = chunk * length; i < (chunk + 1) * length; i++)
        0.3 * math.sin(2 * math.pi * hz * i / rate),
    ]);

void main() {
  group('Note.nearest and cents', () {
    test('finds the nearest note and how far off it is', () {
      expect(Note.nearest(41.2), const Note(4, 1));
      expect(Note.nearest(30.87), const Note(11, 0));
      expect(Note.nearest(442, a4: 442), const Note(9, 4));
      expect(const Note(9, 4).centsOf(440), closeTo(0, 1e-9));
      expect(const Note(9, 4).centsOf(442.55), closeTo(10, 0.1));
      expect(const Note(9, 4).centsOf(437.47), closeTo(-10, 0.1));
    });
  });

  group('TunerReading', () {
    test('names the nearest note, even when far off', () {
      final r = TunerReading.of(43.65);
      expect(r.target, const Note(5, 1));
      expect(r.played, const Note(5, 1));
      expect(r.inTune, isTrue);
    });

    test('measures the distance in cents', () {
      final r = TunerReading.of(44.5);
      expect(r.target, const Note(5, 1));
      expect(r.cents, closeTo(33, 2));
      expect(r.inTune, isFalse);
    });

    test('follows the reference pitch', () {
      final r = TunerReading.of(55.25, a4: 442);
      expect(r.target, const Note(9, 1));
      expect(r.inTune, isTrue);
    });
  });

  group('TunerController', () {
    test('reads a note from the microphone and stops cleanly', () async {
      final mic = FakeMicInput();
      final tuner = TunerController(mic);
      await tuner.start();
      expect(tuner.status, TunerStatus.listening);

      // Half a second of A1 in 100 ms chunks.
      for (var i = 0; i < 5; i++) {
        mic.add(_sine(55, 1600, chunk: i));
        await Future<void>.delayed(Duration.zero);
      }
      expect(tuner.frequency, closeTo(55, 0.2));

      await tuner.stop();
      expect(tuner.status, TunerStatus.idle);
      expect(tuner.frequency, isNull);
      expect(mic.isCapturing, isFalse);
    });

    test('reports a refused microphone', () async {
      final tuner = TunerController(FakeMicInput(allowed: false));
      await tuner.start();
      expect(tuner.status, TunerStatus.permissionDenied);
      expect(tuner.isListening, isFalse);
    });
  });

  test('PCM bytes split across chunks decode correctly', () async {
    final bytes = Uint8List(6)
      ..buffer.asByteData().setInt16(0, 16384, Endian.little)
      ..buffer.asByteData().setInt16(2, -32768, Endian.little)
      ..buffer.asByteData().setInt16(4, 0, Endian.little);
    final chunks = Stream.fromIterable([
      Uint8List.sublistView(bytes, 0, 3),
      Uint8List.sublistView(bytes, 3, 6),
    ]);
    final samples = await chunks
        .transform(const Pcm16Decoder())
        .expand((s) => s)
        .toList();
    expect(samples, [0.5, -1.0, 0.0]);
  });

  test('listening leaves the audio of other apps alone', () {
    // With audio focus, Android stopped Spotify for good whenever the tuner
    // came on screen.
    for (final source in AndroidAudioSource.values) {
      final config = RecordMicInput.micConfig(16000, source);
      expect(config.audioInterruption, AudioInterruptionMode.none);
      expect(config.androidConfig.manageBluetooth, isFalse);
    }
  });

  testWidgets('the tuner screen shows the string being played', (tester) async {
    // A phone-sized screen, so the whole tuner fits without scrolling.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final mic = FakeMicInput();
    await tester.pumpWidget(
      LowEndApp(toneOutput: SilentToneOutput(), micInput: mic),
    );
    await tester.pumpAndSettle();
    // The app opens on the metronome, with the microphone off.
    expect(mic.isCapturing, isFalse);
    await tester.tap(find.byTooltip('Tuner'));
    await tester.pumpAndSettle();
    // Opening the tuner starts listening right away.
    expect(mic.isCapturing, isTrue);
    expect(find.text('Play a note'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      mic.add(_sine(98, 1600, chunk: i)); // G2, the top string.
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('In tune'), findsOneWidget);
    expect(find.text('G2'), findsWidgets);

    // Leaving the tuner turns the microphone off.
    await tester.tap(find.byTooltip('Metronome'));
    await tester.pumpAndSettle();
    expect(mic.isCapturing, isFalse);
  });
}
