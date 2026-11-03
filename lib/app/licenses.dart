import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the licences of the fonts and the piano recordings to the page that
/// the About dialog opens, next to the ones Flutter collects for the code
/// packages. They are read only when that page is opened.
void registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Edwin',
    ], await rootBundle.loadString('assets/fonts/OFL-Edwin.txt'));
    yield LicenseEntryWithLineBreaks([
      'Noto Music',
    ], await rootBundle.loadString('assets/fonts/OFL-NotoMusic.txt'));
    yield const LicenseEntryWithLineBreaks(
      ['Salamander Grand Piano V3'],
      'Piano recordings by Alexander Holm, released into the public domain '
      'on 4 March 2022. No licence is needed to use them.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Meatbass'],
      'Double bass recordings by Karoryfer Lecolds (a 1958 Otto Rubner '
      'double bass played by Drogomir Smolken), released under CC0 1.0: '
      'dedicated to the public domain. No licence is needed to use them.',
    );
  });
}
