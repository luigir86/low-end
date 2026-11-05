import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// What a vertical flick does in the landscape layout: [onFlip] gets +1 for
/// the next section (the finger moved up) or -1 for the previous one. With
/// no [onFlip] the flick does nothing: the player locked the gestures.
class SectionFlip extends InheritedWidget {
  const SectionFlip({super.key, required this.onFlip, required super.child});

  final void Function(int direction)? onFlip;

  static SectionFlip? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SectionFlip>();

  @override
  bool updateShouldNotify(SectionFlip old) =>
      (onFlip == null) != (old.onFlip == null);
}

/// Turns an up or down swipe on [child] into a [SectionFlip]: the landscape
/// layout has the tabs in a column, so the sections follow vertically. Only
/// the dial and the tab rail wear it, never the column of rows, which scrolls
/// with large text. A swipe that starts at the very top or bottom of the
/// screen is left to the system (notification shade, home gesture).
///
/// It has to be a deliberate flick: far enough, and quick. A slow drag, such
/// as a finger resting on the dial while the other hand plays, is not one.
///
/// Only fingers and pens flick. A mouse (the web app on a computer, whose
/// wide window has the rail) changes section with the tabs: its drag starts
/// after a single pixel, so a click that moves a little would become a drag
/// and the tab, or the middle of the dial, would never get it.
class FlipDetector extends StatefulWidget {
  const FlipDetector({super.key, required this.child});

  final Widget child;

  /// How far the finger must go (two pan slops) and how long it may take (a
  /// long press): what Flutter counts as a deliberate drag.
  static const distance = kPanSlop * 2;
  static const duration = kLongPressTimeout;

  /// What can flick: everything but a mouse and a trackpad.
  static const devices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  @override
  State<FlipDetector> createState() => _FlipDetectorState();
}

class _FlipDetectorState extends State<FlipDetector> {
  var _travel = 0.0;
  var _ignored = false;
  Duration? _start;

  @override
  Widget build(BuildContext context) {
    final flip = SectionFlip.maybeOf(context)?.onFlip;
    if (flip == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      supportedDevices: FlipDetector.devices,
      onVerticalDragStart: (d) {
        final media = MediaQuery.of(context);
        // The strip along the top and bottom edges is the system's: the
        // status bar and the notification shade, the home gesture.
        final top = math.max(
          media.viewPadding.top,
          media.systemGestureInsets.top,
        );
        final bottom = math.max(
          media.viewPadding.bottom,
          media.systemGestureInsets.bottom,
        );
        _travel = 0;
        _start = d.sourceTimeStamp;
        _ignored =
            d.globalPosition.dy < top ||
            d.globalPosition.dy > media.size.height - bottom;
      },
      onVerticalDragUpdate: (d) {
        if (_ignored) return;
        _travel += d.delta.dy;
        final start = _start;
        final now = d.sourceTimeStamp;
        if (start != null &&
            now != null &&
            now - start > FlipDetector.duration) {
          // Too slow: this is not a flick, and will not turn into one.
          _ignored = true;
          return;
        }
        if (_travel.abs() >= FlipDetector.distance) {
          // Up: the next section, like the page of a vertical PageView.
          flip(_travel < 0 ? 1 : -1);
          _ignored = true;
        }
      },
      child: widget.child,
    );
  }
}
