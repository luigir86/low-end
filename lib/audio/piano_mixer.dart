import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/metronome/time_signature.dart';
import 'in_steps.dart';
import 'off_thread.dart';
import 'piano_output.dart';
import 'piano_sound.dart';

/// What a piano loop is mixed from: two loops with the same are the same
/// sound.
typedef PianoLoop = ({
  List<PianoChord> chords,
  PianoStyle style,
  int bpm,
  TimeSignature signature,
  double a4,
});

/// A loop mixed, as a WAV file, and the gain that kept it under the top
/// (see PianoSound.loopWav).
typedef MixedLoop = ({Uint8List wav, double scale});

/// Reads the piano's (and the double bass's) recordings and mixes loops
/// and tails from them, wherever they are kept.
abstract class PianoMixer {
  /// Reads what [chords] need, the double bass too if [bass].
  Future<void> prepare(List<PianoChord> chords, {bool bass = false});

  /// Mixes [loop]. With [work], in a page, [slice] at a time with the
  /// screen in between (see runInSlices).
  Future<MixedLoop> loop(
    PianoLoop loop, {
    SlicedWork? work,
    Duration slice = const Duration(milliseconds: 6),
  });

  /// [loop], mixed at [scale], let go [position] samples into it (see
  /// PianoSound.tailWav).
  Future<Uint8List> tail(
    PianoLoop loop, {
    required double scale,
    required int position,
    Duration slice = const Duration(milliseconds: 50),
  });

  /// Lets every recording go.
  void clear();
}

/// [PianoMixer] whose recordings are kept on the screen's thread: in a page
/// (no isolates there, the mixes cut in slices), and on the phone if the
/// isolate of [IsolatePianoMixer] could not start, each mix then made in
/// an isolate of its own.
class LocalPianoMixer implements PianoMixer {
  LocalPianoMixer(this._library);

  final PianoLibrary _library;

  Future<PianoSamples> _samplesFor(PianoLoop loop) =>
      _library.forChords(loop.chords, bass: loop.style == PianoStyle.walking);

  @override
  Future<void> prepare(List<PianoChord> chords, {bool bass = false}) =>
      _library.forChords(chords, bass: bass);

  @override
  Future<MixedLoop> loop(
    PianoLoop loop, {
    SlicedWork? work,
    Duration slice = const Duration(milliseconds: 6),
  }) async {
    final samples = await _samplesFor(loop);
    if (work == null) return offThread(() => mixLoop(samples, loop));
    if (work.cancelled) throw const StepsCancelled();
    final out = StepResult<MixedLoop>();
    await runInSlices(
      PianoSound.loopWavSteps(
        samples: samples,
        chords: loop.chords,
        style: loop.style,
        bpm: loop.bpm,
        signature: loop.signature,
        a4: loop.a4,
        out: out,
      ),
      work,
      slice: slice,
    );
    return out.value;
  }

  @override
  Future<Uint8List> tail(
    PianoLoop loop, {
    required double scale,
    required int position,
    Duration slice = const Duration(milliseconds: 50),
  }) async {
    final samples = await _samplesFor(loop);
    if (!kIsWeb) {
      return offThread(() => mixTail(samples, loop, scale, position));
    }
    final out = StepResult<Uint8List>();
    await runInSlices(
      PianoSound.tailWavSteps(
        samples: samples,
        chords: loop.chords,
        style: loop.style,
        bpm: loop.bpm,
        signature: loop.signature,
        a4: loop.a4,
        scale: scale,
        position: position,
        out: out,
      ),
      SlicedWork(),
      slice: slice,
    );
    return out.value;
  }

  @override
  void clear() => _library.clear();
}

/// [loop] mixed from [samples] at once.
MixedLoop mixLoop(PianoSamples samples, PianoLoop loop) => PianoSound.loopWav(
  samples: samples,
  chords: loop.chords,
  style: loop.style,
  bpm: loop.bpm,
  signature: loop.signature,
  a4: loop.a4,
);

/// The tail of [loop] from [samples] at once (see PianoSound.tailWav).
Uint8List mixTail(
  PianoSamples samples,
  PianoLoop loop,
  double scale,
  int position,
) => PianoSound.tailWav(
  samples: samples,
  chords: loop.chords,
  style: loop.style,
  bpm: loop.bpm,
  signature: loop.signature,
  a4: loop.a4,
  scale: scale,
  position: position,
);

/// The isolate's mixer, or, if it fails at its first task (the phone
/// would not let it read the assets, say), the screen's thread's from then
/// on: the sound must never be lost to it.
class FallingBackMixer implements PianoMixer {
  FallingBackMixer(this._first, this._makeLocal);

  final IsolatePianoMixer _first;
  final PianoMixer Function() _makeLocal;
  PianoMixer? _local;
  var _proven = false;

  Future<T> _try<T>(Future<T> Function(PianoMixer m) task) async {
    final local = _local;
    if (local != null) return task(local);
    try {
      final value = await task(_first);
      _proven = true;
      return value;
    } catch (error) {
      if (_proven || error is StepsCancelled) rethrow;
      debugPrint('The piano isolate failed, mixing here instead: $error');
      _first.dispose();
      final fallback = _local ??= _makeLocal();
      return task(fallback);
    }
  }

  @override
  Future<void> prepare(List<PianoChord> chords, {bool bass = false}) =>
      _try((m) => m.prepare(chords, bass: bass));

  @override
  Future<MixedLoop> loop(
    PianoLoop loop, {
    SlicedWork? work,
    Duration slice = const Duration(milliseconds: 6),
  }) => _try((m) => m.loop(loop, work: work, slice: slice));

  @override
  Future<Uint8List> tail(
    PianoLoop loop, {
    required double scale,
    required int position,
    Duration slice = const Duration(milliseconds: 50),
  }) =>
      _try((m) => m.tail(loop, scale: scale, position: position, slice: slice));

  @override
  void clear() => (_local ?? _first).clear();
}

/// Reads an asset by its name.
typedef AssetLoader = Future<ByteData> Function(String key);

/// [PianoMixer] on the phone: one isolate, alive while the app is, holds
/// the recordings, read and decoded there, and mixes every loop and tail
/// there. Nothing of them is copied at each mix, as an isolate of its own
/// for each mix had to (P3), and the screen's thread never decodes,
/// converts or mixes (P4, P7). The loops come back without a copy.
class IsolatePianoMixer implements PianoMixer {
  IsolatePianoMixer._(this._isolate, this._requests, this._replies);

  final Isolate _isolate;
  final SendPort _requests;
  final ReceivePort _replies;
  final _waiting = <int, Completer<Object?>>{};
  var _next = 0;

  /// Starts the isolate. [decode] and [load], in it, decode a FLAC file
  /// and read an asset: by default with the audio engine's decoder and the
  /// app's assets, reached from the isolate through [token].
  static Future<IsolatePianoMixer> spawn({
    RootIsolateToken? token,
    FlacDecoder? decode,
    AssetLoader? load,
  }) async {
    final ready = ReceivePort();
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(_main, (
      ready: ready.sendPort,
      replies: replies.sendPort,
      token: token,
      decode: decode,
      load: load,
    ), debugName: 'piano');
    final first = await ready.first;
    ready.close();
    if (first is! SendPort) {
      isolate.kill();
      replies.close();
      throw StateError('The piano isolate did not start: $first');
    }
    final mixer = IsolatePianoMixer._(isolate, first, replies);
    replies.listen(mixer._onReply);
    return mixer;
  }

  void _onReply(Object? message) {
    final (id, ok, value) = message! as (int, bool, Object?);
    final waiting = _waiting.remove(id);
    if (waiting == null) return;
    ok ? waiting.complete(value) : waiting.completeError(StateError('$value'));
  }

  Future<Object?> _ask(Object request) {
    final id = _next++;
    final done = Completer<Object?>();
    _waiting[id] = done;
    _requests.send((id, request));
    return done.future;
  }

  @override
  Future<void> prepare(List<PianoChord> chords, {bool bass = false}) =>
      _ask(('prepare', chords, bass));

  @override
  Future<MixedLoop> loop(
    PianoLoop loop, {
    SlicedWork? work,
    Duration slice = const Duration(milliseconds: 6),
  }) async {
    final (wav, scale) =
        await _ask(('loop', loop)) as (TransferableTypedData, double);
    return (wav: wav.materialize().asUint8List(), scale: scale);
  }

  @override
  Future<Uint8List> tail(
    PianoLoop loop, {
    required double scale,
    required int position,
    Duration slice = const Duration(milliseconds: 50),
  }) async {
    final wav =
        await _ask(('tail', loop, scale, position)) as TransferableTypedData;
    return wav.materialize().asUint8List();
  }

  @override
  void clear() => _requests.send((-1, ('clear',)));

  /// Stops the isolate, and with it lets the recordings go.
  void dispose() {
    _isolate.kill();
    _replies.close();
    for (final w in _waiting.values) {
      w.completeError(StateError('The piano isolate was stopped.'));
    }
    _waiting.clear();
  }

  static Future<void> _main(
    ({
      SendPort ready,
      SendPort replies,
      RootIsolateToken? token,
      FlacDecoder? decode,
      AssetLoader? load,
    })
    setup,
  ) async {
    final PianoLibrary library;
    try {
      final token = setup.token;
      if (token != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      }
      library = PianoLibrary(
        setup.decode ?? decodeFlacWithEngine,
        bundle: _LoaderBundle(setup.load ?? _loadAppAsset),
      );
    } catch (error) {
      setup.ready.send('$error');
      return;
    }
    final requests = ReceivePort();
    setup.ready.send(requests.sendPort);
    Future<PianoSamples> samplesFor(PianoLoop loop) =>
        library.forChords(loop.chords, bass: loop.style == PianoStyle.walking);
    requests.listen((message) async {
      final (id, request) = message! as (int, Record);
      try {
        final Object? value = switch (request) {
          ('prepare', final List<PianoChord> chords, final bool bass) =>
            await library.forChords(chords, bass: bass).then((_) => null),
          ('loop', final PianoLoop loop) => _transferable(
            mixLoop(await samplesFor(loop), loop),
          ),
          ('tail', final PianoLoop loop, final double scale, final int at) =>
            TransferableTypedData.fromList([
              mixTail(await samplesFor(loop), loop, scale, at),
            ]),
          ('clear',) => _cleared(library),
          _ => throw ArgumentError('Unknown request: $request'),
        };
        if (id >= 0) setup.replies.send((id, true, value));
      } catch (error) {
        if (id >= 0) setup.replies.send((id, false, '$error'));
      }
    });
  }

  /// [mixed] as it goes back, its WAV file moved rather than copied.
  static (TransferableTypedData, double) _transferable(MixedLoop mixed) =>
      (TransferableTypedData.fromList([mixed.wav]), mixed.scale);

  static Object? _cleared(PianoLibrary library) {
    library.clear();
    return null;
  }

  /// An asset of the app, read from the isolate (as PlatformAssetBundle
  /// does on the screen's thread).
  static Future<ByteData> _loadAppAsset(String key) async {
    final encoded = utf8.encode(Uri(path: Uri.encodeFull(key)).path);
    final data = await BackgroundIsolateBinaryMessenger.instance.send(
      'flutter/assets',
      ByteData.sublistView(encoded),
    );
    if (data == null) throw StateError('Unable to load asset: "$key".');
    return data;
  }
}

/// Assets read by an [AssetLoader].
class _LoaderBundle extends CachingAssetBundle {
  _LoaderBundle(this._load);

  final AssetLoader _load;

  @override
  Future<ByteData> load(String key) => _load(key);
}
