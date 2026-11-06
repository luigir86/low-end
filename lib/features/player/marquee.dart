import 'dart:async';

import 'package:flutter/material.dart';

/// One line of text that fits, or, if it does not, goes by once and stops
/// (RF-PLY-19): it starts [delay] after it appears or after the track starts
/// playing, goes left at a steady pace until its end shows, rests, fades and
/// comes back still at its start. A pass lasts under five seconds
/// (WCAG 2.2.2); with animations off it never moves and ends in dots.
class Marquee extends StatefulWidget {
  const Marquee({
    super.key,
    required this.text,
    required this.style,
    required this.playing,
  });

  final String text;
  final TextStyle? style;

  /// True while the track plays: each start of play makes a pass.
  final bool playing;

  /// The wait before a pass.
  static const delay = Duration(seconds: 1);

  /// The rest at the end of the text, before it fades.
  static const rest = Duration(seconds: 1);

  /// The slowest pace, in logical pixels a second; a long text goes faster so
  /// that the walk takes three seconds at most.
  static const slowest = 30.0;
  static const _walkAtMost = 3.0;

  /// How long the walk of [excess] pixels takes.
  static Duration walk(double excess) {
    final pace = excess / _walkAtMost > slowest
        ? excess / _walkAtMost
        : slowest;
    return Duration(milliseconds: (excess / pace * 1000).round());
  }

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _pass = AnimationController(vsync: this);
  Timer? _wait;

  /// How far the text overflows its room, from the last layout.
  var _excess = 0.0;
  var _walkMs = 0;
  var _fadeMs = 0;
  var _restMs = 0;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(Marquee old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || (widget.playing && !old.playing)) _arm();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _pass.dispose();
    super.dispose();
  }

  /// Plans a pass for [Marquee.delay] from now.
  void _arm() {
    _wait?.cancel();
    _pass
      ..stop()
      ..value = 0;
    _wait = Timer(Marquee.delay, _start);
  }

  void _start() {
    if (!mounted || _excess <= 0 || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _walkMs = Marquee.walk(_excess).inMilliseconds;
    _fadeMs = Durations.medium2.inMilliseconds;
    _restMs = Marquee.rest.inMilliseconds;
    _pass.duration = Duration(milliseconds: _walkMs + _restMs + 2 * _fadeMs);
    _pass.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        _excess = width > room + 0.5 ? width - room : 0;
        if (_excess == 0) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
          );
        }
        // Too long: still, it fades at its end (dots when no motion is
        // wanted); passing, it is shown whole and slides.
        final still = reduce
            ? Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              )
            : ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.85, 1],
                ).createShader(bounds),
                child: Text(
                  widget.text,
                  style: widget.style,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              );
        if (reduce) return still;
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pass,
            child: still,
            builder: (context, still) {
              if (!_pass.isAnimating) return still!;
              final total = _walkMs + _restMs + 2 * _fadeMs;
              final ms = _pass.value * total;
              final walking = ms.clamp(0, _walkMs) / _walkMs;
              var opacity = 1.0;
              var moved = true;
              if (ms > _walkMs + _restMs) {
                final into = ms - _walkMs - _restMs;
                if (into < _fadeMs) {
                  opacity = 1 - Easing.standard.transform(into / _fadeMs);
                } else {
                  // Back at the start, coming up again.
                  moved = false;
                  opacity = Easing.standard.transform(
                    (into - _fadeMs) / _fadeMs,
                  );
                }
              }
              if (!moved) {
                return Opacity(opacity: opacity, child: still);
              }
              return Opacity(
                opacity: opacity,
                child: ClipRect(
                  child: UnconstrainedBox(
                    constrainedAxis: Axis.vertical,
                    alignment: AlignmentDirectional.centerStart,
                    clipBehavior: Clip.hardEdge,
                    child: Transform.translate(
                      offset: Offset(-_excess * walking, 0),
                      child: Text(
                        widget.text,
                        style: widget.style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
