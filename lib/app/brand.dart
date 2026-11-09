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
    this.step,
    this.tint,
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

  /// The −/+ buttons and the metronome's wheel, when a palette keeps its
  /// own; otherwise the light colour dimmed a little towards the dark one.
  final Color? step;

  /// The colour the greys (borders, dark fills, the strobe at rest, muted
  /// text) are mixed towards from [dark], when a palette keeps its own;
  /// otherwise [light].
  final Color? tint;

  /// The surface before Flutter draws (Android window, browser chrome).
  Color get startup => Color.lerp(dark, Colors.black, 0.33)!;

  /// The soft accent glow behind the lion on the icon and the store
  /// graphic: [glow] at its centre, [glowMid] halfway, [brand] at the edge.
  Color get glow => Color.lerp(brand, accent, 0.16)!;
  Color get glowMid => Color.lerp(brand, accent, 0.06)!;
}

/// The palettes of the app, chosen in one place: [palette]. After changing
/// it, run `flutter test tool/make_icons_test.dart` before a local build. CI
/// runs it automatically, including the Pages publication.
abstract final class LowEndBrand {
  static const ffmRed = Color(0xFFA6282C);
  static const bronze = Color(0xFFD4A373);

  /// A touch warmer than a neutral black (9 November 2026, was #141312).
  static const ebony = Color(0xFF18140F);
  static const ivory = Color(0xFFF1E8D5);

  /// Ivory with 15% of bronze (9 November 2026): warm on the ebony, where
  /// ivory dimmed towards it looked grey, and less glaring than ivory.
  static const warmIvory = Color(0xFFEDDEC6);

  /// Ivory with 40% of bronze: the greys of Ebony & Bronze lean to it, so
  /// borders and dark fills read as wood and sand rather than grey.
  static const sand = Color(0xFFE3C9A6);

  /// The theme of 7 November 2026: FFM red on anthracite.
  static const red = BrandPalette(
    name: 'Red',
    brand: ffmRed,
    accent: ffmRed,
    dark: Color(0xFF242424),
    light: Color(0xFFECECE9),
    mark: Color(0xFFFFF5E3),
  );

  /// Ebony & Bronze (8 November 2026): bronze on ebony, ivory light surfaces.
  static const ebonyAndBronze = BrandPalette(
    name: 'Ebony & Bronze',
    brand: ebony,
    accent: bronze,
    dark: ebony,
    light: ivory,
    mark: warmIvory,
    step: warmIvory,
    tint: sand,
  );

  static const palettes = [red, ebonyAndBronze];

  /// The one place that chooses the theme, the icon and the startup.
  static const palette = ebonyAndBronze;

  static Color get accent => palette.accent;

  static const mark = 'assets/brand/mark.png';
  static const splashExtent = 288.0;
  static const transition = Duration(milliseconds: 180);
}
