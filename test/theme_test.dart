import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/theme.dart';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('the product theme is selected by the central constant', () {
    expect(LowEndTheme.dark, same(LowEndTheme.forVariant(LowEndTheme.variant)));
  });

  test('Android and web share a variant-independent launch background', () {
    final launch = RegExp(r'#[0-9A-Fa-f]{6}')
        .firstMatch(
          File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        )![0]!
        .toUpperCase();
    expect(launch, _hex(Palette.startup));
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync());
    for (final key in ['background_color', 'theme_color']) {
      expect((manifest[key] as String).toUpperCase(), launch);
    }
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('background: ${launch.toLowerCase()}'));
    expect(
      html,
      contains('name="theme-color" content="${launch.toLowerCase()}"'),
    );
    expect(
      Directory('android/app/src/main/res/values-night').existsSync(),
      isFalse,
    );
  });

  for (final variant in LowEndThemeVariant.values) {
    group(variant.name, () {
      final theme = LowEndTheme.forVariant(variant);
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
          if (variant == LowEndThemeVariant.woodAndBrass) e.downbeat,
          e.strobeIdle,
          e.strobeOuter,
          e.strobeInner,
        ]) {
          expect(contrast(shape, e.disc), greaterThanOrEqualTo(3));
        }
        // The institutional red fill is identified by a readable border,
        // white label and bold type, rather than fill contrast alone.
        expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
        for (final verdict in [
          e.inTune,
          e.close,
          if (variant == LowEndThemeVariant.woodAndBrass) e.off,
        ]) {
          expect(contrast(verdict, e.disc), greaterThanOrEqualTo(3));
          expect(contrast(verdict, c.surface), greaterThanOrEqualTo(3));
        }
      });
      test('strobe is neutral and verdicts remain semantic', () {
        for (final color in [e.strobeIdle, e.strobeOuter]) {
          expect(color.r, color.g);
          expect(color.g, color.b);
        }
        if (variant == LowEndThemeVariant.woodAndBrass) {
          expect(e.inTune, Palette.inTune);
          expect(e.close, Palette.close);
          expect(e.off, Palette.off);
        } else {
          expect(e.off, e.activeFill);
          expect(e.downbeat, e.activeFill);
          expect(contrast(c.outline, e.disc), greaterThanOrEqualTo(3));
          expect(contrast(e.onActiveFill, e.off), greaterThanOrEqualTo(4.5));
          expect(contrast(e.onStepFill, e.stepFill), greaterThanOrEqualTo(4.5));
          expect(e.filledSteps, isTrue);
          expect(e.inTune, const Color(0xFF8FA891));
          expect(e.close, const Color(0xFFC5A35A));
        }
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
        final other = LowEndTheme.forVariant(
          variant == LowEndThemeVariant.woodAndBrass
              ? LowEndThemeVariant.anthraciteAndRed
              : LowEndThemeVariant.woodAndBrass,
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

  test('Wood&Brass preserves the legacy ground and accent', () {
    final c = LowEndTheme.forVariant(LowEndThemeVariant.woodAndBrass)
        .colorScheme;
    expect(c.primary, Palette.bronze);
    expect(c.surface, Palette.ebony);
    for (final verdict in [Palette.inTune, Palette.close, Palette.off]) {
      final delta =
          (HSLColor.fromColor(verdict).hue - HSLColor.fromColor(c.primary).hue)
              .abs();
      expect(math.min(delta, 360 - delta), greaterThanOrEqualTo(20));
    }
  });

  test('Anthracite & Red uses FFM red for fills and navigation', () {
    final theme = LowEndTheme.forVariant(LowEndThemeVariant.anthraciteAndRed);
    final c = theme.colorScheme;
    final e = theme.extension<LowEndColors>()!;
    expect(_hex(c.primaryContainer), '#A6282C');
    expect(e.activeFill, c.primaryContainer);
    expect(theme.navigationBarTheme.backgroundColor, e.navigationBackground);
    expect(theme.navigationRailTheme.backgroundColor, e.navigationBackground);
    expect(_hex(e.navigationBackground), '#A6282C');
  });
}
