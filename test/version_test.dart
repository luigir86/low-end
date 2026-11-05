import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/version.dart';

void main() {
  test('About shows the version written in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    expect(appVersion, line.substring('version:'.length).trim());
    expect(appVersionLabel, appVersion);
  });
}
