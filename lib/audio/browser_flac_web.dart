import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

@JS('lowEndDecodeFlac')
external JSFunction? get _decode;

/// Whether the browser could not decode a file once: from then on it is not
/// asked again, and the audio engine decodes.
var _failed = false;

/// See browser_flac.dart: the first channel of [flac] as 16-bit samples, or
/// null if the browser cannot decode it (web/flutter_bootstrap.js).
Future<Int16List?> decodeFlacInBrowser(Uint8List flac) async {
  final decode = _decode;
  if (decode == null || _failed) return null;
  try {
    final promise = decode.callAsFunction(null, flac.toJS) as JSPromise;
    final samples = (await promise.toDart) as JSInt16Array;
    return Int16List.fromList(samples.toDart);
  } catch (error) {
    debugPrint('The browser could not decode a recording: $error');
    _failed = true;
    return null;
  }
}
