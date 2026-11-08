// Rebuild every brand surface from the approved drawing (not a new drawing).
// flutter test tool/make_icons_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/brand.dart';

Future<void> _save(String path, ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<ui.Image> _render(int size, void Function(Canvas, double) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder), size.toDouble());
  return recorder.endRecording().toImage(size, size);
}

// The large approved icon, excluding its red tile and the phone mockup.
// Green separates ivory (~245) from red (~35). Unmix edge coverage; flatten
// the mockup's lighting to one ink, the palette's mark colour. No flip, rotation or reshaping.
Future<ui.Image> _master() async {
  final codec = await ui.instantiateImageCodec(
    File('docs/images/lion-brand-approved.png').readAsBytesSync(),
  );
  final source = (await codec.getNextFrame()).image;
  expect((source.width, source.height), (1536, 1024));
  final bytes = (await source.toByteData())!;
  const left = 292, top = 116, width = 350, height = 532;
  final rgba = Uint8List(width * height * 4);
  final ink = LowEndBrand.palette.mark;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final green = bytes.getUint8(
        ((top + y) * source.width + left + x) * 4 + 1,
      );
      final alpha = ((green - 40) / 202).clamp(0.0, 1.0);
      final i = (y * width + x) * 4;
      rgba[i] = (ink.r * 255).round();
      rgba[i + 1] = (ink.g * 255).round();
      rgba[i + 2] = (ink.b * 255).round();
      rgba[i + 3] = (alpha * 255).round();
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final result = await descriptor.instantiateCodec();
  return (await result.getNextFrame()).image;
}

void _lion(
  Canvas c,
  ui.Image master,
  double size,
  double fill, {
  bool monochrome = false,
}) {
  final h = size * fill;
  final w = h * master.width / master.height;
  c.drawImageRect(
    master,
    Rect.fromLTWH(0, 0, master.width.toDouble(), master.height.toDouble()),
    Rect.fromCenter(center: Offset(size / 2, size / 2), width: w, height: h),
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = (monochrome
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : null),
  );
}

// Native and pre-Flutter surfaces cannot read Dart at runtime. Generate them
// from the same constant as the UI, alongside the raster icon variants.
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void _writeBrandColors() {
  final hex = _hex(LowEndBrand.palette.brand);
  final startup = _hex(LowEndBrand.palette.startup);
  const res = 'android/app/src/main/res/values';
  for (final (file: name, colour: role, value: value) in [
    (file: 'colors.xml', colour: 'launch_background', value: hex),
    (file: 'colors.xml', colour: 'app_background', value: startup),
    (
      file: 'ic_launcher_background.xml',
      colour: 'ic_launcher_background',
      value: hex,
    ),
  ]) {
    final file = File('$res/$name');
    final source = file.readAsStringSync();
    final colour = RegExp('(<color name="$role">)#[0-9A-Fa-f]{6}(</color>)');
    if (!colour.hasMatch(source)) {
      throw StateError('Missing $role in ${file.path}');
    }
    file.writeAsStringSync(
      source.replaceFirstMapped(
        colour,
        (match) => '${match[1]}$value${match[2]}',
      ),
    );
  }
  final html = File('web/index.html');
  final source = html.readAsStringSync();
  final background = RegExp(
    r'(html, body \{ margin: 0; height: 100%; background: )#[0-9A-Fa-f]{6}',
  );
  if (!background.hasMatch(source)) {
    throw StateError('Missing pre-Flutter background in web/index.html');
  }
  final themeColour = RegExp(
    r'(<meta name="theme-color" content=")#[0-9A-Fa-f]{6}',
  );
  if (!themeColour.hasMatch(source)) {
    throw StateError('Missing theme-color in web/index.html');
  }
  html.writeAsStringSync(
    source
        .replaceFirstMapped(background, (match) => '${match[1]}$hex')
        .replaceFirstMapped(themeColour, (match) => '${match[1]}$startup'),
  );
  final manifest = File('web/manifest.json');
  final json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
  json['background_color'] = hex;
  json['theme_color'] = startup;
  manifest.writeAsStringSync(
    '${const JsonEncoder.withIndent('    ').convert(json)}\n',
  );
}

void main() {
  testWidgets(
    'generate the approved lion across launcher, splash, web and store',
    (tester) async {
      await tester.runAsync(() async {
        _writeBrandColors();
        final master = await _master();
        await _save('design/lion-mark.png', master);
        const res = 'android/app/src/main/res';
        const densities = {
          'mdpi': (48, 108),
          'hdpi': (72, 162),
          'xhdpi': (96, 216),
          'xxhdpi': (144, 324),
          'xxxhdpi': (192, 432),
        };
        for (final e in densities.entries) {
          final (icon, layer) = e.value;
          await _save(
            '$res/mipmap-${e.key}/ic_launcher.png',
            await _render(icon, (c, s) {
              c.clipRRect(
                RRect.fromRectAndRadius(
                  Offset.zero & Size(s, s),
                  Radius.circular(s * .22),
                ),
              );
              c.drawColor(LowEndBrand.palette.brand, BlendMode.src);
              _lion(c, master, s, .80);
            }),
          );
          for (final mono in [false, true]) {
            await _save(
              '$res/mipmap-${e.key}/ic_launcher_${mono ? 'monochrome' : 'foreground'}.png',
              await _render(
                layer,
                (c, s) => _lion(c, master, s, .50, monochrome: mono),
              ),
            );
          }
          // No icon background circle: Android 12+ supplies its own accent window.
          await _save(
            '$res/drawable-${e.key}/brand_splash.png',
            await _render(
              layer * 288 ~/ 108,
              (c, s) => _lion(c, master, s, .50),
            ),
          );
        }
        for (final size in [32, 180, 192, 512]) {
          final path = switch (size) {
            32 => 'web/favicon.png',
            180 => 'web/icons/apple-touch-icon.png',
            _ => 'web/icons/Icon-$size.png',
          };
          await _save(
            path,
            await _render(size, (c, s) {
              c.drawColor(LowEndBrand.palette.brand, BlendMode.src);
              _lion(c, master, s, .80);
            }),
          );
        }
        for (final size in [192, 512]) {
          await _save(
            'web/icons/Icon-maskable-$size.png',
            await _render(size, (c, s) {
              c.drawColor(LowEndBrand.palette.brand, BlendMode.src);
              _lion(c, master, s, .60);
            }),
          );
        }
        await _save(
          'assets/brand/mark.png',
          await _render(864, (c, s) => _lion(c, master, s, .50)),
        );
        File('assets/brand/mark.png').copySync('web/brand-mark.png');
        await _save(
          'assets/brand/logo.png',
          await _render(192, (c, s) {
            c.clipRRect(
              RRect.fromRectAndRadius(
                Offset.zero & Size(s, s),
                Radius.circular(s * .22),
              ),
            );
            c.drawColor(LowEndBrand.palette.brand, BlendMode.src);
            _lion(c, master, s, .80);
          }),
        );
        File('web/icons/Icon-512.png').copySync('design/icon-512.png');
        File('design/icon-512.png').copySync('store/graphics/icon-512.png');
        // Review true outputs under launcher masks and at small size.
        await _save(
          'docs/images/lion-brand-production.png',
          await _render(1024, (c, s) {
            c.drawColor(LowEndBrand.palette.startup, BlendMode.src);
            for (var i = 0; i < 3; i++) {
              c.save();
              c.translate(40.0 + i * 330, 40);
              if (i == 0) {
                c.clipPath(
                  Path()..addOval(const Rect.fromLTWH(0, 0, 288, 288)),
                );
              }
              if (i == 1) {
                c.clipRRect(
                  RRect.fromRectAndRadius(
                    const Rect.fromLTWH(0, 0, 288, 288),
                    const Radius.circular(64),
                  ),
                );
              }
              c.drawRect(
                const Rect.fromLTWH(0, 0, 288, 288),
                Paint()..color = LowEndBrand.palette.brand,
              );
              _lion(c, master, 288, i == 0 ? .60 : .80);
              c.restore();
            }
            c.save();
            c.translate(320, 400);
            c.drawRect(
              const Rect.fromLTWH(0, 0, 384, 560),
              Paint()..color = LowEndBrand.palette.brand,
            );
            c.translate(48, 136);
            _lion(c, master, 288, .50);
            c.restore();
            c.save();
            c.translate(60, 450);
            c.drawRect(
              const Rect.fromLTWH(0, 0, 48, 48),
              Paint()..color = LowEndBrand.palette.brand,
            );
            _lion(c, master, 48, .80);
            c.restore();
          }),
        );
      });
    },
  );
}
