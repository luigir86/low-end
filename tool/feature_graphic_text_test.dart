// Sets the title and the line under it of the feature graphics in Edwin,
// the app's own font, over the same ebony and glow as the picture. It wipes
// the old text (right of the lion) and writes it again, so it can be run as
// often as the text changes.
//   flutter test tool/feature_graphic_text_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _ebony = [0x1B, 0x14, 0x11];
const _glow = [0x2B, 0x1D, 0x16]; // Palette.walnutDeep
const _cx = 285.0, _cy = 240.0, _radius = 330.0;

/// Everything right of this x is text.
const _textLeft = 480;

const _tagline = {
  'en-US':
      'Piano chords and progressions to play over, with metronome and tuner.',
  'it-IT': 'Accordi e progressioni al piano su cui suonare, con metronomo e accordatore.',
};

void main() {
  testWidgets('write the feature graphic text in Edwin', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Edwin');
    for (final file in ['Edwin-Roman.otf']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
    await tester.runAsync(() async {
      for (final locale in ['en-US', 'it-IT']) {
        final path = 'store/graphics/$locale/feature-graphic-1024x500.png';
        final codec = await ui.instantiateImageCodec(
          File(path).readAsBytesSync(),
        );
        final image = (await codec.getNextFrame()).image;
        final w = image.width, h = image.height;
        final data = (await image.toByteData())!;
        final out = Uint8List(w * h * 4);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final i = (y * w + x) * 4;
            if (x >= _textLeft) {
              final dx = x - _cx, dy = (y - _cy) * 1.1;
              final d = (dx * dx + dy * dy) / (_radius * _radius);
              final k = d >= 1 ? 0.0 : (1 - d) * (1 - d);
              for (var c = 0; c < 3; c++) {
                out[i + c] = (_ebony[c] + (_glow[c] - _ebony[c]) * k).round();
              }
              out[i + 3] = 255;
            } else {
              for (var c = 0; c < 4; c++) {
                out[i + c] = data.getUint8(i + c);
              }
            }
          }
        }
        final buffer = await ui.ImmutableBuffer.fromUint8List(out);
        final wiped = await (await ui.ImageDescriptor.raw(
          buffer,
          width: w,
          height: h,
          pixelFormat: ui.PixelFormat.rgba8888,
        ).instantiateCodec()).getNextFrame();

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImage(wiped.image, ui.Offset.zero, ui.Paint());

        ui.Paragraph paragraph(
          String text,
          double size,
          ui.FontWeight weight,
          ui.Color color,
          double width,
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
                    fontWeight: weight,
                    color: color,
                  ),
                )
                ..addText(text);
          return builder.build()..layout(ui.ParagraphConstraints(width: width));
        }

        final title = paragraph(
          'Low End',
          92,
          ui.FontWeight.w400,
          const ui.Color(0xFFE2BFA9), // Palette.mochaLight
          440,
          1.0,
        );
        final line = paragraph(
          _tagline[locale]!,
          36,
          ui.FontWeight.w400,
          const ui.Color(0xFFF1E6DD), // Palette.inkOnDark
          440,
          1.25,
        );
        const gap = 18.0;
        final top = (h - (title.height + gap + line.height)) / 2;
        canvas.drawParagraph(title, ui.Offset(528, top));
        canvas.drawParagraph(line, ui.Offset(528, top + title.height + gap));

        final result = await recorder.endRecording().toImage(w, h);
        final png = await result.toByteData(format: ui.ImageByteFormat.png);
        File(path).writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  });
}
