import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/brand.dart';

void main() {
  testWidgets('generated icons use the same accent as Flutter startup', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final path in [
        'web/favicon.png',
        'web/icons/apple-touch-icon.png',
        'web/icons/Icon-192.png',
        'web/icons/Icon-512.png',
        'web/icons/Icon-maskable-192.png',
        'web/icons/Icon-maskable-512.png',
        'assets/brand/logo.png',
        'design/icon-512.png',
        'store/graphics/icon-512.png',
        for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'])
          'android/app/src/main/res/mipmap-$density/ic_launcher.png',
      ]) {
        final codec = await ui.instantiateImageCodec(
          File(path).readAsBytesSync(),
        );
        final image = (await codec.getNextFrame()).image;
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        // Top centre is inside every background, above the ivory silhouette.
        final offset =
            (image.width * (image.height * .05).floor() + image.width ~/ 2) * 4;
        final actual =
            (bytes.getUint8(offset + 3) << 24) |
            (bytes.getUint8(offset) << 16) |
            (bytes.getUint8(offset + 1) << 8) |
            bytes.getUint8(offset + 2);
        expect(actual, LowEndBrand.accent.toARGB32(), reason: path);
        image.dispose();
        codec.dispose();
      }
    });
  });

  testWidgets('adaptive and themed marks fit the guaranteed circular safe area', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        for (final layer in ['foreground', 'monochrome']) {
          final codec = await ui.instantiateImageCodec(
            File(
              'android/app/src/main/res/mipmap-$density/ic_launcher_$layer.png',
            ).readAsBytesSync(),
          );
          final image = (await codec.getNextFrame()).image;
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          final side = image.width;
          var visible = 0;
          for (var y = 0; y < side; y++) {
            for (var x = 0; x < side; x++) {
              final i = (y * side + x) * 4;
              if (bytes.getUint8(i + 3) < 16) continue;
              visible++;
              final radius = math.sqrt(
                math.pow(x + .5 - side / 2, 2) + math.pow(y + .5 - side / 2, 2),
              );
              expect(
                radius,
                lessThanOrEqualTo(side * 33 / 108),
                reason: '$density/$layer clipped at $x,$y',
              );
              if (layer == 'monochrome') {
                expect(bytes.getUint8(i), 255);
                expect(bytes.getUint8(i + 1), 255);
                expect(bytes.getUint8(i + 2), 255);
              }
            }
          }
          expect(visible, greaterThan(side * side * .04));
        }
      }
    });
  });
}
