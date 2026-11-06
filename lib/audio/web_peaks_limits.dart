/// How big a file the web app reads for the wave of the Player (RF-PLY-15):
/// the browser decodes the whole file to work it out, which takes memory a
/// phone's browser may not have. Beyond these the track plays all the same,
/// with no wave.
const webPeaksMaxBytes = 40 * 1000 * 1000;
const webPeaksMaxDuration = Duration(minutes: 15);

/// Whether a file of [size] bytes ([size] null when not known) and
/// [duration] may be read for its wave in a web page.
bool webPeaksAllowed({required int? size, required Duration duration}) =>
    (size == null || size <= webPeaksMaxBytes) &&
    duration <= webPeaksMaxDuration;
