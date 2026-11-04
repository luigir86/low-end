import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../features/metronome/time_signature.dart';
import 'bar_loop_player.dart';
import 'browser_flac.dart';
import 'click_sound.dart';
import 'in_steps.dart';
import 'loop_transport.dart';
import 'off_thread.dart';
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
  /// a [play] with [handOver] then starts there. Says how long until that
  /// bar line, or null when nothing plays.
  Duration? beginHandOver({required Duration lead});

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

/// A loop mixed by [SoLoudPianoOutput.prerender], for the settings in [key].
typedef _Ahead = ({
  String key,
  Future<({Uint8List wav, double scale})> loop,
  SlicedWork? work,
});

/// Decodes a mono FLAC file of [frames] samples to its samples, from -1
/// to 1.
typedef FlacDecoder = Future<Float32List> Function(Uint8List flac, int frames);

/// The piano recordings, read and decoded when a chord first needs them,
/// and kept while they may be needed again.
class PianoLibrary {
  PianoLibrary(this._decode, {AssetBundle? bundle, this.oneAtATime = kIsWeb})
    : _bundle = bundle ?? rootBundle;

  /// Whether the double bass is read ten files at a time, leaving the screen
  /// a frame between them: in a browser (see [_doubleBass]).
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
  /// In a browser ten at a time, with a frame between them, so that the
  /// screen keeps moving.
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
typedef _Playing = ({
  PianoSamples samples,
  List<PianoChord> chords,
  PianoStyle style,
  int bpm,
  TimeSignature signature,
  double a4,
  double scale,
});

/// [PianoOutput] backed by the SoLoud audio engine.
class SoLoudPianoOutput implements PianoOutput {
  // Follows the clicks: after a change of tempo it comes back in on their
  // beat, not on its own, the two loops crossing over so that the ringing
  // notes do not jump.
  final _player = BarLoopPlayer(
    'piano',
    follows: true,
    crossfade: const Duration(milliseconds: 40),
  );
  final _library = PianoLibrary(_decodeFlac);
  _Playing? _playing;

  /// The loop mixed ahead of the touch, if any (see [prerender]).
  _Ahead? _ahead;

  static String _keyOf(
    List<PianoChord> chords,
    PianoStyle style,
    int bpm,
    TimeSignature signature,
    double a4,
  ) =>
      '$chords ${style.name} $bpm ${signature.numerator}/'
      '${signature.denominator} ${signature.groups} $a4';

  /// Lets the recordings go a while after the piano stops: started again
  /// soon, it need not read them again.
  Timer? _forget;
  static const _keepFor = Duration(seconds: 30);

  /// In a browser the recordings stay while the page is open: reading them
  /// again holds the screen up for seconds (there is no isolate there), and
  /// did so at every return to the harmony after a pause.
  static const _keepWhilePageOpen = kIsWeb;

  /// How long recordings got ready by [prepare] wait for a touch.
  static const _keepPreparedFor = Duration(minutes: 2);

  /// How long the screen waits at most while a loop the player waits for is
  /// mixed, in a page (see [play]).
  static const _sliceWhileWaited = Duration(milliseconds: 50);

  static Future<Float32List> _decodeFlac(Uint8List flac, int frames) async {
    // The engine's code, not the engine itself: no sound starts.
    await webAudioEngineLoaded();
    return SoLoud.instance.readSamplesFromMem(flac, frames);
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
    // The engine starts and warms up while the notes are mixed, not before.
    final engine = ensureSoLoud()..ignore();
    final samples = await _library.forChords(
      chords,
      bass: style == PianoStyle.walking,
    );
    // Mixed ahead of the touch, or now (which takes a moment: away from
    // the screen's thread where there is one; in a page, for a new song, a
    // slice at a time, so that the screen and the wait it shows keep
    // moving).
    final key = _keyOf(chords, style, bpm, signature, a4);
    var rendered = await _mixedAhead(key);
    if (rendered == null && kIsWeb && patient) {
      await _mixAhead(
        chords: chords,
        style: style,
        bpm: bpm,
        signature: signature,
        a4: a4,
        // Longer slices than ahead of a touch: the sound is awaited, and
        // the screen still draws a few frames a second.
        slice: _sliceWhileWaited,
      );
      rendered = await _mixedAhead(key);
    }
    rendered ??= await _render(samples, chords, style, bpm, signature, a4);
    await engine;
    _player.setVolume(volume);
    final bar = Duration(
      microseconds:
          (ClickSound.sampleRate * 60 / bpm).round() *
          signature.beats *
          1000000 ~/
          ClickSound.sampleRate,
    );
    final was = _playing;
    _playing = (
      samples: samples,
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
      scale: rendered.scale,
    );
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

  /// [was] let go at [position] in its loop (see PianoSound.tailWav).
  static Uint8List _tail(_Playing was, Duration position) => PianoSound.tailWav(
    samples: was.samples,
    chords: was.chords,
    style: was.style,
    bpm: was.bpm,
    signature: was.signature,
    a4: was.a4,
    scale: was.scale,
    position: position.inMicroseconds * ClickSound.sampleRate ~/ 1000000,
  );

  /// Static, so that the closure sent to the isolate captures nothing but
  /// what it needs.
  static Future<({Uint8List wav, double scale})> _render(
    PianoSamples samples,
    List<PianoChord> chords,
    PianoStyle style,
    int bpm,
    TimeSignature signature,
    double a4,
  ) => offThread(
    () => PianoSound.loopWav(
      samples: samples,
      chords: chords,
      style: style,
      bpm: bpm,
      signature: signature,
      a4: a4,
    ),
  );

  /// The loop mixed ahead for [key], finished at full speed if still under
  /// way; null if there is none, or it failed.
  Future<({Uint8List wav, double scale})?> _mixedAhead(String key) async {
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
  }) => _mixAhead(
    chords: chords,
    style: style,
    bpm: bpm,
    signature: signature,
    a4: a4,
    slice: const Duration(milliseconds: 6),
  );

  /// Mixes the loop ahead (see [prerender]), in a page [slice] at a time
  /// with the screen in between.
  Future<void> _mixAhead({
    required List<PianoChord> chords,
    required PianoStyle style,
    required int bpm,
    required TimeSignature signature,
    required double a4,
    required Duration slice,
  }) async {
    final key = _keyOf(chords, style, bpm, signature, a4);
    if (_ahead?.key == key) {
      await _ahead!.loop;
      return;
    }
    // Other settings: the loop for the old ones is no longer wanted.
    _ahead?.work?.cancel();
    // In a page no isolate: a slice at a time, the screen in between.
    final work = kIsWeb ? SlicedWork() : null;
    // Known at once, so that a touch while the recordings are still read
    // waits for this loop instead of mixing a second one.
    final loop = () async {
      final samples = await _library.forChords(
        chords,
        bass: style == PianoStyle.walking,
      );
      if (work == null) {
        return _render(samples, chords, style, bpm, signature, a4);
      }
      if (work.cancelled) throw const StepsCancelled();
      final out = StepResult<({Uint8List wav, double scale})>();
      await runInSlices(
        PianoSound.loopWavSteps(
          samples: samples,
          chords: chords,
          style: style,
          bpm: bpm,
          signature: signature,
          a4: a4,
          out: out,
        ),
        work,
        slice: slice,
      );
      return out.value;
    }();
    _ahead = (key: key, loop: loop, work: work);
    try {
      await loop;
    } on StepsCancelled {
      // Replaced by another; nothing to do.
    } catch (_) {
      if (identical(_ahead?.loop, loop)) _ahead = null;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    final was = _playing;
    _playing = null;
    // The piano is let go as a pianist lifts the hands, not cut.
    await _player.stop(
      tailFor: was == null ? null : (position) => _tail(was, position),
    );
    _forget?.cancel();
    _forget = _keepWhilePageOpen ? null : Timer(_keepFor, _library.clear);
  }

  @override
  Future<void> prepare(List<PianoChord> chords, {bool bass = false}) async {
    // In a browser the engine is started by LowEndApp, held silent until a
    // touch; the recordings are read there without it (see
    // decodeFlacInBrowser).
    if (!kIsWeb) await ensureSoLoud();
    await _library.forChords(chords, bass: bass);
    // Not played after all: they go, as after a stop, a while later.
    if (_playing != null) return;
    _forget?.cancel();
    _forget = _keepWhilePageOpen
        ? null
        : Timer(_keepPreparedFor, _library.clear);
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
