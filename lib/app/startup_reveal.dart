import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand.dart';

/// Continues the native/web splash over the live app, without gating input or
/// delaying its construction. Used only at the process entry point.
class StartupReveal extends StatefulWidget {
  const StartupReveal({super.key, required this.child});

  final Widget child;

  @override
  State<StartupReveal> createState() => _StartupRevealState();
}

class _StartupRevealState extends State<StartupReveal>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: LowEndBrand.transition)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _finished = true);
          }
        });
  bool _started = false;
  bool _finished = false;

  void _reveal() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final features = View.of(context)
          .platformDispatcher
          .accessibilityFeatures;
      if (features.disableAnimations || features.accessibleNavigation) {
        setState(() => _finished = true);
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    textDirection: TextDirection.ltr,
    fit: StackFit.expand,
    children: [
      widget.child,
      if (!_finished)
        IgnorePointer(
          child: ExcludeSemantics(
            child: FadeTransition(
              opacity: ReverseAnimation(_controller),
              child: ColoredBox(
                color: LowEndBrand.palette.brand,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final extent = math.min(
                      LowEndBrand.splashExtent,
                      constraints.biggest.shortestSide,
                    );
                    return Center(
                      child: Image.asset(
                        LowEndBrand.mark,
                        width: extent,
                        height: extent,
                        frameBuilder: (context, child, frame, synchronous) {
                          if (frame != null) _reveal();
                          return child;
                        },
                        errorBuilder: (context, error, stack) {
                          // A missing image must never trap the startup layer.
                          _reveal();
                          return const SizedBox.shrink();
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
