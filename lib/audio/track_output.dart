import 'dart:async';

/// A track the person chose: where the system reads it from, and its name.
/// The uri is a `content://` address on Android and a `blob:` address in a
/// web page, both valid only for as long as the system says (see
/// [TrackFiles]).
class TrackRef {
  const TrackRef({required this.uri, required this.name, this.size});

  final String uri;

  /// The file's name, with its extension.
  final String name;

  /// Size in bytes, when the system says.
  final int? size;

  /// The name without the extension: what stands for a track that has no
  /// title in its tags.
  String get baseName {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Map<String, Object?> toJson() => {
    'uri': uri,
    'name': name,
    if (size != null) 'size': size,
  };

  /// Reads what [toJson] wrote; null when [json] is not a track.
  static TrackRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final uri = json['uri'], name = json['name'], size = json['size'];
    if (uri is! String || uri.isEmpty || name is! String) return null;
    return TrackRef(uri: uri, name: name, size: size is int ? size : null);
  }

  @override
  bool operator ==(Object other) =>
      other is TrackRef && other.uri == uri && other.name == name;

  @override
  int get hashCode => Object.hash(uri, name);
}

/// Why a track could not be opened (RF-PLY-07).
enum TrackProblem {
  /// The system cannot play it: a format it does not read, or a protected
  /// file.
  unreadable,

  /// The file is gone, or the permission to read it was lost.
  missing,
}

class TrackOpenException implements Exception {
  TrackOpenException(this.problem, [this.detail]);

  final TrackProblem problem;
  final Object? detail;

  @override
  String toString() => 'TrackOpenException($problem, $detail)';
}

/// What happens to the track without the person asking.
enum TrackEvent {
  /// It reached its end (and was not looping): it stopped and went back to
  /// the start.
  ended,

  /// A call, or another player, took the sound away.
  interrupted,
}

/// Plays one track at a time, read piece by piece by the system's own
/// player (ExoPlayer on Android, the browser's audio element on the web),
/// whatever its length. Kept behind an interface so that the rest of the app
/// can be tested without a phone.
abstract interface class TrackOutput {
  /// Opens [track], ready to play from [at]; answers with its length. Throws
  /// a [TrackOpenException] when it cannot.
  Future<Duration> open(TrackRef track, {Duration at = Duration.zero});

  Future<void> play();

  Future<void> pause();

  /// Where the track is: always the position in the whole track.
  Duration get position;

  Future<void> seek(Duration position);

  /// The sound, speed: 0.5 to 1.25, the pitch unchanged.
  Future<void> setSpeed(double speed);

  Stream<TrackEvent> get events;

  /// Lets go of the file and the system player.
  Future<void> close();
}

/// A [TrackOutput] that makes no sound, for tests and for the app when it
/// is tested with silent outputs. It plays by being told how much time went
/// by ([advance]).
class SilentTrackOutput implements TrackOutput {
  SilentTrackOutput({this.length = const Duration(minutes: 6)});

  /// How long every track opened is.
  Duration length;

  /// Makes the next [open] fail with this, then clears it.
  TrackOpenException? failWith;

  /// The track last opened; null before the first, and after [close].
  TrackRef? opened;
  var openCount = 0;
  var playing = false;
  var speed = 1.0;
  var closed = false;

  /// Every point [seek] was asked for.
  final seeks = <Duration>[];

  Duration _position = Duration.zero;
  final _events = StreamController<TrackEvent>.broadcast();

  @override
  Future<Duration> open(TrackRef track, {Duration at = Duration.zero}) async {
    openCount++;
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }
    opened = track;
    playing = false;
    _position = at;
    return length;
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  Duration get position => _position;

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _position = position;
  }

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Stream<TrackEvent> get events => _events.stream;

  /// Lets [time] of the listener's time go by: the track moves on by that
  /// much times the speed, and at its end stops and goes back to the start.
  void advance(Duration time) {
    if (!playing) return;
    _position += time * speed;
    if (_position >= length) {
      playing = false;
      _position = Duration.zero;
      _events.add(TrackEvent.ended);
    }
  }

  /// A call, or another player, takes the sound.
  void interrupt() => _events.add(TrackEvent.interrupted);

  @override
  Future<void> close() async {
    closed = true;
    opened = null;
    playing = false;
    await _events.close();
  }
}
