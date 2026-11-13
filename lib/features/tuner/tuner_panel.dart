import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../app/app_navigation.dart';
import '../../app/decimal.dart';
import '../../app/settings.dart';
import '../../app/style.dart';
import '../../app/theme.dart';
import '../../audio/audio_scope.dart';
import '../../audio/mic_input.dart';
import '../../audio/pitch.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/choice_menu.dart';
import '../../widgets/dial.dart';
import '../../widgets/reference_pitch_row.dart';
import '../../widgets/row_controls.dart';
import 'tuner_controller.dart';
import 'tuner_reading.dart';
import 'tuner_tuning.dart';

/// The tuner: listens to the microphone, names whatever note it hears (no
/// tuning to choose) and shows how far off it is on a round strobe, like
/// the Peterson tuners, with the note in the middle.
class TunerPanel extends StatefulWidget {
  const TunerPanel({super.key});

  @override
  State<TunerPanel> createState() => _TunerPanelState();
}

class _TunerPanelState extends State<TunerPanel> {
  late TunerController _tuner;
  late AppNavigation _navigation;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Stop listening when the app goes to the background, and listen again
    // when it comes back with the tuner on screen, unless the player paused
    // it. The callbacks use the controllers saved below: the context must
    // not be looked up from outside a build.
    _lifecycle = AppLifecycleListener(
      onHide: () => _tuner.stop(),
      onShow: () {
        if (_navigation.tunerVisible) _tuner.resume();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AudioScope.of(context);
    _tuner = scope.tuner;
    _navigation = scope.navigation;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _tuner.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AudioScope.of(context).settings;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scope = AudioScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        _tuner,
        settings,
        scope.drone,
        scope.metronome,
        scope.player,
      ]),
      builder: (context, _) {
        final names = settings.noteNames(Localizations.localeOf(context));
        final hz = _tuner.frequency;
        final reading = hz == null
            ? null
            : TunerReading.of(
                hz,
                a4: settings.a4,
                tolerance: settings.inTuneCents,
                tuning: settings.tuning,
              );
        final message = _statusMessage(l10n);
        // A transposing instrument reads its own notes; the strings of the
        // instruments in the menu sound as written.
        final transposition = settings.tuning.isChromatic
            ? settings.transposition
            : Transposition.c;
        return DialLayout(
          dial: _StrobeDisc(
            reading: reading,
            held: _tuner.held,
            tolerance: settings.inTuneCents,
            listening: _tuner.isListening,
            soundPlaying:
                scope.drone.isPlaying ||
                scope.metronome.isPlaying ||
                scope.player.isPlaying,
            names: names,
            numbering: settings.octaveNumbering,
            transposition: transposition,
            onToggle: _tuner.toggle,
          ),
          // The cents scale sits in the first row, next to the strobe, which the
          // other tabs leave empty. Announced by screen readers, e.g. when the
          // microphone is denied, a message takes its place. Paused, the
          // middle of the dial already says Listen: the scale stays, empty,
          // and only screen readers hear that the tuner paused.
          header: message == null || _tuner.status == TunerStatus.idle
              ? Semantics(
                  liveRegion: message != null,
                  label: message,
                  child: _CentsBar(
                    reading: reading,
                    held: _tuner.held,
                    tolerance: settings.inTuneCents,
                    listening: _tuner.isListening,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                    // A way out of a no: straight to the app's settings
                    // (a web page cannot open them).
                    if (_tuner.status == TunerStatus.permissionDenied &&
                        !kIsWeb) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: openAppSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(l10n.openSettings),
                      ),
                    ],
                  ],
                ),
          // Chromatic or an instrument, in the place of the harmony's
          // Chord / Progression.
          upper: _InstrumentField(settings: settings),
          // Listening starts and stops from the middle of the dial, like the
          // other two tabs; the last row is the reference A, in the same
          // pieces as the rows of the metronome and the harmony.
          lower: const ReferencePitchRow(),
        );
      },
    );
  }

  String? _statusMessage(AppLocalizations l10n) => switch (_tuner.status) {
    TunerStatus.idle => l10n.tunerIdleHint,
    TunerStatus.permissionDenied =>
      kIsWeb ? l10n.micPermissionDeniedWeb : l10n.micPermissionDenied,
    TunerStatus.failed => l10n.micUnavailable,
    TunerStatus.starting || TunerStatus.listening => null,
  };
}

String _tuningName(AppLocalizations l10n, TunerTuning tuning) =>
    switch (tuning) {
      TunerTuning.chromatic => l10n.tuningChromatic,
      TunerTuning.guitar => l10n.tuningGuitar,
      TunerTuning.violin => l10n.tuningViolin,
      TunerTuning.viola => l10n.tuningViola,
      TunerTuning.cello => l10n.tuningCello,
      TunerTuning.ukulele => l10n.tuningUkulele,
      TunerTuning.bass => l10n.tuningBass,
    };

/// What the tuner listens for, in the first row under the dial: one field,
/// like the harmony's chord menu, that always names what is being tuned.
/// Chromatic comes first, as the note alone does in the chord menu; then the
/// instruments with their open strings. With strings, the tuner names the
/// nearest open string, its number, and says how far off it is. The last
/// instrument stays remembered while the tuner is chromatic.
class _InstrumentField extends StatelessWidget {
  const _InstrumentField({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = settings.noteNames(Localizations.localeOf(context));
    String strings(TunerTuning t) => t.strings
        .map((n) => n.label(names, numbering: settings.octaveNumbering))
        .join(' ');
    // A transposing instrument says its key: "Chromatic · B♭".
    final chromaticName = settings.transposition == Transposition.c
        ? l10n.tuningChromatic
        : '${l10n.tuningChromatic} · '
              '${Note(settings.transposition.key, 4).name(names)}';
    return Builder(
      builder: (field) => LabeledField(
        key: const Key('instrumentMenu'),
        label: l10n.tuningInstrument,
        value: settings.tunerChromatic
            ? chromaticName
            : _tuningName(l10n, settings.tunerInstrument),
        onTap: () async {
          final picked = await showChoiceMenu<TunerTuning>(
            anchor: field,
            selected: settings.tuning,
            choices: [
              Choice(
                value: TunerTuning.chromatic,
                title: chromaticName,
                subtitle: l10n.tuningChromaticHint,
              ),
              for (final t in TunerTuning.instruments)
                Choice(
                  value: t,
                  title: _tuningName(l10n, t),
                  subtitle: strings(t),
                ),
            ],
          );
          if (picked == null) return;
          if (picked.isChromatic) {
            settings.setTunerChromatic(true);
          } else {
            settings.setTunerInstrument(picked);
            settings.setTunerChromatic(false);
          }
        },
      ),
    );
  }
}

/// The shape that goes with the verdict's colour: a tick in tune, an arrow
/// up or down when close, two arrows when far off (the same limits as
/// [_centsColor]), so that close and far differ by more than their colour.
IconData verdictIcon(double cents, double tolerance) {
  final off = cents.abs();
  if (off <= tolerance) return Icons.check_circle;
  final far = off > math.max(15, tolerance);
  if (cents < 0) {
    return far ? Icons.keyboard_double_arrow_down : Icons.arrow_downward;
  }
  return far ? Icons.keyboard_double_arrow_up : Icons.arrow_upward;
}

/// Green when in tune, yellow when close, red when far off: the shades live
/// in lib/app/theme.dart and keep at least 3:1 contrast (WCAG 1.4.3, 1.4.11).
Color _centsColor(ThemeData theme, double cents, double tolerance) {
  final colors = theme.extension<LowEndColors>()!;
  final off = cents.abs();
  if (off <= tolerance) return colors.inTune;
  if (off <= math.max(15, tolerance)) return colors.close;
  return colors.off;
}

/// The round strobe, with the note and the verdict in its middle.
///
/// Two rings of segments turn anticlockwise when the note is flat and
/// clockwise when it is sharp, faster the further off it is, and stand still
/// when it is spot on. The inner ring turns twice as fast, so it shows even
/// a cent or two. With animations turned off in the phone settings, a still
/// marker on the rim shows the cents instead.
class _StrobeDisc extends StatefulWidget {
  const _StrobeDisc({
    required this.reading,
    required this.held,
    required this.tolerance,
    required this.listening,
    required this.soundPlaying,
    required this.names,
    required this.numbering,
    required this.transposition,
    required this.onToggle,
  });

  final TunerReading? reading;

  /// The note is only kept on screen while the string dies away.
  final bool held;

  /// How many cents either side of a note count as in tune.
  final double tolerance;
  final bool listening;

  /// The metronome or the drone plays: listening will pause it.
  final bool soundPlaying;
  final NoteNames names;
  final OctaveNumbering numbering;

  /// The key the notes are named in (see [AppSettings.transposition]).
  final Transposition transposition;

  /// Touching the middle pauses or resumes listening.
  final VoidCallback onToggle;

  @override
  State<_StrobeDisc> createState() => _StrobeDiscState();
}

class _StrobeDiscState extends State<_StrobeDisc>
    with SingleTickerProviderStateMixin {
  /// Segments per second for each cent off, on the outer ring.
  static const _speed = 0.5;

  /// Fastest turn, in segments per second: beyond this the eye loses track.
  static const _maxSpeed = 6.0;

  late final Ticker _ticker = createTicker(_tick);
  final _phase = ValueNotifier<double>(0);
  var _last = Duration.zero;

  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StrobeDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Turns only while a note is heard, to save battery.
  void _sync() {
    final turning =
        widget.listening && widget.reading != null && !widget.held && _animate;
    if (turning && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!turning && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // A note that is only held stands still: it is not being heard.
    final cents = widget.held ? 0.0 : (widget.reading?.cents ?? 0);
    final speed = (cents * _speed).clamp(-_maxSpeed, _maxSpeed);
    _phase.value = (_phase.value + speed * seconds) % 1024;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.reading;
    // The same verdict as the symbol and cents scale, on both bands.
    // A held note is no longer heard: it must not look actively in tune.
    final idle = !widget.listening || r == null || widget.held;
    final colors = LowEndColors.of(context);
    final segments = idle
        ? colors.strobeIdle
        : _centsColor(theme, r.cents, widget.tolerance);
    return LayoutBuilder(
      builder: (context, box) {
        // The hub of every tab: inside the ring they share.
        final dial = DialGeometry(box.biggest);
        final hubFraction = box.biggest.isEmpty
            ? DialGeometry.hubFraction
            : dial.centreRadius / dial.radius;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Moves on every frame: repaint only this part of the screen.
            RepaintBoundary(
              child: ExcludeSemantics(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(begin: segments, end: segments),
                  duration: _animate ? Durations.short4 : Duration.zero,
                  curve: Easing.standard,
                  builder: (context, color, _) => CustomPaint(
                    key: const Key('tunerStrobe'),
                    painter: _DiscPainter(
                      phase: _phase,
                      segments: color!,
                      innerSegments: color,
                      hub: theme.colorScheme.surface,
                      // A still marker for players who turned animations off.
                      stillCents: _animate ? null : r?.cents,
                      scale: theme.colorScheme.outline,
                      edge: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ),
            // The hub is the button: as wide as the hub of the dial.
            Center(
              child: FractionallySizedBox(
                widthFactor: hubFraction,
                heightFactor: hubFraction,
                child: Semantics(
                  button: true,
                  label: widget.listening
                      ? AppLocalizations.of(context).stopListening
                      : AppLocalizations.of(context).startListening,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: const Key('tunerHub'),
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onToggle();
                      },
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.5 / DialGeometry.hubFraction,
                          heightFactor: 0.5 / DialGeometry.hubFraction,
                          child: _NoteDisplay(
                            reading: r,
                            held: widget.held,
                            tolerance: widget.tolerance,
                            listening: widget.listening,
                            soundPlaying: widget.soundPlaying,
                            names: widget.names,
                            numbering: widget.numbering,
                            transposition: widget.transposition,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter({
    required this.phase,
    required this.segments,
    required this.innerSegments,
    required this.hub,
    required this.stillCents,
    required this.scale,
    required this.edge,
  }) : super(repaint: phase);

  final ValueNotifier<double> phase;
  final Color segments;

  /// The inner band, which turns twice as fast.
  final Color innerSegments;
  final Color hub;
  final double? stillCents;
  final Color scale;
  final Color edge;

  static const _count = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final dial = DialGeometry(size);
    // Two bands of segments fill the ring, the inner one turning twice as
    // fast: the same ring the drone and the metronome use.
    const step = 2 * math.pi / _count;
    // From the inner edge shared by every tab out to the dial's edge.
    final inner = dial.mainInner, width = dial.ringOuter - inner;
    final split = inner + width / 2;
    final bandGap = width * 0.06;
    for (var band = 0; band < 2; band++) {
      final turn = stillCents == null ? phase.value * (band + 1) * step : 0.0;
      for (var i = 0; i < _count; i++) {
        dial.paintSegment(
          canvas,
          startAngle: i * step + turn,
          // Narrower than the gaps between them: a lighter ring.
          sweep: step * 0.4,
          color: band == 0 ? segments : innerSegments,
          inner: band == 0 ? split + bandGap / 2 : inner,
          outer: band == 0 ? dial.ringOuter : split - bandGap / 2,
          border: edge,
        );
      }
    }

    // A fixed reference at 12 o'clock across both bands: the segments stand
    // still against it when in tune.
    final top = dial.center.dx;
    final y0 = dial.center.dy - dial.ringOuter;
    final y1 = dial.center.dy - dial.mainInner;
    canvas.drawLine(
      Offset(top, y0),
      Offset(top, y1),
      Paint()
        ..color = hub
        ..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(top, y0),
      Offset(top, y1),
      Paint()
        ..color = scale
        ..strokeWidth = 2,
    );

    if (stillCents case final cents?) {
      // Ticks every 10 cents over the top of the hub, the marker on them.
      final center = dial.center;
      double angle(double c) => -math.pi / 2 + c / 50 * (math.pi * 3 / 4);
      final tick = Paint()
        ..color = scale
        ..strokeWidth = 2;
      for (var c = -50; c <= 50; c += 10) {
        final a = angle(c.toDouble());
        final dir = Offset(math.cos(a), math.sin(a));
        // The tick for "in tune" is longer and thicker: told by shape.
        final zero = c == 0;
        canvas.drawLine(
          center + dir * (dial.centreRadius * (zero ? 0.72 : 0.86)),
          center + dir * (dial.centreRadius * (zero ? 1.0 : 0.96)),
          zero
              ? (Paint()
                  ..color = scale
                  ..strokeWidth = 4)
              : tick,
        );
      }
      final a = angle(cents.clamp(-50, 50));
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * (dial.centreRadius * 0.80),
        center + dir * dial.centreRadius,
        Paint()
          ..color = segments
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DiscPainter old) =>
      old.segments != segments ||
      old.innerSegments != innerSegments ||
      old.hub != hub ||
      old.stillCents != stillCents ||
      old.scale != scale ||
      old.edge != edge;
}

class _NoteDisplay extends StatelessWidget {
  const _NoteDisplay({
    required this.reading,
    required this.held,
    required this.tolerance,
    required this.listening,
    required this.soundPlaying,
    required this.names,
    required this.numbering,
    required this.transposition,
  });

  final TunerReading? reading;
  final bool held;
  final double tolerance;
  final bool listening;
  final bool soundPlaying;
  final NoteNames names;
  final OctaveNumbering numbering;
  final Transposition transposition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final r = reading;
    // Fixed sizes, the same as on the other two dials; large text on the
    // phone shrinks the whole block to fit rather than overflow.
    Widget fit(List<Widget> children) => Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
    // The reading: the note keeps its own size, whatever the words under it
    // say ("In tune" or "Flat −9 cents"), so it does not jump while tuning.
    // Each row shrinks alone to the width of the dial; the block as a whole
    // shrinks only when it is too tall, and that does not depend on the
    // verdict's words.
    Widget fitRows(List<Widget> children) => Center(
      child: LayoutBuilder(
        builder: (context, box) {
          if (!box.maxWidth.isFinite) return fit(children);
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final child in children)
                    FittedBox(fit: BoxFit.scaleDown, child: child),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (!listening) {
      // Paused: what touching the middle does.
      return fit([
        Icon(Icons.mic, size: 32, color: LowEndColors.of(context).activeFill),
        Text(l10n.startListening, style: muted, textAlign: TextAlign.center),
        // Something sounds: touching will pause it, and the player is told
        // before, not after.
        if (soundPlaying)
          Text(
            l10n.tunerWillPause,
            style: muted?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
      ]);
    }
    if (r == null) {
      return fit([
        Text('–', style: _noteStyle(theme)),
        Text(l10n.playAString, style: muted, textAlign: TextAlign.center),
      ]);
    }
    final cents = r.cents.round();
    final direction = r.inTune
        ? l10n.inTune
        : (cents < 0 ? l10n.flat : l10n.sharp);
    // A real minus sign: the hyphen is too short next to the plus.
    final centsText = l10n.centsValue(
      cents > 0 ? '+$cents' : (cents < 0 ? '−${-cents}' : '$cents'),
    );
    final color = _centsColor(theme, r.cents, tolerance);
    // The note as the player reads it: written, for a transposing
    // instrument.
    final target = transposition.written(r.target);
    final played = transposition.written(r.played);
    final key = transposition == Transposition.c
        ? null
        : l10n.transpositionKey(Note(transposition.key, 4).name(names));
    // Screen readers hear the note and whether it is flat, sharp or in tune,
    // only when that changes: reading every cent aloud would never stop.
    return Semantics(
      container: true,
      liveRegion: true,
      label:
          '${target.label(names, numbering: numbering)}'
          '${key == null ? '' : ' $key'}, $direction'
          '${r.onStrings && r.played != r.target ? ', ${l10n.tunerHeard(played.label(names, numbering: numbering))}' : ''}',
      child: ExcludeSemantics(
        // A note that is only held fades: the string has stopped.
        child: AnimatedOpacity(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Durations.short4,
          opacity: held ? 0.55 : 1,
          child: fitRows([
            // Note and verdict words remain readable; the symbol carries
            // the palette-specific verdict colour.
            _NoteName(
              note: target,
              names: names,
              numbering: numbering,
              color: theme.colorScheme.onSurface,
            ),
            // The verdict, large enough to read from the music stand.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A shape as well as a colour, for colour-blind players: a
                // tick in tune, one arrow close, two arrows far off.
                Icon(
                  verdictIcon(r.cents, tolerance),
                  color: color,
                  shadows: [
                    Shadow(color: theme.colorScheme.onSurface, blurRadius: 2),
                  ],
                  size: LowEndType.headline,
                ),
                const SizedBox(width: 6),
                Text(
                  r.inTune ? direction : '$direction $centsText',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            // With strings: the string being tuned, and what was heard when
            // it is not that one.
            if (r.onStrings) ...[
              if (r.stringNumber case final n?)
                Text(
                  l10n.tunerString(romanNumeral(n)),
                  style: muted?.copyWith(fontWeight: FontWeight.w700),
                ),
              if (r.played != r.target)
                Text(
                  l10n.tunerHeard(played.label(names, numbering: numbering)),
                  style: muted,
                ),
            ],
            // Written notes say for which key.
            if (key != null)
              Text(key, style: muted?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              // A held note says so in words, not only by fading.
              held
                  ? l10n.tunerHeld
                  : l10n.frequencyHz(decimalText(l10n, r.frequency)),
              style: muted,
            ),
          ]),
        ),
      ),
    );
  }
}

TextStyle? _noteStyle(ThemeData theme) =>
    theme.textTheme.displayMedium?.copyWith(height: 1.05);

/// The note name, large, with its octave smaller beside it.
class _NoteName extends StatelessWidget {
  const _NoteName({
    required this.note,
    required this.names,
    required this.numbering,
    required this.color,
  });

  final Note note;
  final NoteNames names;
  final OctaveNumbering numbering;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = _noteStyle(Theme.of(context))
        ?.copyWith(color: color, fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: note.name(names)),
          TextSpan(
            text: '${note.octaveIn(names, numbering: numbering)}',
            style: LowEndType.octave(style),
          ),
        ],
      ),
      style: style,
      textAlign: TextAlign.center,
    );
  }
}

/// The cents, 50 flat to 50 sharp, in the first row under the dial: a scale
/// on a horizontal axis, with a tick every 5 cents, and a needle at the
/// note. The axis takes the verdict's colour from 0 to the needle, so the
/// length of that stretch says how far off the note is even to a player who
/// cannot tell the colours apart. No zone is marked round 0: the needle's
/// colour and the verdict in the dial say when the note is in tune. The
/// strobe shows the same thing by turning, which is hard to read at a
/// glance, and this by position, which is not.
class _CentsBar extends StatelessWidget {
  const _CentsBar({
    required this.reading,
    required this.held,
    required this.tolerance,
    required this.listening,
  });

  final TunerReading? reading;
  final bool held;
  final double tolerance;
  final bool listening;

  /// The room left at each side, so that the numbers under the ends of the
  /// scale stay inside the width of the rows below it.
  static const _inset = 24.0;

  /// The numbers written under the scale.
  static const _numbers = [-50, -25, 0, 25, 50];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final r = reading;
    final show = listening && r != null;
    final label = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // The note and its verdict are read by the middle of the dial.
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Over the scale: which side is flat, which sharp, and what it
            // counts.
            Row(
              children: [
                Expanded(child: Text(l10n.flat, style: label)),
                Text(l10n.centsTitle, style: label),
                Expanded(
                  child: Text(
                    l10n.sharp,
                    style: label,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            SizedBox(
              // Leave room for both caption lines in the shared 64 dp row.
              height: 24,
              width: double.infinity,
              child: CustomPaint(
                painter: _CentsScalePainter(
                  cents: show ? r.cents : null,
                  // The verdict's colour: green in tune, yellow close, red
                  // far off; the colour of the borders while the note is
                  // only held.
                  needle: show && !held
                      ? _centsColor(theme, r.cents, tolerance)
                      : theme.colorScheme.outline,
                  axis: theme.colorScheme.outline,
                  minorTick: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            // The numbers, each centred under its tick.
            LayoutBuilder(
              builder: (context, box) => SizedBox(
                width: box.maxWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Holds the height of a line of numbers.
                    Opacity(opacity: 0, child: Text('0', style: label)),
                    for (final n in _numbers)
                      Positioned(
                        left: centsOnScale(n.toDouble()) * box.maxWidth,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: Text(
                            // A real minus sign: the hyphen is too short next
                            // to the plus.
                            n > 0 ? '+$n' : (n < 0 ? '−${-n}' : '0'),
                            style: label,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where [cents] fall on the scale, from 0 (50 flat) to 1 (50 sharp); a
/// note further off stays at the end.
double centsOnScale(double cents) => (cents.clamp(-50, 50) + 50) / 100;

class _CentsScalePainter extends CustomPainter {
  _CentsScalePainter({
    required this.cents,
    required this.needle,
    required this.axis,
    required this.minorTick,
  });

  final double? cents;
  final Color needle;
  final Color axis;
  final Color minorTick;

  @override
  void paint(Canvas canvas, Size size) {
    // The axis runs along the bottom; the ticks stand on it and the
    // needle's head sits over them.
    final y = size.height - 4;
    double x(double c) => centsOnScale(c) * size.width;
    canvas.drawRRect(
      RRect.fromLTRBR(0, y - 1, size.width, y + 1, const Radius.circular(1)),
      Paint()..color = axis,
    );
    // A tick every 5 cents: tall and thicker at 0, ±25 and ±50, middle at
    // every 10, short in between.
    for (var c = -50; c <= 50; c += 5) {
      final major = c % 25 == 0;
      final height = major ? 14.0 : (c % 10 == 0 ? 9.0 : 6.0);
      final width = major ? 2.0 : 1.0;
      canvas.drawRect(
        Rect.fromLTRB(
          x(c.toDouble()) - width / 2,
          y - height,
          x(c.toDouble()) + width / 2,
          y,
        ),
        Paint()..color = major ? axis : minorTick,
      );
    }
    final c = cents;
    if (c == null) return;
    final paint = Paint()..color = needle;
    // The axis in the needle's colour from 0 to the needle, however short.
    final from = math.min(x(0), x(c));
    final to = math.max(x(0), x(c));
    canvas.drawRect(Rect.fromLTRB(from, y - 2.5, to, y + 2.5), paint);
    // The needle: a line from over the ticks to under the axis, with a
    // head pointing down at the scale.
    final at = x(c);
    canvas.drawRect(Rect.fromLTRB(at - 1.25, 9, at + 1.25, y + 4), paint);
    canvas.drawPath(
      Path()
        ..moveTo(at - 6, 0)
        ..lineTo(at + 6, 0)
        ..lineTo(at, 10)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CentsScalePainter old) =>
      old.cents != cents ||
      old.needle != needle ||
      old.axis != axis ||
      old.minorTick != minorTick;
}
