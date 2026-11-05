import 'dart:async';
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
  FallingBackMixer(
    this._first,
    this._makeLocal, {
    this.firstAnswerWithin = const Duration(seconds: 20),
  });

  final IsolatePianoMixer _first;

  /// How long the isolate's first answer may take: past it the isolate is
  /// taken for stuck (as when the phone never answered its request for a
  /// recording) and the screen's thread mixes instead, rather than leaving
  /// Harmony waiting for ever.
  final Duration firstAnswerWithin;
  final PianoMixer Function() _makeLocal;
  PianoMixer? _local;
  var _proven = false;

  Future<T> _try<T>(Future<T> Function(PianoMixer m) task) async {
    final local = _local;
    if (local != null) return task(local);
    try {
      final asked = task(_first);
      final value = _proven
          ? await asked
          : await asked.timeout(
              firstAnswerWithin,
              onTimeout: () => throw TimeoutException(
                'The piano isolate did not answer',
                firstAnswerWithin,
              ),
            );
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
  IsolatePianoMixer._(
    this._isolate,
    this._requests,
    this._replies,
    this._mainLoad,
  );

  final Isolate _isolate;
  final SendPort _requests;
  final ReceivePort _replies;
  final AssetLoader _mainLoad;
  final _waiting = <int, Completer<Object?>>{};
  var _next = 0;

  /// Starts the isolate. [decode], in it, decodes a FLAC file: by default
  /// with the audio engine's decoder. [load], in it, reads an asset; by
  /// default the isolate asks this isolate for it, which reads it with
  /// [mainLoad] (the app's assets). The isolate does not read the assets
  /// itself through [BackgroundIsolateBinaryMessenger]: on Android the
  /// answer never came, and Harmony waited for ever (1.4.0).
  static Future<IsolatePianoMixer> spawn({
    RootIsolateToken? token,
    FlacDecoder? decode,
    AssetLoader? load,
    AssetLoader? mainLoad,
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
    final mixer = IsolatePianoMixer._(
      isolate,
      first,
      replies,
      mainLoad ?? rootBundle.load,
    );
    replies.listen(mixer._onReply);
    return mixer;
  }

  void _onReply(Object? message) {
    if (message case ('asset', final int id, final String key)) {
      _sendAsset(id, key);
      return;
    }
    final (id, ok, value) = message! as (int, bool, Object?);
    final waiting = _waiting.remove(id);
    if (waiting == null) return;
    ok ? waiting.complete(value) : waiting.completeError(StateError('$value'));
  }

  /// Reads [key] here for the isolate and sends it over, moved, not copied.
  Future<void> _sendAsset(int id, String key) async {
    try {
      final data = await _mainLoad(key);
      _requests.send((
        -2,
        (
          'asset',
          id,
          true,
          TransferableTypedData.fromList([
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ]),
        ),
      ));
    } catch (error) {
      _requests.send((-2, ('asset', id, false, '$error')));
    }
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
    // The assets the isolate waits for from the main isolate.
    final assets = <int, Completer<ByteData>>{};
    var nextAsset = 0;
    Future<ByteData> askMain(String key) {
      final id = nextAsset++;
      final done = Completer<ByteData>();
      assets[id] = done;
      setup.replies.send(('asset', id, key));
      return done.future;
    }

    try {
      final token = setup.token;
      if (token != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      }
      library = PianoLibrary(
        setup.decode ?? decodeFlacWithEngine,
        bundle: _LoaderBundle(setup.load ?? askMain),
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
      if (request case ('asset', final int at, final bool ok, final value)) {
        final done = assets.remove(at);
        if (done == null) return;
        if (ok) {
          final bytes = (value! as TransferableTypedData).materialize();
          done.complete(ByteData.view(bytes));
        } else {
          done.completeError(StateError('$value'));
        }
        return;
      }
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
}

/// Assets read by an [AssetLoader].
class _LoaderBundle extends CachingAssetBundle {
  _LoaderBundle(this._load);

  final AssetLoader _load;

  @override
  Future<ByteData> load(String key) => _load(key);
}
