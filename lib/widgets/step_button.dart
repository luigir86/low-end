import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';

import 'row_controls.dart';

/// A chip of the − + pair that steps by one when tapped. Held, it keeps
/// going by one, faster and faster, and after a couple of seconds by fives
/// (to the next multiple of 5), until it is let go. The tempo of the
/// metronome uses it, and so does the Player to move the ends of a loop.
/// [onHold] is told the unit, 1 and then 5, and each user decides what it
/// stands for.
class StepButton extends StatefulWidget {
  const StepButton({
    super.key,
    this.icon,
    this.label,
    required this.tooltip,
    required this.onStep,
    required this.onHold,
  }) : assert(icon != null || label != null);

  /// What is drawn in the chip: an icon, or, to say more than an icon can,
  /// any [label] (the Player's ‹ A and B ›).
  final IconData? icon;
  final Widget? label;

  /// What a screen reader says: there is no tooltip, since holding the
  /// chip is how the tempo runs.
  final String tooltip;
  final VoidCallback? onStep;

  /// Called again and again while held, with the size of the step.
  final void Function(int unit) onHold;

  /// How long a touch lasts before it counts as held.
  static const holdAfter = kLongPressTimeout;

  /// The pause between the first steps of a hold, and the shortest one it
  /// shrinks to.
  static const _firstEvery = 200;
  static const _fastestEvery = 50;

  /// How long the steps of 1 last before they become steps of 5.
  static const _fivesAfter = Duration(milliseconds: 2400);
  static const _fivesEvery = Duration(milliseconds: 140);

  @override
  State<StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<StepButton> {
  Timer? _timer;

  /// How long the hold has been running, as the sum of its steps' pauses.
  var _held = Duration.zero;
  var _every = StepButton._firstEvery.toDouble();

  /// True once the touch has turned into a hold: letting go then must not
  /// also count as a tap.
  var _holding = false;

  void _down() {
    _stop();
    _holding = false;
    if (widget.onStep == null) return;
    _timer = Timer(StepButton.holdAfter, () {
      _holding = true;
      _every = StepButton._firstEvery.toDouble();
      _held = Duration.zero;
      _tick();
    });
  }

  void _tick() {
    if (!mounted || widget.onStep == null) return _stop();
    final Duration next;
    if (_held < StepButton._fivesAfter) {
      widget.onHold(1);
      next = Duration(milliseconds: _every.round());
      // Each step comes a little sooner than the last.
      _every = math.max(StepButton._fastestEvery.toDouble(), _every * 0.85);
    } else {
      widget.onHold(5);
      next = StepButton._fivesEvery;
    }
    _held += next;
    _timer = Timer(next, _tick);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onStep = widget.onStep;
    return Semantics(
      button: true,
      enabled: onStep != null,
      label: widget.tooltip,
      onTap: onStep,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) {
          _stop();
          _holding = false;
        },
        child: RowButton(
          label: widget.label ?? Icon(widget.icon, size: 24),
          // A tap steps by one; the end of a hold has already stepped.
          onPressed: onStep == null
              ? null
              : () {
                  if (_holding) {
                    _holding = false;
                    return;
                  }
                  onStep();
                },
        ),
      ),
    );
  }
}
