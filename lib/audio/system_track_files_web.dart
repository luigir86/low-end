import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'track_files.dart';
import 'track_output.dart';

/// See system_track_files.dart.
TrackFiles systemTrackFiles() => WebTrackFiles();

/// [TrackFiles] from the browser's file chooser. The file becomes a `blob:`
/// address the audio element plays; it lasts as long as the page.
class WebTrackFiles implements TrackFiles {
  Completer<TrackRef?>? _pending;

  /// The audio formats offered; the browser may still list others.
  static const _accept = 'audio/*,.mp3,.m4a,.aac,.wav,.flac';

  /// Not `async`, and nothing awaited before the click: Safari opens the
  /// chooser only inside the touch that asked for it.
  @override
  Future<TrackRef?> pick() {
    // A chooser left open and forgotten (some browsers never say it was
    // closed) gives way to this one.
    _pending?.complete(null);
    final done = Completer<TrackRef?>();
    _pending = done;
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = _accept;
    input.onchange = ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        _finish(done, null);
        return;
      }
      final uri = web.URL.createObjectURL(file);
      _finish(done, TrackRef(uri: uri, name: file.name, size: file.size));
    }).toJS;
    input.addEventListener(
      'cancel',
      ((web.Event _) => _finish(done, null)).toJS,
    );
    input.click();
    return done.future;
  }

  void _finish(Completer<TrackRef?> done, TrackRef? track) {
    if (!done.isCompleted) done.complete(track);
    if (identical(_pending, done)) _pending = null;
  }

  // A blob does not survive the page, so nothing is remembered here.
  @override
  Future<bool> canRead(TrackRef track) async => false;

  @override
  Future<TrackTags> tags(TrackRef track) async => (title: null, artist: null);

  @override
  Future<Float32List?> envelope(TrackRef track, int points) async => null;

  @override
  Future<void> release(TrackRef track) async {
    web.URL.revokeObjectURL(track.uri);
  }
}
