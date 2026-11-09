import 'track_output.dart';

/// A take belongs to the current session. Exporting it leaves the player
/// pointing at the original so the loop and position are preserved.
class RecordedTrack extends TrackRef {
  RecordedTrack({required super.uri, required super.name});
  bool saved = false;

  /// The name the take stands for on screen and is shared and saved with,
  /// without its extension (Take1_9_nov_2026); the person can change it.
  /// It starts as the name of its temporary file.
  late String fileName = super.baseName;

  @override
  String get baseName => fileName;

  /// The extension of the temporary file (m4a, wav), kept by every name.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1) : '';
  }

  /// [fileName] with the [extension]: the name of the shared or saved file.
  String get exportName =>
      extension.isEmpty ? fileName : '$fileName.$extension';
}
