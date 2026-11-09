import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/theme.dart';
import 'package:low_end/app/brand.dart';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('the product theme is built from the central palette', () {
    final active = LowEndTheme.forPalette(LowEndBrand.palette).colorScheme;
    expect(LowEndTheme.dark.colorScheme, active);
    expect(LowEndBrand.palettes, contains(LowEndBrand.palette));
  });

  test('the red palette keeps the anthracite theme of 7 November', () {
    final theme = LowEndTheme.forPalette(LowEndBrand.red);
    final c = theme.colorScheme;
    final e = theme.extension<LowEndColors>()!;
    expect(_hex(c.surface), '#242424');
    expect(_hex(e.disc), '#202020');
    expect(_hex(c.surfaceContainerHigh), '#303030');
    expect(_hex(LowEndBrand.red.startup), '#181818');
    // Since 9 November the tabs sit on the ground in every palette.
    expect(e.bottomNavigationBackground, c.surface);
    expect(e.activeFill, LowEndBrand.ffmRed);
  });

  test('Ebony & Bronze uses the four approved colours', () {
    const p = LowEndBrand.ebonyAndBronze;
    expect(_hex(p.brand), '#141312');
    expect(_hex(p.accent), '#D4A373');
    expect(_hex(p.dark), '#141312');
    expect(_hex(p.light), '#F1E8D5');
    expect(p.mark, p.light);
    final theme = LowEndTheme.forPalette(p);
    final e = theme.extension<LowEndColors>()!;
    expect(theme.colorScheme.surface, p.dark);
    // Ebony ink on bronze buttons; the tabs on ebony, the open one ivory.
    expect(e.bottomNavigationBackground, p.dark);
    expect(e.onActiveFill, Palette.inkOnLight);
    expect(contrast(e.onActiveFill, p.accent), greaterThanOrEqualTo(4.5));
    expect(e.bottomNavigationSelectedInk, p.light);
    expect(
      contrast(e.bottomNavigationSelectedInk, p.dark),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('Android and web share a variant-independent launch background', () {
    final launch = RegExp(r'#[0-9A-Fa-f]{6}')
        .firstMatch(
          File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        )![0]!
        .toUpperCase();
    expect(launch, _hex(LowEndBrand.palette.brand));
    expect(
      File('android/app/src/main/res/values/ic_launcher_background.xml')
          .readAsStringSync(),
      contains(launch),
    );
    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains(
        '<color name="app_background">${_hex(LowEndBrand.palette.startup)}</color>',
      ),
    );
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync());
    expect((manifest['background_color'] as String).toUpperCase(), launch);
    expect(
      (manifest['theme_color'] as String).toUpperCase(),
      _hex(LowEndBrand.palette.startup),
    );
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('background: $launch'));
    expect(
      html,
      contains(
        'name="theme-color" content="${_hex(LowEndBrand.palette.startup)}"',
      ),
    );
    expect(
      Directory('android/app/src/main/res/values-night').existsSync(),
      isFalse,
    );
  });

  for (final palette in LowEndBrand.palettes) {
    group(palette.name, () {
      final theme = LowEndTheme.forPalette(palette);
      final c = theme.colorScheme;
      final e = theme.extension<LowEndColors>()!;
      test('text and informative shapes retain WCAG contrast', () {
        for (final surface in [
          c.surface,
          c.surfaceContainerHigh,
          c.surfaceContainerHighest,
        ]) {
          expect(contrast(c.primary, surface), greaterThanOrEqualTo(4.5));
          expect(contrast(c.onSurface, surface), greaterThanOrEqualTo(4.5));
          expect(
            contrast(c.onSurfaceVariant, surface),
            greaterThanOrEqualTo(4.5),
          );
        }
        for (final pair in [
          (c.onPrimary, c.primary),
          (c.onSecondary, c.secondary),
          (c.onPrimaryContainer, c.primaryContainer),
          (c.onSecondaryContainer, c.secondaryContainer),
          (e.onActiveFill, e.activeFill),
          (e.navigationInk, e.navigationBackground),
          (e.navigationInk, e.navigationIndicator),
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
        for (final shape in [
          c.outline,
          c.secondary,
          e.strobeIdle,
          e.strobeOuter,
          e.strobeInner,
        ]) {
          expect(contrast(shape, e.disc), greaterThanOrEqualTo(3));
        }
        // The institutional red fill is identified by a readable border,
        // white label and bold type, rather than fill contrast alone.
        expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
        for (final verdict in [e.inTune, e.close, e.off]) {
          expect(contrast(verdict, e.disc), greaterThanOrEqualTo(3));
          expect(contrast(verdict, c.surface), greaterThanOrEqualTo(3));
        }
      });
      test('idle strobe is neutral and verdicts remain semantic', () {
        for (final color in [e.strobeIdle, e.strobeOuter]) {
          expect(color.r, color.g);
          expect(color.g, color.b);
        }
        expect(e.inTune, Palette.inTune);
        expect(e.close, Palette.close);
        expect(e.off, Palette.off);
        expect(e.off, isNot(e.activeFill));
        expect(e.downbeat, e.activeFill);
        expect(contrast(c.outline, e.disc), greaterThanOrEqualTo(3));
        expect(contrast(e.onStepFill, e.stepFill), greaterThanOrEqualTo(4.5));
        expect(e.filledSteps, isTrue);
        expect(e.strobeInner, isNot(e.off));
      });
      test('extension copies and interpolates all semantic roles', () {
        List<Color> roles(LowEndColors x) => [
          x.activeFill,
          x.onActiveFill,
          x.strobeIdle,
          x.strobeOuter,
          x.strobeInner,
          x.navigationBackground,
          x.navigationIndicator,
          x.navigationInk,
          x.bottomNavigationBackground,
          x.bottomNavigationInk,
          x.bottomNavigationSelectedInk,
          x.bottomNavigationIndicator,
          x.bottomNavigationBorder,

          x.inTune,
          x.close,
          x.off,
          x.disc,
          x.downbeat,
          x.beatReceded,
          x.beatSilent,
          x.beatWeak,
          x.stepFill,
          x.onStepFill,
        ];
        expect(roles(e.copyWith()), roles(e));
        expect(e.copyWith().filledSteps, e.filledSteps);
        final other = LowEndTheme.forPalette(
          palette == LowEndBrand.red
              ? LowEndBrand.ebonyAndBronze
              : LowEndBrand.red,
        ).extension<LowEndColors>()!;
        expect(roles(e.lerp(other, 0)), roles(e));
        expect(roles(e.lerp(other, 1)), roles(other));
        final mid = roles(e.lerp(other, 0.5));
        for (var i = 0; i < mid.length; i++) {
          expect(mid[i], Color.lerp(roles(e)[i], roles(other)[i], 0.5));
        }
      });
    });
  }

  test(
    'the current accent colours the frame with readable tabs on the ground',
    () {
      final theme = LowEndTheme.dark;
      final c = theme.colorScheme;
      final e = theme.extension<LowEndColors>()!;
      expect(c.primaryContainer, LowEndBrand.accent);
      expect(e.activeFill, c.primaryContainer);
      expect(
        theme.navigationBarTheme.backgroundColor,
        e.bottomNavigationBackground,
      );
      expect(e.bottomNavigationBorder, e.activeFill);
      // No pill: the open tab is the light colour, clearly brighter than
      // the others (and its icon is filled).
      expect(e.bottomNavigationIndicator, Colors.transparent);
      expect(
        contrast(e.bottomNavigationSelectedInk, e.bottomNavigationBackground),
        greaterThan(
          2 * contrast(e.bottomNavigationInk, e.bottomNavigationBackground),
        ),
      );
      expect(
        contrast(e.bottomNavigationSelectedInk, e.bottomNavigationBackground),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(e.bottomNavigationInk, e.bottomNavigationBackground),
        greaterThanOrEqualTo(4.5),
      );
      // The rail in landscape is the same ground as the bottom bar; the
      // top of the screen is the ground too, no accent band.
      expect(
        theme.navigationRailTheme.backgroundColor,
        e.bottomNavigationBackground,
      );
      expect(e.navigationBackground, theme.colorScheme.surface);
    },
  );

  for (final accent in [
    LowEndBrand.ffmRed,
    LowEndBrand.bronze,
    const Color(0xFFB97858),
    const Color(0xFF438C87),
    const Color(0xFF608DB4),
    const Color(0xFF987493),
  ]) {
    test('accent ${_hex(accent)} preserves neutrals and readable controls', () {
      // On the neutral anthracite, where a hue shift would show.
      final theme = LowEndTheme.withAccent(accent, on: LowEndBrand.red);
      final c = theme.colorScheme;
      final e = theme.extension<LowEndColors>()!;
      final red = LowEndTheme.forPalette(LowEndBrand.red);
      final base = red.colorScheme;
      expect(c.surface, base.surface);
      expect(c.surfaceContainerHighest, base.surfaceContainerHighest);
      expect(c.outline, base.outline);
      expect(e.stepFill, red.extension<LowEndColors>()!.stepFill);
      expect(e.activeFill, accent);
      expect(e.downbeat, accent);
      for (final shade in [c.secondary, e.beatWeak, e.beatSilent]) {
        final hsl = HSLColor.fromColor(shade);
        expect(hsl.saturation, greaterThan(0.05));
        final delta = (hsl.hue - HSLColor.fromColor(accent).hue).abs();
        expect(math.min(delta, 360 - delta), lessThan(5));
      }
      expect(c.secondary, isNot(accent));
      expect(contrast(c.secondary, e.disc), greaterThanOrEqualTo(3));
      expect(c.primaryContainer, accent);
      expect(e.navigationBackground, c.surface);
      expect(e.bottomNavigationBorder, accent);
      expect(theme.badgeTheme.backgroundColor, accent);
      for (final pair in [
        (e.onActiveFill, accent),
        (c.onSecondary, c.secondary),
        (c.onPrimaryContainer, accent),
        (e.navigationInk, e.navigationIndicator),
        (e.bottomNavigationSelectedInk, e.bottomNavigationBackground),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      expect(e.off, Palette.off);
      expect(e.close, Palette.close);
      expect(e.inTune, Palette.inTune);
    });
  }

  test('Ebony & Bronze keeps a warm ivory on -/+ and the wheel', () {
    final e = LowEndTheme.forPalette(LowEndBrand.ebonyAndBronze)
        .extension<LowEndColors>()!;
    expect(_hex(e.stepFill), '#EDDEC6');
    expect(contrast(e.onStepFill, e.stepFill), greaterThanOrEqualTo(7));
  });

  test('bronze and FFM red keep their values and choose readable ink', () {
    expect(_hex(LowEndBrand.ffmRed), '#A6282C');
    expect(_hex(LowEndBrand.bronze), '#D4A373');
    final bronze = LowEndTheme.withAccent(LowEndBrand.bronze)
        .extension<LowEndColors>()!;
    expect(bronze.onActiveFill, Palette.inkOnLight);
    final red = LowEndTheme.withAccent(LowEndBrand.ffmRed)
        .extension<LowEndColors>()!;
    expect(red.onActiveFill, Palette.inkOnDark);
  });
}
