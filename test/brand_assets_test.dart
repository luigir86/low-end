import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
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
