import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'track_files.dart';
import 'track_output.dart';

/// See system_track_files.dart.
TrackFiles systemTrackFiles() => AndroidTrackFiles();

/// [TrackFiles] from Android's document chooser, through TrackFiles.kt: it
/// asks for no permission, and keeps the right to read the chosen file.
class AndroidTrackFiles implements TrackFiles {
  static const _channel = MethodChannel('low_end/track_files');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<TrackRef?> pick() async {
    if (!_supported) return null;
    final picked = await _channel.invokeMapMethod<String, Object?>('pick');
    if (picked == null) return null;
    return TrackRef.fromJson(picked);
  }

  // The next steps of the Player fill these in; until then they answer
  // "unknown": not readable again, no tags, no loudness.
  @override
  Future<bool> canRead(TrackRef track) async => false;

  @override
  Future<TrackTags> tags(TrackRef track) async => (title: null, artist: null);

  @override
  Future<Float32List?> envelope(TrackRef track, int points) async => null;

  @override
  Future<void> release(TrackRef track) async {}
}
