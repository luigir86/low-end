import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// The name a take starts with, in the app's language: the take's number
/// that day and the date, such as Take1_9_nov_2026 (Toma1_9_nov_2026 in
/// Spanish, Prise1_9_nov_2026 in French). It can be changed before the take
/// is shared or saved.
String takeName(AppLocalizations strings, int number, DateTime day) {
  String month;
  try {
    month = DateFormat.MMM(strings.localeName).format(day);
  } catch (_) {
    // The month names of the language are not loaded (some tests).
    month = DateFormat.MMM('en').format(day);
  }
  month = month.toLowerCase().replaceAll('.', '').replaceAll(' ', '');
  return strings.takeFileName(number, '${day.day}_${month}_${day.year}');
}

/// The longest name a take may have, without its extension.
const maxTakeNameLength = 80;

/// [name] made safe for a file: no characters that phones or computers
/// refuse in a file name, no spaces at the ends, at most
/// [maxTakeNameLength] characters. Empty when nothing usable is left.
String cleanTakeName(String name) {
  var clean = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .trim()
      .replaceAll(RegExp(r'^\.+'), '');
  if (clean.length > maxTakeNameLength) {
    clean = clean.substring(0, maxTakeNameLength).trimRight();
  }
  return clean;
}
