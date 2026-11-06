import 'package:flutter/gestures.dart';

import 'player_controller.dart';

/// A drag that wins at once, before the swipe between the sections, when the
/// finger lands on a flag (RF-PLY-08, RF-PLY-17); anywhere else it does not
/// take part, and the touch and the swipe work as ever.
class FlagDrag extends PanGestureRecognizer {
  FlagDrag({required this.flagAt});

  /// The flag under [local] (a point of the widget), or null.
  final LoopEdge? Function(Offset local) flagAt;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      flagAt(event.localPosition) != null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
