import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/brand.dart';
import 'package:low_end/app/style.dart';
import 'package:low_end/app/theme.dart';

void main() {
  test('no text in the theme is smaller than the style sheet allows', () {
    for (final theme in LowEndBrand.palettes.map(LowEndTheme.forPalette)) {
      final t = theme.textTheme;
      for (final style in [
        t.displayMedium,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ]) {
        expect(style!.fontSize, greaterThanOrEqualTo(LowEndType.small));
      }
    }
  });

  test('the sizes of the style sheet are in descending order', () {
    const sizes = [
      LowEndType.display,
      LowEndType.headline,
      LowEndType.title,
      LowEndType.body,
      LowEndType.caption,
      LowEndType.small,
    ];
    for (var i = 1; i < sizes.length; i++) {
      expect(sizes[i], lessThan(sizes[i - 1]));
    }
  });

  test('font sizes are only written in style.dart', () {
    // Every size comes from the text theme, so that the screens stay
    // uniform: see docs/style.md.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(String.fromCharCode(92), '/');
      if (path.endsWith('lib/app/style.dart') || path.contains('/l10n/')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'fontSize\s*:\s*\d').hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
