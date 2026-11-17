// Where the phone sends the sound, headphones pulled out and calls, as Dart
// hears them from AudioRoute.kt (its own tests: AudioRouteTest.kt). The
// Player pauses on "noisy", the metronome and Harmony on "call", and the
// beat on screen waits for the route's delay.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/audio_route.dart';
import 'package:low_end/audio/soloud_engine.dart';

const _channel = MethodChannel('low_end/audio_route');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Android calls [method] on Dart, as AudioRoute.kt does.
  Future<void> fromAndroid(String method, [Object? arguments]) async {
    await messenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }

  late List<MethodCall> asked;
  late String route;

  setUp(() {
    asked = [];
    route = 'speaker';
    messenger.setMockMethodCallHandler(_channel, (call) async {
      asked.add(call);
      return call.method == 'route' ? route : null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('asks the route at once and takes its delay', () async {
    route = 'bluetooth';
    final audio = AndroidAudioRoute();
    addTearDown(audio.dispose);
    await pumpEventQueue();
    expect(asked.map((c) => c.method), ['route']);
    expect(audio.outputLatency, outputLatencyFor(AudioOutputKind.bluetooth));
  });

  test('a new route from Android changes the delay', () async {
    final audio = AndroidAudioRoute();
    addTearDown(audio.dispose);
    await pumpEventQueue();
    expect(audio.outputLatency, outputLatencyFor(AudioOutputKind.speaker));

    for (final (name, kind) in [
      ('wired', AudioOutputKind.wired),
      ('ble', AudioOutputKind.bleAudio),
      ('bluetooth', AudioOutputKind.bluetooth),
      ('speaker', AudioOutputKind.speaker),
      ('something new', AudioOutputKind.speaker),
    ]) {
      await fromAndroid('route', name);
      expect(audio.outputLatency, outputLatencyFor(kind), reason: name);
    }
  });

  test('headphones pulled out and a call reach their streams', () async {
    final audio = AndroidAudioRoute();
    addTearDown(audio.dispose);
    var unplugged = 0;
    var interrupted = 0;
    audio.unplugged.listen((_) => unplugged++);
    audio.interrupted.listen((_) => interrupted++);

    await fromAndroid('noisy');
    await pumpEventQueue();
    expect((unplugged, interrupted), (1, 0));

    await fromAndroid('call');
    await pumpEventQueue();
    expect((unplugged, interrupted), (1, 1));
  });

  test('tells Android only when playing changes', () async {
    final audio = AndroidAudioRoute();
    addTearDown(audio.dispose);
    await pumpEventQueue();
    asked.clear();

    audio.playing = true;
    audio.playing = true;
    audio.playing = false;
    await pumpEventQueue();
    expect(asked.map((c) => (c.method, c.arguments)), [
      ('watch', true),
      ('watch', false),
    ]);
  });

  test('without the Android side it stays on the speaker', () async {
    messenger.setMockMethodCallHandler(_channel, null);
    final audio = AndroidAudioRoute();
    addTearDown(audio.dispose);
    audio.playing = true;
    await pumpEventQueue();
    expect(audio.outputLatency, outputLatencyFor(AudioOutputKind.speaker));
  });
}
