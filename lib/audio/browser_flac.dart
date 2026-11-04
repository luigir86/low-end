/// Decodes FLAC recordings with the browser's own decoder, in a web page:
/// some twenty times faster than the audio engine's, which runs on the
/// page's only thread. Elsewhere (the Android app, the tests) there is none.
library;

export 'browser_flac_stub.dart'
    if (dart.library.js_interop) 'browser_flac_web.dart';
