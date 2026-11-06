import 'dart:async';
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
  static const _peaks = EventChannel('low_end/track_peaks');

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
  Stream<Uint16List> peaks(TrackRef track, {required Duration duration}) {
    if (!_supported) return const Stream.empty();
    StreamSubscription<Object?>? source;
    late final StreamController<Uint16List> out;
    out = StreamController<Uint16List>(
      onListen: () {
        source = _peaks
            .receiveBroadcastStream({'uri': track.uri})
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

  @override
  Future<void> release(TrackRef track) async {}
}
