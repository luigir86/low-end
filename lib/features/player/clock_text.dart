/// A time as a clock shows it: "1:12", "0:05", "1:02:03" past the hour. With
/// [hundredths] a hundredth of a second follows ("1:12,34"), after the
/// [decimalSeparator] of the player's language (a comma in Italian, Spanish
/// and French, a point in English).
String clockText(
  Duration time, {
  bool hundredths = false,
  String decimalSeparator = '.',
}) {
  final total = time.isNegative ? Duration.zero : time;
  // Whole hundredths, cut and not rounded, so that 59.996 s never reads
  // 0:60.
  final all = total.inMilliseconds ~/ 10;
  final seconds = all ~/ 100;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final two = s.toString().padLeft(2, '0');
  final clock = h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$two' : '$m:$two';
  return hundredths
      ? '$clock$decimalSeparator${(all % 100).toString().padLeft(2, '0')}'
      : clock;
}
