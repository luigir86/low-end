import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';

import 'recorded_track.dart';
import 'track_files.dart';
import 'track_output.dart';

/// See system_track_files.dart.
TrackFiles systemTrackFiles() => AndroidTrackFiles();

const _takes = MethodChannel('low_end/takes');

Future<String> recordingPath(String name) async =>
    (await _takes.invokeMethod<String>('path', name))!;

Future<RecordedTrack> recordedTrack(String path, String name) async =>
    RecordedTrack(uri: Uri.file(path).toString(), name: name);

/// Saves the take where the person chooses, as [RecordedTrack.exportName].
Future<bool> saveRecording(RecordedTrack track) async =>
    await _takes.invokeMethod<bool>('save', _export(track)) ?? false;

/// Shares the take as [RecordedTrack.exportName] through the system's share
/// window.
Future<bool> shareRecording(RecordedTrack track) async =>
    await _takes.invokeMethod<bool>('share', _export(track)) ?? false;

/// Audio files opened or shared from another app ("Open with Low End",
/// ReceivedTracks.kt): each comes as the app's own copy, for the Player.
/// Those that came before anyone listened (the app was opened by one)
/// come first.
Stream<TrackRef> receivedTracks({@visibleForTesting bool? android}) {
  if (!(android ?? (!kIsWeb && Platform.isAndroid))) {
    return const Stream.empty();
  }
  const channel = MethodChannel('low_end/received_tracks');
  final out = StreamController<TrackRef>();
  void add(Object? data) {
    final track = data is Map
        ? TrackRef.fromJson(Map<String, Object?>.from(data))
        : null;
    if (track != null) out.add(track);
  }

  channel.setMethodCallHandler((call) async {
    if (call.method == 'open') add(call.arguments);
  });
  unawaited(() async {
    try {
      final waiting = await channel.invokeListMethod<Object?>('ready');
      (waiting ?? const []).forEach(add);
    } on PlatformException catch (error) {
      debugPrint('Files from other apps cannot reach the Player: $error');
    }
  }());
  return out.stream;
}

Map<String, Object?> _export(RecordedTrack track) => {
  'path': Uri.parse(track.uri).toFilePath(),
  'name': track.exportName,
};

/// [TrackFiles] from Android's document chooser, through TrackFiles.kt: it
/// asks for no permission, and keeps the right to read the chosen file.
class AndroidTrackFiles implements TrackFiles {
  static const _channel = MethodChannel('low_end/track_files');
  static const _peaks = EventChannel('low_end/track_peaks');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<TrackRef?> pick() async {
    if (!_supported) return null;
    final picked = await _channel.invokeMapMethod<String, Object?>('pick');
    if (picked == null) return null;
    return TrackRef.fromJson(picked);
  }

  /// Whether the right to read the file was kept and the file is still
  /// there: after a restart the track is looked at before it is trusted.
  @override
  Future<bool> canRead(TrackRef track) async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('canRead', {'uri': track.uri}) ??
          false;
    } on PlatformException catch (error) {
      debugPrint('Could not tell if a track can be read: $error');
      return false;
    }
  }

  /// The tags the system reads (MediaMetadataRetriever): any format it plays.
  @override
  Future<TrackTags> tags(TrackRef track) async {
    const none = (title: null, artist: null);
    if (!_supported) return none;
    try {
      final tags = await _channel.invokeMapMethod<String, String?>('tags', {
        'uri': track.uri,
      });
      return (title: tags?['title'], artist: tags?['artist']);
    } on PlatformException catch (error) {
      debugPrint('Could not read the tags of a track: $error');
      return none;
    }
  }

  @override
  Stream<Uint16List> peaks(TrackRef track, {required Duration duration}) {
    if (!_supported) return const Stream.empty();
    StreamSubscription<Object?>? source;
    late final StreamController<Uint16List> out;
    out = StreamController<Uint16List>(
      onListen: () {
        source = _peaks
            .receiveBroadcastStream({'uri': track.uri, 'size': track.size})
            .listen(
              (data) {
                if (data is Uint8List) out.add(_unpack(data));
              },
              onError: out.addError,
              onDone: out.close,
            );
      },
      // Cancelling tells the Kotlin side to stop reading.
      onCancel: () => source?.cancel(),
    );
    return out.stream;
  }

  /// 16-bit little-endian pairs of bytes to values: read one by one, because
  /// the buffer of the channel may not be aligned to two bytes.
  static Uint16List _unpack(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    return Uint16List.fromList([
      for (var i = 0; i + 1 < bytes.length; i += 2)
        data.getUint16(i, Endian.little),
    ]);
  }

  /// Gives back the right to read the file, which the system limits in
  /// number: done when the track is replaced or cannot be read.
  @override
  Future<void> release(TrackRef track) async {
    if (track is RecordedTrack) {
      try {
        await File.fromUri(Uri.parse(track.uri)).delete();
      } on Object catch (error) {
        debugPrint('Could not release the temporary recording: $error');
      }
      return;
    }
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('release', {'uri': track.uri});
    } on PlatformException catch (error) {
      debugPrint('Could not let go of a track: $error');
    }
  }
}
