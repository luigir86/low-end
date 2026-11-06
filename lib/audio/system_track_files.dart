/// The real [TrackFiles] of the platform: the system's document chooser on
/// Android, an `<input type="file">` in a web page. Elsewhere (the tests)
/// there is no chooser.
library;

export 'system_track_files_io.dart'
    if (dart.library.js_interop) 'system_track_files_web.dart';
