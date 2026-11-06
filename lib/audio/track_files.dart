import 'dart:typed_data';

import 'track_output.dart';

/// The title and the artist written in a file's tags; null when missing.
typedef TrackTags = ({String? title, String? artist});

/// The system's side of the Player's files: choosing one with the file
/// chooser (no permission needed), and letting it go. Kept behind an
/// interface so that the rest of the app can be tested without a phone.
abstract interface class TrackFiles {
  /// The system's file chooser; null if closed without a choice. In a web
  /// page it must be called inside the touch, with nothing awaited before it
  /// (Safari refuses the chooser otherwise).
  Future<TrackRef?> pick();

  /// Whether [track] can still be read (the file was not moved, the
  /// permission was not lost). On the web a track never survives the page.
  Future<bool> canRead(TrackRef track);

  /// The title and the artist in the tags of [track].
  Future<TrackTags> tags(TrackRef track);

  /// The loudness of [track] over [points] equal slices of its length, each
  /// from 0 to 1; null when it cannot be worked out.
  Future<Float32List?> envelope(TrackRef track, int points);

  /// Lets go of what was kept for [track]: the permission to read it
  /// (Android) or its blob (web).
  Future<void> release(TrackRef track);
}

/// A [TrackFiles] for tests: [next] is what the chooser gives.
class FakeTrackFiles implements TrackFiles {
  FakeTrackFiles({this.next});

  /// What the next [pick] answers; null is a chooser closed with no choice.
  TrackRef? next;

  var picks = 0;
  final released = <TrackRef>[];

  @override
  Future<TrackRef?> pick() async {
    picks++;
    return next;
  }

  @override
  Future<bool> canRead(TrackRef track) async => true;

  @override
  Future<TrackTags> tags(TrackRef track) async => (title: null, artist: null);

  @override
  Future<Float32List?> envelope(TrackRef track, int points) async => null;

  @override
  Future<void> release(TrackRef track) async => released.add(track);
}
