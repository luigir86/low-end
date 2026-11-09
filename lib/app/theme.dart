import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'style.dart';

/// Low End's look, in one place: change a colour, a radius or a font weight
/// here and every screen follows, like the variables of a CSS stylesheet.
///
/// The colours come from one [BrandPalette] (four colours), chosen in
/// `LowEndBrand.palette` at build time, without a user setting.
abstract final class Palette {
  // Text.
  static const inkOnLight = Color(0xFF1E1C1A);
  static const inkOnDark = Color(0xFFEFEDEA);

  static const error = Color(0xFFFF5F56);

  // Warm tuner colours against the dark dial, the same in every palette.
  static const inTune = Color(0xFFA4BF89);
  static const close = Color(0xFFDCCB79);
  static const off = Color(0xFFD98376);
}

/// Colours the Material scheme has no name for.
@immutable
class LowEndColors extends ThemeExtension<LowEndColors> {
  const LowEndColors({
    required this.activeFill,
    required this.onActiveFill,
    required this.strobeIdle,
    required this.strobeOuter,
    required this.strobeInner,
    required this.navigationBackground,
    required this.navigationIndicator,
    required this.navigationInk,
    required this.bottomNavigationBackground,
    required this.bottomNavigationInk,
    required this.bottomNavigationSelectedInk,
    required this.bottomNavigationIndicator,
    required this.bottomNavigationBorder,

    required this.inTune,
    required this.close,
    required this.off,
    required this.disc,
    required this.downbeat,
    required this.beatReceded,
    required this.beatSilent,
    required this.beatWeak,
    required this.stepFill,
    required this.onStepFill,
    this.filledSteps = false,
  });

  /// Semantic fills and ink, independent of the readable Material accent.
  final Color activeFill;
  final Color onActiveFill;
  final Color strobeIdle;
  final Color strobeOuter;
  final Color strobeInner;
  final Color navigationBackground;
  final Color navigationIndicator;
  final Color navigationInk;

  /// Bottom navigation is independent of the header and landscape rail.
  final Color bottomNavigationBackground;
  final Color bottomNavigationInk;
  final Color bottomNavigationSelectedInk;
  final Color bottomNavigationIndicator;
  final Color bottomNavigationBorder;

  /// Within a few cents.
  final Color inTune;

  /// Within 15 cents.
  final Color close;

  /// Further off.
  final Color off;

  /// The disc of every dial: under the beats, the keys and the strobe.
  final Color disc;

  /// The first beat of the bar on the metronome's ring.
  final Color downbeat;

  /// The beats not lit while the metronome plays: they recede into the
  /// disc, as the harmony's silent notes do.
  final Color beatReceded;

  /// A beat left silent (1 and 3, with the click on 2 and 4) when it comes
  /// round: it only glows, so the place in the bar is still seen.
  final Color beatSilent;

  /// The weak pulses of a group (6/8) when they come round: softer than its
  /// first.
  final Color beatWeak;

  /// Numeric adjustment buttons, independently of transport buttons, and the
  /// metronome's tempo wheel (both change the tempo).
  final Color stepFill;
  final Color onStepFill;
  final bool filledSteps;

  static LowEndColors of(BuildContext context) =>
      Theme.of(context).extension<LowEndColors>()!;

  @override
  LowEndColors copyWith({
    Color? activeFill,
    Color? onActiveFill,
    Color? strobeIdle,
    Color? strobeOuter,
    Color? strobeInner,
    Color? navigationBackground,
    Color? navigationIndicator,
    Color? navigationInk,
    Color? bottomNavigationBackground,
    Color? bottomNavigationInk,
    Color? bottomNavigationSelectedInk,
    Color? bottomNavigationIndicator,
    Color? bottomNavigationBorder,

    Color? inTune,
    Color? close,
    Color? off,
    Color? disc,
    Color? downbeat,
    Color? beatReceded,
    Color? beatSilent,
    Color? beatWeak,
    Color? stepFill,
    Color? onStepFill,
    bool? filledSteps,
  }) => LowEndColors(
    activeFill: activeFill ?? this.activeFill,
    onActiveFill: onActiveFill ?? this.onActiveFill,
    strobeIdle: strobeIdle ?? this.strobeIdle,
    strobeOuter: strobeOuter ?? this.strobeOuter,
    strobeInner: strobeInner ?? this.strobeInner,
    navigationBackground: navigationBackground ?? this.navigationBackground,
    navigationIndicator: navigationIndicator ?? this.navigationIndicator,
    navigationInk: navigationInk ?? this.navigationInk,
    bottomNavigationBackground:
        bottomNavigationBackground ?? this.bottomNavigationBackground,
    bottomNavigationInk: bottomNavigationInk ?? this.bottomNavigationInk,
    bottomNavigationSelectedInk:
        bottomNavigationSelectedInk ?? this.bottomNavigationSelectedInk,
    bottomNavigationIndicator:
        bottomNavigationIndicator ?? this.bottomNavigationIndicator,
    bottomNavigationBorder:
        bottomNavigationBorder ?? this.bottomNavigationBorder,

    inTune: inTune ?? this.inTune,
    close: close ?? this.close,
    off: off ?? this.off,
    disc: disc ?? this.disc,
    downbeat: downbeat ?? this.downbeat,
    beatReceded: beatReceded ?? this.beatReceded,
    beatSilent: beatSilent ?? this.beatSilent,
    beatWeak: beatWeak ?? this.beatWeak,
    stepFill: stepFill ?? this.stepFill,
    onStepFill: onStepFill ?? this.onStepFill,
    filledSteps: filledSteps ?? this.filledSteps,
  );

  @override
  LowEndColors lerp(LowEndColors? other, double t) {
    if (other == null) return this;
    return LowEndColors(
      activeFill: Color.lerp(activeFill, other.activeFill, t)!,
      onActiveFill: Color.lerp(onActiveFill, other.onActiveFill, t)!,
      strobeIdle: Color.lerp(strobeIdle, other.strobeIdle, t)!,
      strobeOuter: Color.lerp(strobeOuter, other.strobeOuter, t)!,
      strobeInner: Color.lerp(strobeInner, other.strobeInner, t)!,
      navigationBackground: Color.lerp(
        navigationBackground,
        other.navigationBackground,
        t,
      )!,
      navigationIndicator: Color.lerp(
        navigationIndicator,
        other.navigationIndicator,
        t,
      )!,
      navigationInk: Color.lerp(navigationInk, other.navigationInk, t)!,
      bottomNavigationBackground: Color.lerp(
        bottomNavigationBackground,
        other.bottomNavigationBackground,
        t,
      )!,
      bottomNavigationInk: Color.lerp(
        bottomNavigationInk,
        other.bottomNavigationInk,
        t,
      )!,
      bottomNavigationSelectedInk: Color.lerp(
        bottomNavigationSelectedInk,
        other.bottomNavigationSelectedInk,
        t,
      )!,
      bottomNavigationIndicator: Color.lerp(
        bottomNavigationIndicator,
        other.bottomNavigationIndicator,
        t,
      )!,
      bottomNavigationBorder: Color.lerp(
        bottomNavigationBorder,
        other.bottomNavigationBorder,
        t,
      )!,

      inTune: Color.lerp(inTune, other.inTune, t)!,
      close: Color.lerp(close, other.close, t)!,
      off: Color.lerp(off, other.off, t)!,
      disc: Color.lerp(disc, other.disc, t)!,
      downbeat: Color.lerp(downbeat, other.downbeat, t)!,
      beatReceded: Color.lerp(beatReceded, other.beatReceded, t)!,
      beatSilent: Color.lerp(beatSilent, other.beatSilent, t)!,
      beatWeak: Color.lerp(beatWeak, other.beatWeak, t)!,
      stepFill: Color.lerp(stepFill, other.stepFill, t)!,
      onStepFill: Color.lerp(onStepFill, other.onStepFill, t)!,
      filledSteps: t < 0.5 ? filledSteps : other.filledSteps,
    );
  }
}

abstract final class LowEndTheme {
  static final dark = forPalette(LowEndBrand.palette);

  static const radius = LowEndShape.radius;

  /// The neutral grey of the strobe, also used to soften the accent.
  static const _grey = Color(0xFF999999);

  /// The status bar and the navigation bar: see-through, the app drawn
  /// under them from edge to edge, light icons on the dark screen. The same on
  /// every Android version (from 15 it is the only way).
  static const systemBars = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  /// The whole theme from the four colours of [p]. Every neutral is a
  /// mixture of the dark and light colours, so a warm palette has warm greys.
  static ThemeData forPalette(BrandPalette p) {
    final accent = p.accent;
    Color shade(double amount) => Color.lerp(p.dark, p.light, amount)!;
    final ground = p.dark;
    final disc = Color.lerp(p.dark, Colors.black, 0.11)!;
    const ink = Palette.inkOnDark;
    // Borders: 3 : 1 on the disc.
    final outline = shade(0.585);
    // Soften the accent with a neutral grey (so it keeps its hue) for chord
    // tones and ordinary beats, keeping their fill visible against the dial.
    final chord = _accentInk(Color.lerp(accent, _grey, 0.3)!, disc, 3);
    final navigation = p.light;
    final onAccent = _readableOn(accent);
    return _build(
      ColorScheme(
        brightness: Brightness.dark,
        // Readable Material text; action fills use the shared accent.
        primary: ink,
        onPrimary: ground,
        primaryContainer: accent,
        onPrimaryContainer: onAccent,
        secondary: chord,
        onSecondary: _readableOn(chord),
        secondaryContainer: accent,
        onSecondaryContainer: onAccent,
        error: Palette.error,
        onError: ground,
        surface: ground,
        onSurface: ink,
        onSurfaceVariant: shade(0.74),
        surfaceContainerLowest: p.startup,
        surfaceContainerLow: shade(0.02),
        surfaceContainer: shade(0.02),
        surfaceContainerHigh: shade(0.06),
        surfaceContainerHighest: shade(0.1),
        outline: outline,
        // Keys and beats that are off.
        outlineVariant: shade(0.18),
      ),
      LowEndColors(
        stepFill: shade(0.89),
        onStepFill: ground,
        filledSteps: true,
        activeFill: accent,
        onActiveFill: onAccent,
        // The strobe stays neutral grey in every palette.
        strobeIdle: const Color(0xFF777777),
        strobeOuter: _grey,
        strobeInner: ink,
        bottomNavigationBackground: navigation,
        bottomNavigationInk: Color.lerp(navigation, p.dark, 0.875)!,
        bottomNavigationSelectedInk: _accentInk(accent, navigation),
        bottomNavigationIndicator: Colors.transparent,
        bottomNavigationBorder: accent,
        navigationBackground: accent,
        navigationIndicator: Color.lerp(
          accent,
          onAccent.computeLuminance() < 0.5 ? Colors.white : Colors.black,
          0.18,
        )!,
        navigationInk: onAccent,
        // Pitch verdicts stay bright on the disc, independently of the
        // accent used for controls and navigation.
        inTune: Palette.inTune,
        close: Palette.close,
        off: Palette.off,
        disc: disc,
        downbeat: accent,
        beatReceded: Color.lerp(disc, ground, 0.6)!,
        beatSilent: Color.alphaBlend(chord.withValues(alpha: 0.35), disc),
        beatWeak: Color.alphaBlend(chord.withValues(alpha: 0.6), disc),
      ),
    );
  }

  /// Preview another accent on the neutrals of a palette (the active one
  /// unless [on] says otherwise).
  static ThemeData withAccent(Color accent, {BrandPalette? on}) {
    final base = on ?? LowEndBrand.palette;
    return forPalette(
      BrandPalette(
        name: 'Preview',
        brand: accent,
        accent: accent,
        dark: base.dark,
        light: base.light,
      ),
    );
  }

  static ThemeData _build(ColorScheme scheme, LowEndColors colors) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      // Edwin (SIL OFL), the text font of MuseScore, bundled in assets/fonts;
      // it has the ♭ and ♯. The ♩, which it lacks, comes from Noto Music.
      fontFamily: 'Edwin',
      fontFamilyFallback: const ['NotoMusic'],
      colorScheme: scheme,
      textTheme: LowEndType.textTheme,
      // The name written on the border of a field is never under the
      // smallest size: it is drawn at three quarters of this.
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelStyle: TextStyle(fontSize: LowEndType.small / 0.75),
      ),
      scaffoldBackgroundColor: scheme.surface,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        // Otherwise a page with a title bar paints the navigation bar black.
        systemOverlayStyle: systemBars,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: Typography.material2021().black.titleLarge?.copyWith(
          fontFamily: 'Edwin',
          fontFamilyFallback: const ['NotoMusic'],
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.bottomNavigationSelectedInk
                : colors.bottomNavigationInk,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: LowEndType.small,
            color: states.contains(WidgetState.selected)
                ? colors.bottomNavigationSelectedInk
                : colors.bottomNavigationInk,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        backgroundColor: colors.bottomNavigationBackground,
        indicatorColor: colors.bottomNavigationIndicator,
        surfaceTintColor: Colors.transparent,
      ),
      // The tabs in landscape, the same destinations as the bottom
      // bar, in the same colours and text.
      navigationRailTheme: NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: colors.navigationInk),
        unselectedIconTheme: IconThemeData(color: colors.navigationInk),
        backgroundColor: colors.navigationBackground,
        indicatorColor: colors.navigationIndicator,
        minWidth: LowEndShape.railWidth,
        // The rail does not take the app's font by itself.
        selectedLabelTextStyle: TextStyle(
          fontFamily: 'Edwin',
          fontFamilyFallback: const ['NotoMusic'],
          fontSize: LowEndType.small,
          color: colors.navigationInk,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'Edwin',
          fontFamilyFallback: const ['NotoMusic'],
          fontSize: LowEndType.small,
          color: colors.navigationInk,
        ),
      ),
      // The dot on the tab of a section that is playing: the accent, not
      // the red of an error.
      badgeTheme: BadgeThemeData(
        backgroundColor: colors.activeFill,
        textColor: colors.onActiveFill,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? null
              : states.contains(WidgetState.selected)
              ? colors.activeFill
              : scheme.outline,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? null
              : states.contains(WidgetState.selected)
              ? colors.onActiveFill
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? null
              : states.contains(WidgetState.selected)
              ? colors.activeFill
              : null,
        ),
      ),
      // The menu of every list of choices (`showChoiceMenu`): round corners
      // like the buttons, on the raised surface, with no tint.
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        elevation: 3,
        menuPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          backgroundColor: colors.filledSteps ? colors.activeFill : null,
          foregroundColor: colors.filledSteps ? colors.onActiveFill : null,
        ),
      ),
      // Every outlined button alike: the ink of the text, a border that
      // reads on the disc, and both dimmed at the end of a range.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              shape: shape,
              foregroundColor: scheme.onSurface,
              disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.disabled)
                      ? scheme.outlineVariant
                      : scheme.outline,
                ),
              ),
            ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          // As high as a finger.
          minimumSize: const Size(0, 48),
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          // The choices not taken in the muted ink: the colour marks the one
          // that is.
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The dark or the light ink, whichever reads better on [background].
Color _readableOn(Color background) {
  double ratio(Color a, Color b) {
    final l1 = a.computeLuminance(), l2 = b.computeLuminance();
    final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  final ink =
      ratio(background, Palette.inkOnLight) >=
          ratio(background, Palette.inkOnDark)
      ? Palette.inkOnLight
      : Palette.inkOnDark;
  if (ratio(background, ink) >= 4.5) return ink;
  // Mid-tone accents sometimes need full black/white to meet text contrast.
  return ratio(background, Colors.black) >= ratio(background, Colors.white)
      ? Colors.black
      : Colors.white;
}

/// Keep the hue, but increase contrast for accent text on a light/dark surface.
/// Fills still use the exact chosen accent (not this accessible ink).
Color _accentInk(Color accent, Color surface, [double minimumContrast = 4.5]) {
  final target = _readableOn(surface);
  final background = surface.computeLuminance();
  for (var step = 0; step <= 100; step++) {
    final candidate = Color.lerp(accent, target, step / 100)!;
    final luminance = candidate.computeLuminance();
    final hi = luminance > background ? luminance : background;
    final lo = luminance > background ? background : luminance;
    if ((hi + 0.05) / (lo + 0.05) >= minimumContrast) return candidate;
  }
  return target;
}
