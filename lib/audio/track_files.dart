import 'dart:async';
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

  /// The peaks of [track], one every 10 ms, in pieces from the start while
  /// the file is read (RF-PLY-15): each value is the strongest sample of
  /// those 10 ms, 0 to 32767. The stream ends when the whole track has been
  /// read, or with an error if it cannot be (in a web page, beyond the
  /// limits of web_peaks_limits.dart, at once). Cancelling the subscription
  /// stops the reading.
  Stream<Uint16List> peaks(TrackRef track, {required Duration duration});

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

  /// The tracks [peaks] was asked for, and the stream given for each: a test
  /// adds pieces, closes it or makes it fail.
  final peaksAsked = <TrackRef>[];
  final peakStreams = <StreamController<Uint16List>>[];

  /// How many of those streams have been cancelled by their listener.
  var peaksCancelled = 0;

  @override
  Future<TrackRef?> pick() async {
    picks++;
    return next;
  }

  /// What [canRead] answers, and the tracks it was asked about.
  var readable = true;
  final canReadAsked = <TrackRef>[];

  /// The tags of every track, or what [tagsFor] says; the tracks asked.
  TrackTags tagsAnswer = (title: null, artist: null);
  Future<TrackTags> Function(TrackRef track)? tagsFor;
  final tagsAsked = <TrackRef>[];

  @override
  Future<bool> canRead(TrackRef track) async {
    canReadAsked.add(track);
    return readable;
  }

  @override
  Future<TrackTags> tags(TrackRef track) {
    tagsAsked.add(track);
    final custom = tagsFor;
    return custom != null ? custom(track) : Future.value(tagsAnswer);
  }

  @override
  Stream<Uint16List> peaks(TrackRef track, {required Duration duration}) {
    peaksAsked.add(track);
    final stream = StreamController<Uint16List>(
      onCancel: () => peaksCancelled++,
    );
    peakStreams.add(stream);
    return stream.stream;
  }

  @override
  Future<void> release(TrackRef track) async => released.add(track);
}
