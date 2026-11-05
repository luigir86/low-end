import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/audio/piano_mixer.dart';
import 'package:low_end/audio/piano_output.dart';
import 'package:low_end/audio/piano_sound.dart';
import 'package:low_end/features/metronome/time_signature.dart';

/// The app's own recordings, read from the disk as the isolate would read
/// them from the phone.
Future<ByteData> _fromDisk(String key) async =>
    ByteData.sublistView(await File(key).readAsBytes());

/// No audio engine in a test: every recording a quiet sine, as long as the
/// file says.
Future<Float32List> _fakeDecode(Uint8List flac, int frames) async {
  final hz = 110 + flac.length % 300;
  return Float32List.fromList([
    for (var i = 0; i < frames; i++)
      0.3 * math.sin(2 * math.pi * hz * i / 48000),
  ]);
}

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => _fromDisk(key);
}

void main() {
  const PianoLoop loop = (
    chords: [
      [45, 64, 69, 73],
      [42, 61, 66, 69],
    ],
    style: PianoStyle.beat,
    bpm: 120,
    signature: TimeSignature.fourFour,
    a4: 440,
  );

  test('the isolate mixes the loop and its tail as the screen would', () async {
    final isolate = await IsolatePianoMixer.spawn(
      decode: _fakeDecode,
      load: _fromDisk,
    );
    addTearDown(isolate.dispose);
    final local = LocalPianoMixer(
      PianoLibrary(_fakeDecode, bundle: _DiskBundle()),
    );

    await isolate.prepare(loop.chords);
    final there = await isolate.loop(loop);
    final here = await local.loop(loop);
    expect(there.wav.length, greaterThan(44));
    expect(there.scale, here.scale);
    expect(there.wav, here.wav);

    final tailThere = await isolate.tail(
      loop,
      scale: there.scale,
      position: 30000,
    );
    final tailHere = await local.tail(loop, scale: here.scale, position: 30000);
    expect(tailThere, tailHere);
  });

  test('by default the isolate asks this isolate for the recordings', () async {
    // As on the phone: the isolate does not read the assets itself (on
    // Android its request was never answered and Harmony waited for ever).
    final isolate = await IsolatePianoMixer.spawn(
      decode: _fakeDecode,
      mainLoad: _fromDisk,
    );
    addTearDown(isolate.dispose);
    final local = LocalPianoMixer(
      PianoLibrary(_fakeDecode, bundle: _DiskBundle()),
    );
    final there = await isolate.loop(loop);
    final here = await local.loop(loop);
    expect(there.wav, here.wav);
  });

  test('a recording this isolate cannot read is an error there', () async {
    final isolate = await IsolatePianoMixer.spawn(
      decode: _fakeDecode,
      mainLoad: _noAssets,
    );
    addTearDown(isolate.dispose);
    await expectLater(isolate.loop(loop), throwsA(isA<StateError>()));
  });

  test('an isolate that never answers is left for the screen', () async {
    final isolate = await IsolatePianoMixer.spawn(
      decode: _fakeDecode,
      mainLoad: _never,
    );
    final mixer = FallingBackMixer(
      isolate,
      () => LocalPianoMixer(PianoLibrary(_fakeDecode, bundle: _DiskBundle())),
      firstAnswerWithin: const Duration(milliseconds: 300),
    );
    final mixed = await mixer.loop(loop);
    expect(mixed.wav.length, greaterThan(44));
  });

  test('a failure comes back as an error, not a silence', () async {
    final isolate = await IsolatePianoMixer.spawn(
      decode: _fakeDecode,
      load: _noAssets,
    );
    addTearDown(isolate.dispose);
    await expectLater(isolate.loop(loop), throwsA(isA<StateError>()));
    // And the next request is answered too.
    await expectLater(isolate.prepare(loop.chords), throwsA(isA<StateError>()));
    isolate.clear();
  });

  test('if the isolate cannot read the recordings, the screen mixes', () async {
    final isolate = await IsolatePianoMixer.spawn(
      decode: _fakeDecode,
      load: _noAssets,
    );
    final mixer = FallingBackMixer(
      isolate,
      () => LocalPianoMixer(PianoLibrary(_fakeDecode, bundle: _DiskBundle())),
    );
    final mixed = await mixer.loop(loop);
    expect(mixed.wav.length, greaterThan(44));
    await mixer.prepare(loop.chords);
  });
}

/// A request for a recording that is never answered.
Future<ByteData> _never(String key) => Completer<ByteData>().future;

/// A phone that would not let the isolate read the assets.
Future<ByteData> _noAssets(String key) async =>
    throw StateError('Unable to load asset: "$key".');
