import 'package:flutter/material.dart';

/// One accent for the current interface, launcher and startup.
/// After changing [accent], run `flutter test tool/make_icons_test.dart` before
/// a local build. CI runs it automatically, including the Pages publication.
abstract final class LowEndBrand {
  static const ffmRed = Color(0xFFA6282C);
  static const brass = Color(0xFFB69A58);

  /// The only colour choice: use ffmRed to restore the FFM accent.
  static const accent = brass;

  static const ivory = Color(0xFFFFF5E3);
  static const mark = 'assets/brand/mark.png';
  static const splashExtent = 288.0;
  static const transition = Duration(milliseconds: 180);
}
