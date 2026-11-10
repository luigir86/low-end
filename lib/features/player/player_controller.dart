import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../audio/recorded_track.dart';
import '../../audio/sound_section.dart';
import '../../audio/track_files.dart';
import '../../audio/track_output.dart';
import 'player_setup.dart';
import 'track_peaks.dart';

/// Where the Player stands with its track.
enum PlayerStatus {
  /// No track is open.
  empty,

  /// A track was chosen and the system is getting it ready.
  opening,

  /// The track is open and can play.
  ready,
}

/// An end of the loop: the point A where it starts, or the point B where it
/// ends and begins again.
enum LoopEdge { start, end }

/// The Player: plays one track of the person's own, chosen with the system's
/// file chooser. The sound and the files are outside, behind
/// [TrackOutput] and [TrackFiles], so that it is tested without a phone.
///
/// It plays alone: the app pauses the metronome and Harmony when it starts,
/// and stops it when either of them starts (see low_end_app.dart).
class PlayerController extends ChangeNotifier implements SoundSection {
  PlayerController(this._output, this._files) {
    _events = _output.events.listen(_onEvent);
  }

  final TrackOutput _output;
  final TrackFiles _files;
  late final StreamSubscription<TrackEvent> _events;
  final _interruptions = StreamController<void>.broadcast();

  TrackRef? _track;
  Duration _duration = Duration.zero;
  var _status = PlayerStatus.empty;
  var _playing = false;
  TrackProblem? _problem;
  var _disposed = false;

  /// The speed in percent, and the stretch A to B that may repeat.
  var _speed = 100;
  Duration? _loopStart;
  Duration? _loopEnd;
  var _looping = false;
  Timer? _settle;
  var _active = LoopEdge.start;

  /// The slowest and the fastest the track plays, in percent.
  static const minSpeed = 50;
  static const maxSpeed = 125;

  /// What the person's reaction takes off the point where an end is marked
  /// ("Mark the start here" of a screen reader, the assistants' `player_mark`),
  /// in real time (at half speed the track has gone half as far).
  static const reaction = Duration(milliseconds: 150);

  /// The shortest loop.
  static const minLoop = Duration(seconds: 1);

  /// The step of the − and + under the dial: a touch and a hold (RF-PLY-10).
  static const fineStep = Duration(milliseconds: 10);
  static const coarseStep = Duration(milliseconds: 100);

  /// How long the ends must be left alone before the sound follows.
  static const settleAfter = Duration(milliseconds: 300);

  /// When B is moved before where the track is, it restarts this long
  /// before B, to hear how the loop closes.
  static const preroll = Duration(seconds: 2);

  /// Chains what is asked of the output's loop, so that it is told in order.
  Future<void>? _loopWork;

  /// The loudness of the open track, filling up as the file is read; null
  /// without a track. Not reported to the listeners as it fills: the dial
  /// listens to it.
  TrackPeaks? _peaks;
  StreamSubscription<Uint16List>? _peaksReading;

  /// Counts the tracks opened: what an earlier one answers late is ignored.
  var _generation = 0;

  /// False for a track remembered from the last launch, until it is first
  /// played (or moved): nothing is asked of the system's player before then
  /// (RF-PLY-13, RNF-AVV-01).
  var _loaded = false;
  Future<bool>? _loading;

  /// True once the file of a remembered track has been looked at.
  var _activated = true;

  /// The track being studied when a take was opened over it, with its speed
  /// and passage: kept (and remembered for the next launch) while the take
  /// is open, and back when the take is removed (RF-PLY-20).
  PlayerSetup? _beforeTake;

  /// A take not saved, just discarded with the X: for [undoTime] it can be
  /// opened again with [undoDiscard]; then its file is let go.
  RecordedTrack? _discarded;
  Timer? _undoTimer;

  /// How long a discarded take can be brought back.
  static const undoTime = Duration(seconds: 5);

  /// The title and the artist in the tags of the file (RF-PLY-14).
  String? _title;
  String? _artist;

  /// The take just discarded, while it can still be brought back.
  RecordedTrack? get discarded => _discarded;

  /// The track chosen, until it is replaced or fails.
  TrackRef? get track => _track;

  PlayerStatus get status => _status;

  /// How long the track is; zero until it is [PlayerStatus.ready].
  Duration get duration => _duration;

  /// True as soon as a start is asked, also while the track is still being
  /// got ready.
  @override
  bool get isPlaying => _playing;

  /// Why the last track could not be opened; null once another is chosen.
  TrackProblem? get problem => _problem;

  /// What stands for the track on screen and in the notification: the title
  /// in its tags, else the name of the file without its extension.
  String? get title => _track == null ? null : (_title ?? _track!.baseName);

  /// The artist in the tags of the file, if it has one.
  String? get artist => _track == null ? null : _artist;

  /// True if the file gave a title or an artist: the middle of the dial then
  /// shows them, going by once if they are long (RF-PLY-19).
  bool get hasTags => _track != null && (_title != null || _artist != null);

  /// What is kept for the next launch; null with no track.
  PlayerSetup? get setup {
    final track = _track;
    // A take lasts only for this session: the track under it is kept.
    if (track is RecordedTrack) return _beforeTake;
    if (track == null || _status != PlayerStatus.ready) return null;
    return PlayerSetup(
      track: track,
      duration: _duration,
      speed: _speed,
      loopStart: _loopStart,
      loopEnd: _loopEnd,
      looping: _looping && hasLoop,
      title: _title,
      artist: _artist,
    );
  }

  /// Where the track is, in the whole track. Read when needed (a screen
  /// asks every frame while it plays): the controller does not notify as it
  /// goes.
  Duration get position {
    if (_status != PlayerStatus.ready || !_loaded) return Duration.zero;
    final at = _output.position;
    return at > _duration ? _duration : at;
  }

  /// The speed in percent, 50 to 125; the pitch does not change.
  int get speed => _speed;

  /// The ends of the loop, or null while not marked.
  Duration? get loopStart => _loopStart;
  Duration? get loopEnd => _loopEnd;

  /// True when both ends are marked.
  bool get hasLoop => _loopStart != null && _loopEnd != null;

  /// True when the track repeats from B to A.
  bool get looping => _looping && hasLoop;

  /// The peaks of the open track (RF-PLY-15); null before it is ready.
  TrackPeaks? get peaks => _peaks;

  /// A call, or another player, took the sound: the app pauses the Player
  /// like the other sections (see PauseReason.interrupted).
  Stream<void> get interruptions => _interruptions.stream;

  /// The system's file chooser, then the track chosen opens. The chooser is
  /// the first thing asked: in a web page it works only inside the touch.
  Future<void> pick() async {
    final picked = await _files.pick();
    if (picked == null || _disposed) return;
    await open(picked);
  }

  /// Opens [track], ready to play from its start; the one before is let go.
  /// A take ([RecordedTrack]) is opened over the track being studied, which
  /// is kept with its speed and passage and comes back when the take is
  /// removed. A problem leaves the Player empty and says why in [problem].
  Future<void> open(TrackRef track) async {
    final generation = ++_generation;
    _forgetDiscarded();
    final old = _track;
    // The reading of the last track stops before the system is asked for
    // another: a cancel arriving after would close the new one.
    _stopReadingPeaks();
    if (_playing) {
      _playing = false;
      unawaited(_output.pause());
    }
    if (track is RecordedTrack) {
      // The first take over a track keeps it; the next ones replace the
      // take, and the track under it stays the same.
      if (old != null && old is! RecordedTrack) {
        final kept = setup;
        if (kept != null) {
          _beforeTake = kept;
        } else {
          unawaited(_files.release(old));
        }
      } else if (old is RecordedTrack) {
        unawaited(_files.release(old));
      }
    } else {
      _dropBeforeTake(except: track);
      if (old != null && old.uri != track.uri) unawaited(_files.release(old));
    }
    _track = track;
    _duration = Duration.zero;
    _status = PlayerStatus.opening;
    _problem = null;
    _settle?.cancel();
    _loopStart = _loopEnd = null;
    _active = LoopEdge.start;
    _looping = false;
    _loaded = false;
    _title = _artist = null;
    _activated = true;
    if (_speed != 100) {
      _speed = 100;
      unawaited(_output.setSpeed(1));
    }
    notifyListeners();
    try {
      final duration = await _output.open(track);
      if (generation != _generation || _disposed) return;
      _duration = duration;
      _status = PlayerStatus.ready;
      _loaded = true;
      _readPeaks(track, duration);
      unawaited(_readTags(track, generation));
      // A start asked while the track opened plays as soon as it is ready.
      if (_playing) await _output.play();
    } on TrackOpenException catch (error) {
      if (generation != _generation || _disposed) return;
      _fail(error.problem);
    } on Object catch (error) {
      debugPrint('The track could not be opened: $error');
      if (generation != _generation || _disposed) return;
      _fail(TrackProblem.unreadable);
    }
    if (!_disposed) notifyListeners();
  }

  /// Starts reading the peaks of [track]. A track with no wave (too long for
  /// a web page, a codec the system cannot decode) says nothing: it plays
  /// all the same.
  void _readPeaks(TrackRef track, Duration duration) {
    final peaks = TrackPeaks();
    _peaks = peaks;
    _peaksReading = _files
        .peaks(track, duration: duration)
        .listen(
          peaks.add,
          onDone: peaks.finish,
          onError: (Object error) {
            debugPrint('No wave for this track: $error');
            peaks.fail();
          },
          cancelOnError: true,
        );
  }

  void _stopReadingPeaks() {
    _peaksReading?.cancel();
    _peaksReading = null;
    _peaks = null;
  }

  /// Brings back the track of the last launch, with its speed and passage
  /// (RF-PLY-13). Nothing is asked of the system: the file is looked at when
  /// the tab is reached ([activate]) and opened at the first play.
  void restore(PlayerSetup setup) {
    if (_track != null || _disposed) return;
    _generation++;
    _track = setup.track;
    _duration = setup.duration;
    _status = PlayerStatus.ready;
    _loaded = false;
    _activated = false;
    _speed = setup.speed;
    _loopStart = setup.loopStart;
    _loopEnd = setup.loopEnd;
    _looping = setup.looping;
    _active = LoopEdge.start;
    _title = setup.title;
    _artist = setup.artist;
    notifyListeners();
  }

  /// The tab of the Player is on screen: a remembered track is looked at once
  /// (can it still be read?), and its wave and tags are read. A file that
  /// is gone says so, and the memory of it is cleared.
  Future<void> activate() async {
    final track = _track;
    if (_activated || track == null || _disposed) return;
    _activated = true;
    final generation = _generation;
    bool readable;
    try {
      readable = await _files.canRead(track);
    } on Object catch (error) {
      debugPrint('The remembered track could not be looked at: $error');
      readable = false;
    }
    if (generation != _generation || _disposed) return;
    if (!readable) {
      _fail(TrackProblem.missing);
      notifyListeners();
      return;
    }
    if (_peaks == null) _readPeaks(track, _duration);
    unawaited(_readTags(track, generation));
  }

  Future<void> _readTags(TrackRef track, int generation) async {
    try {
      final tags = await _files.tags(track);
      if (generation != _generation || _disposed) return;
      String? clean(String? text) {
        final trimmed = text?.trim();
        return trimmed == null || trimmed.isEmpty ? null : trimmed;
      }

      // A file with no tag keeps what was remembered of it.
      final title = clean(tags.title) ?? _title;
      final artist = clean(tags.artist) ?? _artist;
      if (title == _title && artist == _artist) return;
      _title = title;
      _artist = artist;
      notifyListeners();
    } on Object catch (error) {
      debugPrint('The tags of the track could not be read: $error');
    }
  }

  /// Opens a remembered track in the system's player, at [at], with its speed
  /// and passage; false if it cannot be (the Player is then empty and says
  /// why).
  Future<bool> _load(Duration at) =>
      _loading ??= _openRemembered(at).whenComplete(() => _loading = null);

  Future<bool> _openRemembered(Duration at) async {
    final track = _track;
    if (track == null) return false;
    final generation = _generation;
    try {
      final duration = await _output.open(track, at: at);
      if (generation != _generation || _disposed) return false;
      _duration = duration;
      _loaded = true;
      if (_speed != 100) await _output.setSpeed(_speed / 100);
      if (looping) await _output.setLoop(_loopStart, _loopEnd);
      return true;
    } on TrackOpenException catch (error) {
      if (generation != _generation || _disposed) return false;
      _fail(error.problem);
    } on Object catch (error) {
      debugPrint('The remembered track could not be opened: $error');
      if (generation != _generation || _disposed) return false;
      _fail(TrackProblem.unreadable);
    }
    notifyListeners();
    return false;
  }

  /// Empties the Player: the X beside the track's name (RF-PLY-21). A file
  /// is closed and no longer remembered (it stays on the phone); a take
  /// goes as with [removeRecording], the track under it coming back, and
  /// one not saved can be brought back for [undoTime] with [undoDiscard].
  Future<void> close() async {
    final track = _track;
    if (track == null) return;
    if (track is RecordedTrack) {
      final keep = !track.saved;
      await removeRecording(track, keepFile: keep);
      if (keep && !_disposed && !identical(_track, track)) _offerUndo(track);
      return;
    }
    await stop();
    if (_disposed || !identical(_track, track)) return;
    ++_generation;
    _settle?.cancel();
    _forgetDiscarded();
    _clearTrack(null);
    notifyListeners();
  }

  /// Opens again the take just discarded, over the track it was over.
  Future<void> undoDiscard() async {
    final take = _discarded;
    if (take == null) return;
    _undoTimer?.cancel();
    _undoTimer = null;
    _discarded = null;
    await open(take);
  }

  /// Lets the discarded take go at once, before [undoTime] is over.
  void dismissUndo() {
    if (_discarded == null) return;
    _forgetDiscarded();
    notifyListeners();
  }

  void _offerUndo(RecordedTrack take) {
    _forgetDiscarded();
    _discarded = take;
    _undoTimer = Timer(undoTime, dismissUndo);
    notifyListeners();
  }

  void _forgetDiscarded() {
    _undoTimer?.cancel();
    _undoTimer = null;
    final take = _discarded;
    _discarded = null;
    if (take != null) releaseRecording(take);
  }

  /// Removes the take open (its temporary file is deleted; a copy already
  /// saved stays) and brings back the track that was being studied under
  /// it, with its speed and passage (RF-PLY-20). With [keepFile] the
  /// temporary file stays, so that the take can be opened again (Undo);
  /// [releaseRecording] lets it go once it is no longer wanted.
  Future<void> removeRecording(
    RecordedTrack take, {
    bool keepFile = false,
  }) async {
    if (!identical(_track, take)) return;
    await stop();
    if (_disposed || !identical(_track, take)) return;
    ++_generation;
    _settle?.cancel();
    _clearTrack(null, release: !keepFile);
    _backToTrack();
    notifyListeners();
  }

  /// Gives the take open the name it is shared and saved with (without its
  /// extension); does nothing without a take.
  void renameTake(String name) {
    final take = _track;
    if (take is! RecordedTrack || take.fileName == name) return;
    take.fileName = name;
    notifyListeners();
  }

  /// Lets go of the file of a take removed with `keepFile`, unless it has
  /// been opened again in the meantime.
  void releaseRecording(RecordedTrack take) {
    if (identical(_track, take)) return;
    unawaited(_files.release(take));
  }

  /// A take that cannot be played also gives the track back.
  void _fail(TrackProblem problem) {
    final take = _track is RecordedTrack;
    _clearTrack(problem);
    if (take) _backToTrack();
  }

  /// Brings back the track that was under the take, if there was one.
  void _backToTrack() {
    final before = _beforeTake;
    _beforeTake = null;
    if (before == null) return;
    restore(before);
    // The Player is on screen: the file is looked at again, and its wave
    // and tags are read.
    unawaited(activate());
  }

  /// Another track chosen while a take is open: the track under the take
  /// is let go, unless it is the one chosen again.
  void _dropBeforeTake({required TrackRef except}) {
    final before = _beforeTake;
    _beforeTake = null;
    if (before != null && before.track.uri != except.uri) {
      unawaited(_files.release(before.track));
    }
  }

  void _clearTrack(TrackProblem? problem, {bool release = true}) {
    final failed = _track;
    if (failed != null && release) unawaited(_files.release(failed));
    _stopReadingPeaks();
    _loaded = false;
    _title = _artist = null;
    _track = null;
    _duration = Duration.zero;
    _status = PlayerStatus.empty;
    _playing = false;
    _problem = problem;
    _loopStart = _loopEnd = null;
    _active = LoopEdge.start;
    _looping = false;
  }

  /// Plays the track from where it is. Without a track it does nothing: the
  /// screen opens the chooser instead.
  @override
  Future<void> start() async {
    if (_track == null || _playing) return;
    _playing = true;
    notifyListeners();
    if (_status != PlayerStatus.ready) return;
    if (!_loaded) {
      // A remembered track opens now, at A if the loop is on.
      final at = looping ? _loopStart! : Duration.zero;
      if (!await _load(at) || !_playing) return;
    }
    await _output.play();
  }

  /// Pauses; the position stays.
  @override
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
    await _output.pause();
  }

  Future<void> toggle() => _playing ? stop() : start();

  /// Moves the listening point to [to], within the track. A point outside
  /// the loop turns it off (A and B stay marked).
  Future<void> seek(Duration to) async {
    if (_status != PlayerStatus.ready) return;
    final clamped = _within(to);
    if (!_loaded && !await _load(clamped)) return;
    if (looping && (clamped < _loopStart! || clamped >= _loopEnd!)) {
      _looping = false;
      _settle?.cancel();
      await _queue(() => _output.setLoop(null, null));
    }
    await _output.seek(clamped);
    if (!_disposed) notifyListeners();
  }

  Duration _within(Duration t) =>
      t.isNegative ? Duration.zero : (t > _duration ? _duration : t);

  /// Sets the speed, [minSpeed] to [maxSpeed] percent, at once.
  void setSpeed(int percent) {
    final clamped = percent.clamp(minSpeed, maxSpeed);
    if (clamped == _speed) return;
    _speed = clamped;
    if (_loaded) unawaited(_output.setSpeed(clamped / 100));
    notifyListeners();
  }

  /// Marks the start or the end of the loop where the track is heard, less
  /// the person's reaction (RF-PLY-09), as [place] does.
  Future<void> mark(LoopEdge edge) {
    return place(edge, _heardPosition);
  }

  Duration get _heardPosition {
    final lag = Duration(
      microseconds: (reaction.inMicroseconds * _speed / 100).round(),
    );
    return position - lag;
  }

  /// The two-touch control uses the exact cursor when paused. While listening,
  /// both marks use the same reaction compensation as the ring's actions.
  Future<void> captureOrToggle() async {
    if (hasLoop) return setLooping(!looping);
    final at = _playing ? _heardPosition : position;
    final a = _loopStart;
    if (a == null) return place(LoopEdge.start, at);
    // Preserve A on a quick double tap and enforce the minimum duration.
    final b = position >= duration ? duration : at;
    await place(LoopEdge.end, b < a + minLoop ? a + minLoop : b);
  }

  Future<void> clearPassage() async {
    _settle?.cancel();
    _loopStart = _loopEnd = null;
    _looping = false;
    _active = LoopEdge.start;
    notifyListeners();
    await _queue(_applyLoop);
  }

  /// Marks an endpoint. Replacing it discards an incompatible opposite
  /// endpoint. A complete passage repeats, restarting at A when playing.
  Future<void> place(LoopEdge edge, Duration at) async {
    if (_status != PlayerStatus.ready || _duration < minLoop) return;
    final wasLooping = looping;
    final t = _within(at);
    switch (edge) {
      case LoopEdge.start:
        final a = t > _duration - minLoop ? _duration - minLoop : t;
        _loopStart = a;
        final end = _loopEnd;
        if (end != null && end - a < minLoop) _loopEnd = null;
      case LoopEdge.end:
        final b = t;
        _loopEnd = b;
        final start = _loopStart;
        if (start != null && b - start < minLoop) _loopStart = null;
    }
    _active = edge;
    _looping = hasLoop;
    _settle?.cancel();
    notifyListeners();
    if (_looping) {
      await _queue(() => _applyLoop(jumpTo: _playing ? _loopStart : null));
    } else if (wasLooping) {
      // A loop that was on is told that it is off.
      await _queue(_applyLoop);
    }
  }

  /// Moves an end of the loop to the time [to] (RF-PLY-10, RF-PLY-11). Each
  /// end stops at its limit and does not push the other: A between the start
  /// of the track and one [minLoop] before B, B between one [minLoop] after A
  /// and the end. The number changes at once; the sound follows when the
  /// person has stopped touching for [settleAfter], carrying on if the track
  /// is still inside the loop.
  void moveEdge(LoopEdge edge, Duration to) {
    final start = _loopStart, end = _loopEnd;
    if (_status != PlayerStatus.ready) return;
    switch (edge) {
      case LoopEdge.start:
        if (start == null) return;
        final top = (end ?? _duration) - minLoop;
        _loopStart = _clampTo(to, Duration.zero, top);
      case LoopEdge.end:
        if (end == null) return;
        _loopEnd = _clampTo(
          to,
          start == null ? Duration.zero : start + minLoop,
          _duration,
        );
    }
    _active = edge;
    notifyListeners();
    _settle?.cancel();
    if (!looping) return;
    _settle = Timer(settleAfter, () {
      if (_disposed || !looping) return;
      final a = _loopStart!, b = _loopEnd!;
      // Inside the new loop it carries on, to B and then from A. Before A it
      // goes to A; past B it plays the last [preroll] before B, to hear how
      // the loop closes, never before A.
      final at = _output.position;
      final jump = !_playing || (at >= a && at < b)
          ? null
          : (at < a || b - preroll < a ? a : b - preroll);
      unawaited(_queue(() => _applyLoop(jumpTo: jump)));
    });
  }

  /// Moves an end of the loop by [by] (negative: earlier), as [moveEdge].
  void nudge(LoopEdge edge, Duration by) {
    final at = edge == LoopEdge.start ? _loopStart : _loopEnd;
    if (at == null) return;
    moveEdge(edge, at + by);
  }

  Duration _clampTo(Duration t, Duration low, Duration high) {
    if (high < low) return low;
    return t < low ? low : (t > high ? high : t);
  }

  /// Sets the loop between [a] and [b] (put in order, within the track, at
  /// least [minLoop] long) and turns it on; if the track plays, it restarts
  /// from A.
  Future<void> setLoop(Duration a, Duration b) async {
    if (_status != PlayerStatus.ready || _duration < minLoop) return;
    var start = _within(a < b ? a : b);
    var end = _within(a < b ? b : a);
    if (end - start < minLoop) end = start + minLoop;
    if (end > _duration) {
      end = _duration;
      start = end - minLoop;
    }
    _loopStart = start;
    _loopEnd = end;
    _looping = true;
    _active = LoopEdge.end;
    _settle?.cancel();
    notifyListeners();
    await _queue(() => _applyLoop(jumpTo: _playing ? start : null));
  }

  /// The flag that ‹ and › move: the last one placed, dragged or touched.
  /// A at first and with each new track; it is not kept.
  LoopEdge get activeEdge => _active;

  /// Makes [edge] the flag that ‹ and › move.
  void focus(LoopEdge edge) {
    if (_active == edge) return;
    _active = edge;
    notifyListeners();
  }

  /// Turns the repeat on, if both ends are marked, or off. Turning it on
  /// with the track outside the stretch goes to A.
  Future<void> setLooping(bool on) async {
    if (_status != PlayerStatus.ready) return;
    if (on && !hasLoop) return;
    if (_looping == on) return;
    _looping = on;
    _settle?.cancel();
    notifyListeners();
    await _queue(_applyLoop);
  }

  Future<void> _queue(Future<void> Function() work) =>
      _loopWork = (_loopWork ?? Future<void>.value())
          .then((_) => work())
          .catchError((Object error) {
            debugPrint('The loop could not be set: $error');
          });

  /// Tells the output the loop as it stands now, then puts the track back
  /// where it was (or at [jumpTo]; or at A if it is outside the loop): the
  /// output may be anywhere after the change.
  Future<void> _applyLoop({Duration? jumpTo}) async {
    // A remembered track not opened yet is told the loop when it opens.
    if (_disposed || !_loaded) return;
    final on = looping;
    final a = _loopStart, b = _loopEnd;
    var to = jumpTo ?? _output.position;
    if (on && (to < a! || to >= b!)) to = a;
    await _output.setLoop(on ? a : null, on ? b : null);
    await _output.seek(to);
    if (!_disposed) notifyListeners();
  }

  void _onEvent(TrackEvent event) {
    switch (event) {
      case TrackEvent.ended:
        // The output stopped by itself and went back to the start.
        _playing = false;
        notifyListeners();
      case TrackEvent.interrupted:
        _interruptions.add(null);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _undoTimer?.cancel();
    final discarded = _discarded;
    if (discarded != null) unawaited(_files.release(discarded));
    _settle?.cancel();
    _stopReadingPeaks();
    _events.cancel();
    _interruptions.close();
    // The right to read the file is kept: the track is remembered.
    final track = _track;
    if (track is RecordedTrack) unawaited(_files.release(track));
    unawaited(_output.close());
    super.dispose();
  }
}
