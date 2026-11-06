import '../../audio/track_output.dart';

/// What the Player keeps between launches (RF-PLY-13): the track, how long it
/// is, the speed and the passage. Written as JSON in the settings; reading it
/// back never fails: whatever is wrong falls back to the default, and with no
/// track there is no setup at all.
class PlayerSetup {
  const PlayerSetup({
    required this.track,
    required this.duration,
    this.speed = 100,
    this.loopStart,
    this.loopEnd,
    this.looping = false,
    this.title,
    this.artist,
  });

  final TrackRef track;
  final Duration duration;

  /// In percent, 50 to 125.
  final int speed;
  final Duration? loopStart;
  final Duration? loopEnd;
  final bool looping;

  /// From the tags of the file, when it has them.
  final String? title;
  final String? artist;

  Map<String, Object?> toJson() => {
    ...track.toJson(),
    'duration': duration.inMilliseconds,
    'speed': speed,
    if (loopStart != null) 'start': loopStart!.inMilliseconds,
    if (loopEnd != null) 'end': loopEnd!.inMilliseconds,
    'looping': looping,
    if (title != null) 'title': title,
    if (artist != null) 'artist': artist,
  };

  /// Reads what [toJson] wrote; null when there is no track in [json] or its
  /// length is no use. The other fields that are wrong are left out.
  static PlayerSetup? fromJson(Object? json) {
    final track = TrackRef.fromJson(json);
    if (track == null || json is! Map) return null;
    final length = json['duration'];
    if (length is! int || length <= 0) return null;
    final duration = Duration(milliseconds: length);
    Duration? time(Object? ms) => ms is int && ms >= 0 && ms <= length
        ? Duration(milliseconds: ms)
        : null;
    var start = time(json['start']), end = time(json['end']);
    // A passage needs two ends in order; one alone stays as a mark.
    if (start != null && end != null && end <= start) {
      start = end = null;
    }
    final speed = json['speed'];
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value : null;
    return PlayerSetup(
      track: track,
      duration: duration,
      speed: speed is int ? speed.clamp(50, 125) : 100,
      loopStart: start,
      loopEnd: end,
      looping: json['looping'] == true && start != null && end != null,
      title: text(json['title']),
      artist: text(json['artist']),
    );
  }
}
