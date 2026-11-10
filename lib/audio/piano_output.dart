import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../features/metronome/time_signature.dart';
import 'audio_format.dart';
import 'bar_loop_player.dart';
import 'browser_flac.dart';
import 'click_sound.dart';
import 'in_steps.dart';
import 'loop_transport.dart';
import 'piano_mixer.dart';
import 'piano_sound.dart';
import 'soloud_engine.dart';
import 'walking_bass.dart';
import 'web_audio_engine.dart';

/// Plays the chords of the drone on the piano, one bar after another, in
/// time with the metronome.
///
/// Kept behind an interface so the rest of the app can be tested without a
/// real audio device.
abstract class PianoOutput {
  /// Starts looping [chords] (one per bar) in [style] at [bpm] pulses (the
  /// metronome's clicks) a minute in [signature], tuned to [a4], at
  /// [volume]; replaces what plays now.
  ///
  /// With no [startAt], a loop replacing another carries on from where the
  /// old one was, as a tempo change should; otherwise it starts that far in
  /// and, if the metronome is playing, waits for its next bar line. Says
  /// where and when it began.
  ///
  /// [onTheBeat], carrying on, keeps the old loop until its next beat and
  /// the new one comes in on it: a new chord, struck when the old one
  /// would have been struck again.
  ///
  /// [patient]: the player is told to wait for this loop (a new song), so
  /// in a page it is mixed a slice at a time, the screen and the wait it
  /// shows moving in between, rather than as fast as it can.
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
  });

  /// Starts letting the loop playing now down, for another to come in on
  /// the next bar line at least [lead] away (see BarLoopPlayer.beginHandOver):
  /// a [play] with `handOver` then starts there. Says how long until that
  /// bar line, or null when nothing plays.
  Duration? beginHandOver({required Duration lead});

  /// Calls off a hand-over under way: the loop playing goes on, back up to
  /// its level.
  void cancelHandOver();

  Future<void> stop();

  /// Gets the audio engine and the recordings [chords] need ready while
  /// nothing plays, so that playing them starts sooner; the double bass
  /// too if [bass] (the walking bass).
  Future<void> prepare(List<PianoChord> chords, {bool bass = false});

  /// Mixes ahead the loop that [play] with the same settings would start,
  /// while nothing plays: the touch then only has to start it. In a
  /// browser it is mixed a slice at a time, the screen drawn in between.
  /// A later call for other settings replaces it.
  Future<void> prerender({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required double a4,
  });
}

/// A loop mixed by [PianoOutput.prerender], for the settings in `key`.
typedef _Ahead = ({String key, Future<MixedLoop> loop, SlicedWork? work});

/// Decodes a mono FLAC file of [frames] samples to its samples, from -1
/// to 1.
typedef FlacDecoder = Future<Float32List> Function(Uint8List flac, int frames);

/// Decodes [flac] with the audio engine's own decoder (in an isolate of
/// its own on the phone; in a page, see decodeFlacInBrowser first). Only
/// the engine's code is needed, not the engine: no sound starts.
Future<Float32List> decodeFlacWithEngine(Uint8List flac, int frames) async {
  await webAudioEngineLoaded();
  return SoLoud.instance.readSamplesFromMem(flac, frames);
}

/// The piano recordings, read and decoded when a chord first needs them,
/// and kept while they may be needed again.
class PianoLibrary {
  PianoLibrary(this._decode, {AssetBundle? bundle, this.oneAtATime = true})
    : _bundle = bundle ?? rootBundle;

  /// Whether the double bass is read ten files at a time, leaving the screen
  /// a frame between them (see [_doubleBass]): on Android too, where the
  /// files are decoded on the screen's thread as well.
  final bool oneAtATime;

  final FlacDecoder _decode;
  final AssetBundle _bundle;
  final _notes = <int, Future<Map<int, PianoTake>>>{};
  final _releases = <int, Future<PianoTake>>{};
  Future<BassSamples>? _bass;

  /// Recorded notes kept beyond those the chords asked for need: about
  /// 3.5 MB each.
  static const _kept = 8;

  /// What [chords] need: the recordings of their notes in every touch, and
  /// the dampers of their keys; and the double bass, all of it, if [bass].
  Future<PianoSamples> forChords(
    List<PianoChord> chords, {
    bool bass = false,
  }) async {
    final walking = bass ? _doubleBass() : null;
    final roots = PianoSamples.rootsFor(chords);
    final keys = {
      for (final c in chords)
        for (final m in [...c, c.first - 12])
          if (m >= PianoSamples.releaseKeys.low &&
              m <= PianoSamples.releaseKeys.high)
            m,
    };
    // Forget the notes no longer needed, the oldest first, beyond a few.
    for (final k in _notes.keys.toList()) {
      if (_notes.length <= _kept) break;
      if (!roots.contains(k)) _notes.remove(k);
    }
    final notes = await Future.wait([
      for (final r in roots) _cached(_notes, r, () => _note(r)),
    ]);
    final releases = await Future.wait([
      for (final k in keys) _cached(_releases, k, () => _release(k)),
    ]);
    return PianoSamples(
      {for (final (i, r) in roots.indexed) r: notes[i]},
      releases: {for (final (i, k) in keys.indexed) k: releases[i]},
      cents: PianoSamples.tuning,
      gains: PianoSamples.levels,
      bass: await walking,
    );
  }

  /// Lets every recording go, to give the memory back.
  void clear() {
    _notes.clear();
    _releases.clear();
    _bass = null;
  }

  /// The double bass, every take: some 90 short files, read once.
  ///
  /// Ten at a time, with a frame between them, so that the screen keeps
  /// moving.
  Future<BassSamples> _doubleBass() => _bass ??=
      () async {
        final files = BassSamples.all.toList();
        final watch = Stopwatch()..start();
        final List<Int16List> takes;
        if (oneAtATime) {
          takes = [];
          const batch = 10;
          for (var i = 0; i < files.length; i += batch) {
            takes.addAll(
              await Future.wait([
                for (final (root, layer, take) in files.skip(i).take(batch))
                  _channel(BassSamples.assetOf(root, layer, take)),
              ]),
            );
            await Future<void>.delayed(Duration.zero);
          }
        } else {
          takes = await Future.wait([
            for (final (root, layer, take) in files)
              _channel(BassSamples.assetOf(root, layer, take)),
          ]);
        }
        // How long it takes on a real phone, to look at in the logs.
        if (kDebugMode) {
          debugPrint('Double bass read in ${watch.elapsedMilliseconds} ms');
        }
        final notes = <int, Map<int, List<Int16List>>>{};
        for (final (i, (root, layer, _)) in files.indexed) {
          (notes.putIfAbsent(root, () => {})[layer] ??= []).add(takes[i]);
        }
        return BassSamples(notes);
      }().catchError((Object error) {
        _bass = null;
        throw error;
      });

  /// The value of [key] in [cache], made by [make] the first time; tried
  /// again next time if it failed.
  static Future<T> _cached<T>(
    Map<int, Future<T>> cache,
    int key,
    Future<T> Function() make,
  ) => cache.putIfAbsent(
    key,
    () => make().catchError((Object error) {
      cache.remove(key);
      throw error;
    }),
  );

  Future<Map<int, PianoTake>> _note(int root) async {
    final takes = await Future.wait([
      for (final layer in PianoSamples.layers)
        _take(PianoSamples.assetsOf(root, layer)),
    ]);
    return {
      for (final (i, layer) in PianoSamples.layers.indexed) layer: takes[i],
    };
  }

  Future<PianoTake> _release(int midi) =>
      _take(PianoSamples.releaseAssetsOf(midi));

  Future<PianoTake> _take((String, String) files) async {
    final (left, right) = await (_channel(files.$1), _channel(files.$2)).wait;
    final n = math.min(left.length, right.length);
    return PianoTake(
      Int16List.sublistView(left, 0, n),
      Int16List.sublistView(right, 0, n),
    );
  }

  Future<Int16List> _channel(String asset) async {
    final data = await _bundle.load(asset);
    final flac = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    // In a browser, its own decoder: the engine's takes seconds there.
    if (await decodeFlacInBrowser(flac) case final samples?) return samples;
    final samples = await _decode(flac, flacFrames(flac));
    // Straight into the 16-bit list: a channel is up to half a million
    // samples, converted on the screen's thread.
    final out = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      out[i] = (samples[i] * 32768).round().clamp(-32768, 32767);
    }
    return out;
  }

  /// The number of samples in a FLAC file, from its header (the 36 bits
  /// that end its STREAMINFO block).
  @visibleForTesting
  static int flacFrames(Uint8List flac) {
    if (flac.length < 26 ||
        String.fromCharCodes(flac.sublist(0, 4)) != 'fLaC') {
      throw const FormatException('not a FLAC file');
    }
    // "fLaC", the block header (4 bytes), then 13 bytes of STREAMINFO
    // before the count.
    const at = 8 + 13;
    return (flac[at] & 0x0F) * 0x100000000 +
        (flac[at + 1] << 24 |
            flac[at + 2] << 16 |
            flac[at + 3] << 8 |
            flac[at + 4]);
  }
}

/// What the piano loop playing now was made of, to let it go.
/// What plays now: its settings, and the gain its loop was mixed at.
typedef _Playing = ({PianoLoop loop, double scale});

/// [PianoOutput] backed by the SoLoud audio engine.
class SoLoudPianoOutput implements PianoOutput {
  /// On the phone's engine. Tests give a transport on a fake engine, a
  /// mixer and an engine of their own.
  SoLoudPianoOutput({
    @visibleForTesting this._transport,
    @visibleForTesting PianoMixer? mixer,
    @visibleForTesting Future<void> Function()? engineReady,
  }) : _mixerGiven = mixer,
       _engineReady = engineReady ?? ensureSoLoud;

  final LoopTransport? _transport;
  final PianoMixer? _mixerGiven;
  final Future<void> Function() _engineReady;

  // Follows the clicks: after a change of tempo it comes back in on their
  // beat, not on its own, the two loops crossing over so that the ringing
  // notes do not jump.
  late final _player = BarLoopPlayer(
    'piano',
    follows: true,
    crossfade: const Duration(milliseconds: 40),
    transport: _transport,
  );
  _Playing? _playing;

  /// Where the recordings are kept and the loops mixed: on the phone an
  /// isolate of its own (see IsolatePianoMixer), started at the first need;
  /// in a page, or if that isolate cannot start, the screen's thread.
  Future<PianoMixer> get _mixer => _mixerReady ??= _mixerGiven != null
      ? Future.value(_mixerGiven)
      : _startMixer();
  Future<PianoMixer>? _mixerReady;

  static Future<PianoMixer> _startMixer() async {
    if (!kIsWeb) {
      try {
        return FallingBackMixer(
          await IsolatePianoMixer.spawn(token: RootIsolateToken.instance),
          () => LocalPianoMixer(PianoLibrary(decodeFlacWithEngine)),
        );
      } catch (error) {
        debugPrint('The piano isolate could not start: $error');
      }
    }
    return LocalPianoMixer(PianoLibrary(decodeFlacWithEngine));
  }

  /// The loop mixed ahead of the touch, if any (see [prerender]).
  _Ahead? _ahead;

  static String _keyOf(PianoLoop loop) =>
      '${loop.chords} ${loop.style.name} ${loop.bpm} '
      '${loop.signature.numerator}/${loop.signature.denominator} '
      '${loop.signature.groups} ${loop.a4}';

  /// Lets the recordings go a while after the piano stops: started again
  /// soon, it need not read them again.
  Timer? _forget;
  static const _keepFor = Duration(seconds: 30);

  /// How many times [play] was called: a [stop] knows whether the piano
  /// was started again while it let the loop go.
  var _plays = 0;

  /// In a browser the recordings stay while the page is open: reading them
  /// again holds the screen up for seconds (there is no isolate there), and
  /// did so at every return to the harmony after a pause.
  static const _keepWhilePageOpen = kIsWeb;

  /// How long recordings got ready by [prepare] wait for a touch.
  static const _keepPreparedFor = Duration(minutes: 2);

  /// How long the screen waits at most while a loop the player waits for is
  /// mixed, in a page (see [play]).
  static const _sliceWhileWaited = Duration(milliseconds: 50);

  /// The same for a touch while nothing was mixed ahead (a tempo, a chord):
  /// the screen still moves, at some 30 frames a second.
  static const _sliceWhileTouched = Duration(milliseconds: 25);

  void _forgetAfter(Duration wait) {
    _forget?.cancel();
    _forget = _keepWhilePageOpen
        ? null
        : Timer(wait, () => _mixer.then((m) => m.clear()));
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
    _forget?.cancel();
    _plays++;
    // The engine starts and warms up while the notes are mixed, not before.
    final engine = _engineReady()..ignore();
    final loop = (
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
    );
    // Mixed ahead of the touch, or now (which takes a moment: away from
    // the screen's thread where there is one; in a page a slice at a time,
    // so that the screen and the wait it shows keep moving (P1): longer
    // slices than ahead of a touch, since the sound is awaited, and longer
    // still for a change that waits for its bar line).
    final key = _keyOf(loop);
    var rendered = await _mixedAhead(key);
    if (rendered == null) {
      await _mixAhead(
        loop,
        slice: patient ? _sliceWhileWaited : _sliceWhileTouched,
      );
      rendered = await _mixedAhead(key);
    }
    rendered ??= await (await _mixer).loop(loop);
    await engine;
    _player.setVolume(volume);
    final bar = barDuration(bpm, signature.beats);
    final was = _playing;
    _playing = (loop: loop, scale: rendered.scale);
    return _player.play(
      rendered.wav,
      bar,
      startAt: startAt,
      onPulse: onTheBeat ? bar ~/ signature.beats : null,
      tailFor: was == null ? null : (position) => _tail(was, position),
      handOver: handOver,
    );
  }

  @override
  Duration? beginHandOver({required Duration lead}) =>
      _player.beginHandOver(lead: lead);

  @override
  void cancelHandOver() => _player.cancelHandOver();

  /// [was] let go at [position] in its loop (see PianoSound.tailWav): away
  /// from the screen's thread where there is one, in a page a slice at a
  /// time.
  Future<Uint8List> _tail(_Playing was, Duration position) async =>
      (await _mixer).tail(
        was.loop,
        scale: was.scale,
        position: position.inMicroseconds * ClickSound.sampleRate ~/ 1000000,
        slice: _sliceWhileWaited,
      );

  /// The loop mixed ahead for [key], finished at full speed if still under
  /// way; null if there is none, or it failed.
  Future<MixedLoop?> _mixedAhead(String key) async {
    final ahead = _ahead;
    if (ahead == null || ahead.key != key) return null;
    ahead.work?.hurry();
    try {
      return await ahead.loop;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> prerender({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required double a4,
  }) => _mixAhead((
    chords: chords,
    style: style,
    bpm: bpm,
    signature: signature,
    a4: a4,
  ), slice: const Duration(milliseconds: 6));

  /// Mixes [loop] ahead (see [prerender]), in a page [slice] at a time
  /// with the screen in between.
  Future<void> _mixAhead(PianoLoop loop, {required Duration slice}) async {
    final key = _keyOf(loop);
    if (_ahead?.key == key) {
      try {
        await _ahead!.loop;
      } catch (_) {}
      return;
    }
    // Other settings: the loop for the old ones is no longer wanted.
    _ahead?.work?.cancel();
    // In a page no isolate: a slice at a time, the screen in between.
    final work = kIsWeb ? SlicedWork() : null;
    // Known at once, so that a touch while the recordings are still read
    // waits for this loop instead of mixing a second one.
    final mixed = _mixer.then((m) => m.loop(loop, work: work, slice: slice));
    _ahead = (key: key, loop: mixed, work: work);
    try {
      await mixed;
    } on StepsCancelled {
      // Replaced by another; nothing to do.
    } catch (error) {
      if (identical(_ahead?.loop, mixed)) _ahead = null;
      debugPrint('The piano could not mix ahead: $error');
    }
  }

  @override
  Future<void> stop() async {
    final was = _playing;
    final plays = _plays;
    _playing = null;
    // The piano is let go as a pianist lifts the hands, not cut.
    await _player.stop(
      tailFor: was == null ? null : (position) => _tail(was, position),
    );
    // Started again while it was let go: the recordings are in use.
    if (_plays == plays) _forgetAfter(_keepFor);
  }

  @override
  Future<void> prepare(List<PianoChord> chords, {bool bass = false}) async {
    // In a browser the engine is started by LowEndApp, held silent until a
    // touch; the recordings are read there without it (see
    // decodeFlacInBrowser).
    if (!kIsWeb) await _engineReady();
    await (await _mixer).prepare(chords, bass: bass);
    // Not played after all: they go, as after a stop, a while later.
    if (_playing != null) return;
    _forgetAfter(_keepPreparedFor);
  }
}

/// [PianoOutput] that makes no sound; used where audio is unavailable.
@visibleForTesting
class SilentPianoOutput implements PianoOutput {
  /// What plays now, or null when stopped.
  List<PianoChord>? chords;
  PianoStyle? style;
  int? bpm;
  TimeSignature? signature;
  Duration? startAt;
  bool onTheBeat = false;
  double volume = 0;
  var plays = 0;

  /// How long the next start waits, as if the metronome were playing.
  Duration delay = Duration.zero;

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
    this.handOver = handOver;
    this.patient = patient;
    if (handOver && this.chords != null && handOverIn != null) {
      final wait = handOverIn!;
      handOverIn = null;
      this.chords = chords;
      this.style = style;
      this.bpm = bpm;
      this.signature = signature;
      this.startAt = startAt;
      this.onTheBeat = onTheBeat;
      this.volume = volume;
      plays++;
      return (position: Duration.zero, delay: wait);
    }
    this.chords = chords;
    this.style = style;
    this.bpm = bpm;
    this.signature = signature;
    this.startAt = startAt;
    this.onTheBeat = onTheBeat;
    this.volume = volume;
    plays++;
    return (position: startAt ?? Duration.zero, delay: delay);
  }

  @override
  Future<void> stop() async {
    chords = null;
    handOverIn = null;
  }

  /// How long a hand-over waits for its bar line, as a real loop would.
  Duration handOverWait = const Duration(seconds: 1);

  /// The wait of the hand-over under way, if any.
  Duration? handOverIn;

  /// How many times [beginHandOver] was asked for.
  var handOvers = 0;

  /// Whether the last [play] was a hand-over, and one the player waits for.
  bool handOver = false;
  bool patient = false;

  @override
  Duration? beginHandOver({required Duration lead}) {
    if (chords == null) return null;
    handOvers++;
    return handOverIn ??= handOverWait;
  }

  /// How many times [cancelHandOver] was asked for.
  var handOversCancelled = 0;

  @override
  void cancelHandOver() {
    if (handOverIn == null) return;
    handOverIn = null;
    handOversCancelled++;
  }

  /// What [prepare] was last asked for.
  List<PianoChord>? prepared;

  /// Whether it was asked to get the double bass ready too.
  bool preparedBass = false;

  @override
  Future<void> prepare(List<PianoChord> chords, {bool bass = false}) async {
    prepared = chords;
    preparedBass = bass;
  }

  /// The chords and style [prerender] was last asked for.
  List<PianoChord>? prerendered;
  PianoStyle? prerenderedStyle;

  @override
  Future<void> prerender({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required double a4,
  }) async {
    prerendered = chords;
    prerenderedStyle = style;
  }
}
