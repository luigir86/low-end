import 'package:flutter/material.dart';

/// The four colours a theme is made of. Every other shade (surfaces,
/// borders, controls that are off, readable variants of the accent) is
/// derived from them in `lib/app/theme.dart`. The tuner's verdict colours
/// and the neutral strobe stay independent of any palette.
@immutable
final class BrandPalette {
  const BrandPalette({
    required this.name,
    required this.brand,
    required this.accent,
    required this.dark,
    required this.light,
    Color? mark,
  }) : mark = mark ?? light;

  final String name;

  /// The launcher icon and every startup surface (Android, web, Flutter).
  final Color brand;

  /// Active fills: TAP, selections, the first beat, the landscape rail.
  final Color accent;

  /// The ground of every screen; the dial's disc is a little darker.
  final Color dark;

  /// The bottom bar and the numeric +/− buttons.
  final Color light;

  /// The lion; the light colour unless a palette keeps its own.
  final Color mark;

  /// The surface before Flutter draws (Android window, browser chrome).
  Color get startup => Color.lerp(dark, Colors.black, 0.33)!;
}

/// The palettes of the app, chosen in one place: [palette]. After changing
/// it, run `flutter test tool/make_icons_test.dart` before a local build. CI
/// runs it automatically, including the Pages publication.
abstract final class LowEndBrand {
  static const ffmRed = Color(0xFFA6282C);
  static const brass = Color(0xFFB8924E);
  static const ebony = Color(0xFF141312);
  static const ivory = Color(0xFFF1E8D5);

  /// The theme of 7 November 2026: FFM red on anthracite.
  static const red = BrandPalette(
    name: 'Red',
    brand: ffmRed,
    accent: ffmRed,
    dark: Color(0xFF242424),
    light: Color(0xFFECECE9),
    mark: Color(0xFFFFF5E3),
  );

  /// Ebony & Brass (8 November 2026): brass on ebony, ivory light surfaces.
  static const ebonyAndBrass = BrandPalette(
    name: 'Ebony & Brass',
    brand: ebony,
    accent: brass,
    dark: ebony,
    light: ivory,
  );

  static const palettes = [red, ebonyAndBrass];

  /// The one place that chooses the theme, the icon and the startup.
  static const palette = ebonyAndBrass;

  static Color get accent => palette.accent;

  static const mark = 'assets/brand/mark.png';
  static const splashExtent = 288.0;
  static const transition = Duration(milliseconds: 180);
}
