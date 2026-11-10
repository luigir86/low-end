import '../l10n/app_localizations.dart';

/// [value] with [digits] decimals and the decimal mark of the app language:
/// a comma in Italian, Spanish and French, a point in English. The Player
/// does the same for its clock.
String decimalText(AppLocalizations l10n, double value, [int digits = 1]) {
  final text = value.toStringAsFixed(digits);
  return l10n.localeName == 'en' ? text : text.replaceFirst('.', ',');
}
