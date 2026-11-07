import 'package:flutter/material.dart';

/// The style sheet of Low End: the few sizes the screens are made from.
///
/// Colours live in `theme.dart` ([Palette]); the written version of all of
/// it, with where each size is used, is `docs/style.md`. A test
/// (`style_test.dart`) keeps font sizes from being written anywhere else,
/// so a new screen picks one of these instead of inventing a size.
abstract final class LowEndType {
  /// The value in the middle of every dial: the note, the tempo.
  static const display = 45.0;

  /// The verdict under the note on the tuner.
  static const headline = 24.0;

  /// A value on a control: the time signature, TAP.
  static const title = 22.0;

  /// Names of notes and chords on the keys, the chord on the dial, titles.
  static const body = 16.0;

  /// Hints and captions: "Tap to start", "Play a note", the labels of the
  /// settings.
  static const caption = 14.0;

  /// The smallest text anywhere: names under icons, the label of a button.
  /// Nothing is set smaller, whatever the screen.
  static const small = 13.0;

  /// The octave next to a note name, as a fraction of the note's size.
  static const octaveScale = 0.4;

  /// The sizes above in the roles of Material's text theme, which every
  /// `Text` picks up (see [LowEndTheme]).
  static const textTheme = TextTheme(
    displayMedium: TextStyle(fontSize: display),
    headlineSmall: TextStyle(fontSize: headline),
    titleLarge: TextStyle(fontSize: title),
    titleMedium: TextStyle(fontSize: body),
    titleSmall: TextStyle(fontSize: caption),
    bodyLarge: TextStyle(fontSize: body),
    bodyMedium: TextStyle(fontSize: caption),
    labelLarge: TextStyle(fontSize: caption),
    bodySmall: TextStyle(fontSize: small),
    labelMedium: TextStyle(fontSize: small),
    labelSmall: TextStyle(fontSize: small),
  );

  /// The style of the octave beside a note written in [note].
  static TextStyle octave(TextStyle? note) =>
      TextStyle(fontSize: (note?.fontSize ?? display) * octaveScale);
}

/// Shapes and sizes of the controls.
abstract final class LowEndShape {
  /// Corner radius of buttons, cards and menus.
  static const radius = 16.0;

  /// Fine rule beneath the bottom navigation, including its safe area.
  static const navigationBaseLine = 2.0;

  /// Width of the rail of the tabs, in landscape, however long the names:
  /// they shrink to fit.
  static const railWidth = 96.0;
}
