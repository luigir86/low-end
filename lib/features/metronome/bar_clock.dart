import 'package:flutter/foundation.dart';

import 'time_signature.dart';

/// The length, position, tempo and time signature of the bar a progression
/// follows: the metronome's, so chords change on its "one". It notifies when
/// the tempo or the time signature change.
abstract interface class BarClock implements Listenable {
  /// Beats per minute of the figure the tempo counts (in 6/8, dotted
  /// quarters, see [TimeSignature.pulsesPerBeat]), as heard: a tempo still
  /// being chosen on the metronome's − and + is not heard yet.
  int get soundingBpm;
  TimeSignature get signature;

  Duration get barLength;

  /// How far into the bar it is, 0 to 1, or null when not counting.
  double? get barPhase;
}
