import 'track_output.dart';

/// A take belongs to the current session. Exporting it leaves the player
/// pointing at the original so the loop and position are preserved.
class RecordedTrack extends TrackRef {
  RecordedTrack({required super.uri, required super.name});
  bool saved = false;
}
