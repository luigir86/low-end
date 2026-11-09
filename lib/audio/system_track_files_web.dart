import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../features/player/track_tags.dart';
import 'recorded_track.dart';
import 'track_files.dart';
import 'track_output.dart';
import 'web_peaks_limits.dart';

@JS('lowEndPeaks')
external JSFunction? get _peaksFunction;

/// See system_track_files.dart.
TrackFiles systemTrackFiles() => WebTrackFiles();

final _takes = <String, web.File>{};
Future<String> recordingPath(String name) async => name;

Future<RecordedTrack> recordedTrack(String url, String name) async {
  try {
    final response = await web.window.fetch(url.toJS).toDart;
    final blob = await response.blob().toDart;
    _takes[url] = web.File(
      [blob].toJS,
      name,
      web.FilePropertyBag(type: 'audio/wav'),
    );
    return RecordedTrack(uri: url, name: name);
  } catch (_) {
    web.URL.revokeObjectURL(url);
    rethrow;
  }
}

Future<bool> saveRecording(RecordedTrack track) async {
  final link = web.HTMLAnchorElement()
    ..href = track.uri
    ..download = track.name;
  link.click();
  return true;
}

Future<bool> shareRecording(RecordedTrack track) async {
  final data = web.ShareData(
    files: [_takes[track.uri]!].toJS,
    title: track.baseName,
  );
  final navigator = web.window.navigator;
  if (!navigator.has('canShare') || !navigator.canShare(data)) return false;
  try {
    await navigator.share(data).toDart;
  } catch (error) {
    if (error.toString().contains('AbortError')) return true;
    rethrow;
  }
  return true;
}

/// [TrackFiles] from the browser's file chooser. The file becomes a `blob:`
/// address the audio element plays; it lasts as long as the page.
class WebTrackFiles implements TrackFiles {
  Completer<TrackRef?>? _pending;

  /// The files chosen, by their blob address: the wave is read from them.
  final _files = <String, web.File>{};

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
      _files[uri] = file;
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

  /// The ID3v2 tag at the start of an MP3 (the browser tells no more): the
  /// first 128 KB of the file are read.
  @override
  Future<TrackTags> tags(TrackRef track) async {
    const none = (title: null, artist: null);
    final file = _files[track.uri];
    if (file == null) return none;
    try {
      final head = await file.slice(0, 128 * 1024).arrayBuffer().toDart;
      return readId3Tags(head.toDart.asUint8List());
    } on Object catch (error) {
      debugPrint('The tags of a track could not be read: $error');
      return none;
    }
  }

  /// The browser decodes the whole file (web/flutter_bootstrap.js), so only
  /// a file within the limits of web_peaks_limits.dart is tried, and the
  /// peaks come in one piece. An error means no wave, never a message.
  @override
  Stream<Uint16List> peaks(
    TrackRef track, {
    required Duration duration,
  }) async* {
    final file = _files[track.uri] ?? _takes[track.uri];
    final read = _peaksFunction;
    if (file == null ||
        read == null ||
        !webPeaksAllowed(size: file.size, duration: duration)) {
      throw StateError('no wave for this track');
    }
    try {
      final data = await file.arrayBuffer().toDart;
      final promise = read.callAsFunction(null, data) as JSPromise;
      final peaks = (await promise.toDart) as JSUint16Array;
      yield peaks.toDart;
    } catch (error) {
      debugPrint('The browser could not read the wave of a track: $error');
      rethrow;
    }
  }

  @override
  Future<void> release(TrackRef track) async {
    _files.remove(track.uri);
    _takes.remove(track.uri);
    web.URL.revokeObjectURL(track.uri);
  }
}
