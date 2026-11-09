// Draws the Google Play feature graphics (1024 x 500), one per language,
// from the active palette (LowEndBrand.palette): the lion mark of the app
// icon on the left, "Low End" in the accent and a line under it in the light
// colour, in Edwin, the app's own font, over the dark colour with a soft
// glow behind the lion. Run it again when the palette or the text changes:
//   flutter test tool/feature_graphic_text_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/brand.dart';

const _tagline = {
  'en-US': 'Piano chords to play over, with metronome, tuner and a player for your tracks.',
  'it-IT': 'Accordi al piano su cui suonare, con metronomo, accordatore e lettore di brani.',
  'es-ES': 'Acordes de piano sobre los que tocar, con metrónomo, afinador y reproductor.',
  'fr-FR': 'Des accords au piano pour jouer dessus, avec métronome, accordeur et lecteur.',
};

void main() {
  testWidgets('draw the feature graphics', (tester) async {
    final loader = FontLoader('Edwin')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Edwin-Roman.otf').readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
    final palette = LowEndBrand.palette;
    await tester.runAsync(() async {
      final mark = (await (await ui.instantiateImageCodec(
        File(LowEndBrand.mark).readAsBytesSync(),
      )).getNextFrame()).image;
      for (final locale in _tagline.keys) {
        const w = 1024, h = 500;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 1024, 500),
          ui.Paint()..color = palette.dark,
        );
        // A soft glow of the accent behind the lion.
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 1024, 500),
          ui.Paint()
            ..shader = ui.Gradient.radial(
              const ui.Offset(260, 250),
              520,
              [
                ui.Color.lerp(palette.dark, palette.accent, 0.16)!,
                ui.Color.lerp(palette.dark, palette.accent, 0.06)!,
                palette.dark,
              ],
              [0, 0.55, 1],
            ),
        );
        const side = 640.0;
        canvas.drawImageRect(
          mark,
          ui.Rect.fromLTWH(0, 0, mark.width.toDouble(), mark.height.toDouble()),
          const ui.Rect.fromLTWH(260 - side / 2, 250 - side / 2, side, side),
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );

        ui.Paragraph paragraph(
          String text,
          double size,
          ui.Color color,
          double height,
        ) {
          final builder =
              ui.ParagraphBuilder(
                  ui.ParagraphStyle(fontFamily: 'Edwin', height: height),
                )
                ..pushStyle(
                  ui.TextStyle(
                    fontFamily: 'Edwin',
                    fontSize: size,
                    color: color,
                  ),
                )
                ..addText(text);
          return builder.build()
            ..layout(const ui.ParagraphConstraints(width: 450));
        }

        final title = paragraph('Low End', 92, palette.accent, 1.0);
        final line = paragraph(_tagline[locale]!, 34, palette.light, 1.25);
        const gap = 18.0;
        final top = (h - (title.height + gap + line.height)) / 2;
        canvas.drawParagraph(title, ui.Offset(520, top));
        canvas.drawParagraph(line, ui.Offset(520, top + title.height + gap));

        final result = await recorder.endRecording().toImage(w, h);
        final png = await result.toByteData(format: ui.ImageByteFormat.png);
        File('store/graphics/$locale/feature-graphic-1024x500.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  });
}
