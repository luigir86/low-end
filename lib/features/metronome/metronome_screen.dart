import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../app/theme.dart';
import '../../audio/audio_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/choice_menu.dart';
import '../../widgets/dial.dart';
import '../../widgets/row_controls.dart';
import '../../widgets/step_button.dart';
import 'metronome_controller.dart';
import 'note_icon.dart';
import 'subdivision.dart';
import 'tempo_dial.dart';
import 'tempo_dialog.dart';
import 'time_signature.dart';

/// The metronome: a ring with one segment per beat of the bar (4 in 4/4,
/// 6 in 6/8, and so on) lights up clockwise from 12 o'clock, with the "one"
/// in its own colour, and the tempo in the middle. A thin outer jog wheel
/// adjusts tempo independently of the inner beat ring and start/stop hub.
/// In bars felt in groups (6/8) wider gaps split the groups, and a bar of one beat is a single
/// segment that flashes. Touching the ring starts and stops it; below it, a
/// row like the harmony's that chooses the bar (the time signature and what
/// fills each beat), and one for the tempo: TAP, − + and a pencil to type it.
class MetronomeScreen extends StatelessWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final metronome = AudioScope.of(context).metronome;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: metronome,
      builder: (context, _) => DialLayout(
        dial: _BeatRing(metronome: metronome),
        header: Text(
          l10n.tempoDialCaption,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // The upper row, two fields like the tuner's, chooses the bar: the time
        // signature and what fills each beat. The second only sets the tempo:
        // TAP, − + and the pencil.
        upper: Row(
          key: const Key('barSwitch'),
          children: [
            Expanded(child: _SignatureButton(metronome: metronome)),
            const SizedBox(width: 8),
            Expanded(child: _SubdivisionField(metronome: metronome)),
          ],
        ),
        lower: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _TapButton(metronome: metronome)),
                const SizedBox(width: rowGap),
                StepButton(
                  icon: Icons.remove,
                  tooltip: l10n.slower,
                  onStep: metronome.bpm > MetronomeController.minBpm
                      ? () => metronome.step(-1)
                      : null,
                  onHold: (unit) => metronome.nudge(-1, unit),
                ),
                const SizedBox(width: rowGap),
                StepButton(
                  icon: Icons.add,
                  tooltip: l10n.faster,
                  onStep: metronome.bpm < metronome.maxTempo
                      ? () => metronome.step(1)
                      : null,
                  onHold: (unit) => metronome.nudge(1, unit),
                ),
                RowIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: l10n.setTempo,
                  onPressed: () => showTempoDialog(context, metronome),
                ),
              ],
            ),
            if (metronome.audioFailed)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // In a browser it is almost always a download that failed.
                  child: Text(
                    kIsWeb ? l10n.audioDownloadFailed : l10n.audioUnavailable,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The ring and the dot; touching it starts or stops the metronome.
class _BeatRing extends StatefulWidget {
  const _BeatRing({required this.metronome});

  final MetronomeController metronome;

  @override
  State<_BeatRing> createState() => _BeatRingState();
}

class _BeatRingState extends State<_BeatRing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onFrame);

  /// Bumped when the lit segment changes (or the metronome stops), to repaint
  /// the ring: the costly layer, which does not move between beats.
  final _ringFrame = ValueNotifier<int>(0);

  /// Bumped while the countdown shows, to repaint the hub.
  final _hubFrame = ValueNotifier<int>(0);

  int? _lastBeat;

  /// Wakes the frames again just before the next beat (see [_onFrame]).
  Timer? _nextBeat;

  /// How long before a beat the frames start again: enough for the timer
  /// coming in a little late, so that the beat is lit on its first frame.
  static const _wakeEarly = Duration(milliseconds: 40);

  void _onFrame(Duration _) {
    final metronome = widget.metronome;
    final beat = metronome.beat;
    if (beat != _lastBeat) {
      _lastBeat = beat;
      _ringFrame.value++;
      _hubFrame.value++;
    } else if (metronome.waitLeft != null) {
      _hubFrame.value++;
    }
    // A bar of one beat has a single segment: it flashes on the beat and
    // fades, so that the beat is seen.
    final since = metronome.sinceBeat;
    final flashing =
        metronome.beatsPerBar == 1 &&
        since != null &&
        since < _RingPainter.flashTime(metronome);
    if (flashing && beat == _lastBeat) _ringFrame.value++;
    // Between two beats nothing moves: no frames until just before the
    // next one, which saves the battery (and, in a browser, redrawing the
    // whole screen at every frame). Before the first beat (starting, or the
    // countdown) frames go on.
    if (beat == null || since == null || flashing) return;
    final wait = metronome.pulseLength - since - _wakeEarly;
    if (wait <= Duration.zero) return;
    _ticker.stop();
    _nextBeat = Timer(wait, _sync);
  }

  @override
  void initState() {
    super.initState();
    widget.metronome.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(_BeatRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metronome != widget.metronome) {
      oldWidget.metronome.removeListener(_sync);
      widget.metronome.addListener(_sync);
    }
    _sync();
  }

  /// Runs frames only while the metronome plays, to save battery. Also
  /// called just before a beat, and when the metronome changes (a new tempo
  /// moves the next beat): the frames start again at once.
  void _sync() {
    _nextBeat?.cancel();
    _nextBeat = null;
    final playing = widget.metronome.isPlaying;
    if (playing && !_ticker.isActive) _ticker.start();
    if (!playing && (_ticker.isActive || _lastBeat != null)) {
      _ticker.stop();
      _lastBeat = null;
      _ringFrame.value++;
      _hubFrame.value++;
    }
  }

  @override
  void dispose() {
    _nextBeat?.cancel();
    widget.metronome.removeListener(_sync);
    _ticker.dispose();
    _ringFrame.dispose();
    _hubFrame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metronome = widget.metronome;
    final playing = metronome.isPlaying;
    void toggle() {
      HapticFeedback.lightImpact();
      metronome.toggle();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = TempoDialGeometry(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Preserve the beat-ring tap and swipe behaviour. Its
            // accessible button is the centre, above the tempo slider.
            ExcludeSemantics(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: toggle,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _RingPainter(
                        metronome: metronome,
                        signature: metronome.signature,
                        frame: _ringFrame,
                        colors: theme.colorScheme,
                        beats: LowEndColors.of(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            MetronomeTempoDial(metronome: metronome),
            Center(
              child: SizedBox.square(
                dimension: geometry.hubRadius * 2,
                child: Semantics(
                  button: true,
                  label: playing ? l10n.metronomeStop : l10n.metronomeStart,
                  value:
                      '${l10n.bpmValue('${metronome.bpm}')}, '
                      '${beatUnitName(l10n, metronome.signature.beatUnit)}, '
                      '${tempoMark(metronome.signature, metronome.bpm)}',
                  onTap: toggle,
                  excludeSemantics: true,
                  child: ClipOval(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: toggle,
                        child: Center(
                          child: SizedBox.square(
                            dimension: geometry.hubSize,
                            child: ValueListenableBuilder<int>(
                              valueListenable: _hubFrame,
                              builder: (context, _, _) => FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _Hub(
                                  metronome: metronome,
                                  playing: playing,
                                ),
                              ),
                            ),
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

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.metronome,
    required this.signature,
    required ValueNotifier<int> frame,
    required this.colors,
    required this.beats,
  }) : super(repaint: frame);

  final MetronomeController metronome;

  /// The time signature drawn: kept here so that a new one repaints the ring
  /// at once, also while the metronome is stopped and nothing else does.
  final TimeSignature signature;
  final ColorScheme colors;

  /// The colours of the beats: the "one", and the ones that recede, stay
  /// silent or are weak.
  final LowEndColors beats;

  /// How fast the single segment of a one-beat bar fades.
  static double _decay(MetronomeController metronome) =>
      math.min(0.12, metronome.pulseLength.inMicroseconds / 3e6);

  /// After this long the flash is invisible: no more frames.
  static Duration flashTime(MetronomeController metronome) =>
      Duration(microseconds: (_decay(metronome) * 6e6).round());

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = TempoDialGeometry(size);
    final dial = geometry.dial;
    final beat = metronome.beat;
    final count = signature.beats;
    final slice = 2 * math.pi / count;
    // Wider gaps between the groups of a bar such as 6/8, so that it does
    // not look like 3/4 with twice the segments.
    const groupGap = 0.14;
    for (var b = 0; b < count; b++) {
      final opens = signature.grouped && signature.accent(b) < 2;
      final closes = signature.grouped && signature.accent((b + 1) % count) < 2;
      // A bar of one beat is the whole ring, with no gap.
      final whole = count == 1;
      final start = whole
          ? 0.0
          : DialGeometry.gap / 2 + (opens ? groupGap / 2 : 0);
      final end = whole
          ? 0.0
          : DialGeometry.gap / 2 + (closes ? groupGap / 2 : 0);
      // Beat 0 starts at 12 o'clock, then clockwise.
      var color = colors.outlineVariant;
      if (count == 1 && beat != null) {
        // The only segment is always "the beat": it flashes and fades.
        final since = metronome.sinceBeat ?? Duration.zero;
        final t = math.exp(-since.inMicroseconds / 1e6 / _decay(metronome));
        color = Color.lerp(colors.outlineVariant, beats.downbeat, t)!;
      } else if (b != beat) {
        // Playing, the other beats recede: only the lit one stands out.
        color = beat == null ? colors.outlineVariant : beats.beatReceded;
      } else if (metronome.isSilent(b)) {
        // A beat left silent (1 and 3, with the click on 2 and 4) only
        // glows: the place in the bar is still seen.
        color = beats.beatSilent;
      } else if (b == 0) {
        color = beats.downbeat;
      } else if (signature.grouped && !opens) {
        // The weak pulses of a group are softer than its first.
        color = beats.beatWeak;
      } else {
        // The colour of the rest of a chord in the harmony: a step softer
        // than the "one", as the chord's notes are than its root.
        color = colors.secondary;
      }
      // The lit "one" is also wider, into the ring's margins: it stands out
      // by its shape as well as by its colour.
      final one = b == 0 && b == beat && count > 1 && !metronome.isSilent(0);
      dial.paintSegment(
        canvas,
        inner: geometry.beatInner + geometry.beatWidth * (one ? 0.12 : 0.22),
        outer: geometry.beatOuter - geometry.beatWidth * (one ? 0.0 : 0.08),
        startAngle: b * slice + start,
        sweep: slice - start - end,
        color: color,
        border: colors.outline,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.metronome != metronome ||
      old.signature != signature ||
      old.colors != colors ||
      old.beats != beats;
}

/// What the hub shows: the tempo, or, while the click waits for the piano's
/// bar line, the seconds to go. Apart from the ring, so a frame of the
/// countdown repaints only this.
class _Hub extends StatelessWidget {
  const _Hub({required this.metronome, required this.playing});

  final MetronomeController metronome;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = metronome.waitLeft;
    final beats = metronome.beatsLeft;
    final waiting = beats != null && left! >= const Duration(milliseconds: 300);
    final number = waiting ? beats : metronome.bpm;
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$number',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: waiting
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        // What touching does, or the figure the tempo counts and its name:
        // "♩ Andante", "♩. Allegro · ♪ = 180" in 6/8.
        if (!waiting) ...[
          Text(
            tempoUnitCaption(metronome.signature, metronome.bpm),
            textAlign: TextAlign.center,
            // A little taller than the text: the note symbol comes from
            // another font and was clipped at the top.
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          // Stopped: the tempo keeps its name, and under it what touching
          // does.
          if (!playing)
            Text(
              l10n.metronomeHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}

/// What the tempo counts and how fast it is, under its number: "♩ Andante",
/// "♪ Allegro" in 7/8 and in the compound bars "♩. Allegro · ♪ = 180", the
/// eighths too.
String tempoUnitCaption(TimeSignature signature, int bpm) {
  final caption = '${signature.beatUnit.symbol} ${tempoMark(signature, bpm)}';
  if (!signature.compound) return caption;
  return '$caption · ${BeatUnit.eighth.symbol} = '
      '${bpm * signature.pulsesPerBeat}';
}

/// The Italian name of the tempo, the same in every language, for [bpm]
/// counted in the beat of [signature]. The limits are in quarter notes per
/// minute, so a dotted quarter or an eighth is first turned into quarters.
String tempoMark(TimeSignature signature, int bpm) {
  final quarters = switch (signature.beatUnit) {
    BeatUnit.quarter => bpm.toDouble(),
    BeatUnit.dottedQuarter => bpm * 1.5,
    BeatUnit.eighth => bpm / 2,
  };
  const limits = [
    (40, 'Grave'),
    (60, 'Largo'),
    (66, 'Larghetto'),
    (76, 'Adagio'),
    (108, 'Andante'),
    (120, 'Moderato'),
    (156, 'Allegro'),
    (176, 'Vivace'),
    (200, 'Presto'),
  ];
  for (final (limit, name) in limits) {
    if (quarters < limit) return name;
  }
  return 'Prestissimo';
}

/// The figure the tempo counts, for screen readers.
String beatUnitName(AppLocalizations l10n, BeatUnit unit) => switch (unit) {
  BeatUnit.quarter => l10n.beatUnitQuarter,
  BeatUnit.dottedQuarter => l10n.beatUnitDottedQuarter,
  BeatUnit.eighth => l10n.beatUnitEighth,
};

/// What fills each beat, the second field of the upper row: a quarter
/// note, two eighths, a triplet, four sixteenths, or the swung eighths and
/// sixteenths (softer clicks between the beats). It shows the notes and
/// opens a menu of them. Bars counted in eighths are always played plain,
/// so it is off there.
class _SubdivisionField extends StatelessWidget {
  const _SubdivisionField({required this.metronome});

  final MetronomeController metronome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subdivision = metronome.subdivision;
    final enabled = metronome.subdivisionApplies;
    return Builder(
      builder: (field) => LabeledField(
        key: const Key('subdivisionMenu'),
        label: l10n.subdivisionLabel,
        value: subdivisionName(l10n, subdivision),
        display: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          // As tall as a line of text, so that the field grows with large
          // text as the time signature beside it does.
          child: NoteIcon(
            subdivision,
            height: MediaQuery.textScalerOf(context).scale(24),
          ),
        ),
        onTap: enabled ? () => _choose(field) : null,
      ),
    );
  }

  /// The menu, opened under the field.
  Future<void> _choose(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showChoiceMenu(
      anchor: context,
      selected: metronome.subdivision,
      choices: [
        for (final s in Subdivision.values)
          Choice(
            value: s,
            title: subdivisionName(l10n, s),
            leading: SizedBox(
              width: 110,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: NoteIcon(s, height: 26),
              ),
            ),
          ),
      ],
    );
    if (picked != null) metronome.setSubdivision(picked);
  }
}

/// What fills the beat, for the menu and for screen readers.
String subdivisionName(AppLocalizations l10n, Subdivision s) => switch (s) {
  Subdivision.quarters => l10n.subdivisionQuarters,
  Subdivision.eighths => l10n.subdivisionEighths,
  Subdivision.swungEighths => l10n.subdivisionSwungEighths,
  Subdivision.triplets => l10n.subdivisionTriplets,
  Subdivision.sixteenths => l10n.subdivisionSixteenths,
  Subdivision.swungSixteenths => l10n.subdivisionSwungSixteenths,
};

/// The first field of the upper row: shows the time signature and opens the
/// list to choose another.
class _SignatureButton extends StatelessWidget {
  const _SignatureButton({required this.metronome});

  final MetronomeController metronome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signature = metronome.signature;
    // With the click on 2 and 4 the half says so: "4/4 · 2 & 4".
    final value = metronome.backbeat && metronome.backbeatApplies
        ? '${signature.label} · ${l10n.backbeatShort}'
        : signature.label;
    return Builder(
      builder: (field) => LabeledField(
        key: const Key('signatureMenu'),
        label: l10n.timeSignature,
        value: value,
        fitValue: true,
        onTap: () => _choose(field),
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<TimeSignature>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titled like the other sheets (the example songs).
              Semantics(
                header: true,
                child: Text(
                  l10n.timeSignature,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final s in TimeSignature.all)
                ListTile(
                  title: Text(s.label),
                  // How the bar is felt: 3/4 is "3", 6/8 is "3 + 3".
                  subtitle: s.grouped ? Text(s.feel) : null,
                  selected: s == metronome.signature,
                  trailing: s == metronome.signature
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(s),
                ),
              const Divider(),
              // Kept whatever the bar, and heard in 2/4 and 4/4.
              ListenableBuilder(
                listenable: metronome,
                builder: (context, _) => SwitchListTile(
                  key: const Key('backbeatSwitch'),
                  value: metronome.backbeat,
                  onChanged: metronome.setBackbeat,
                  title: Text(l10n.backbeatTitle),
                  subtitle: Text(l10n.backbeatSubtitle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) metronome.setSignature(picked);
  }
}

class _TapButton extends StatefulWidget {
  const _TapButton({required this.metronome});

  final MetronomeController metronome;

  @override
  State<_TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<_TapButton> {
  final _clock = Stopwatch()..start();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void tap() {
      HapticFeedback.lightImpact();
      widget.metronome.tap(_clock.elapsed);
    }

    return Semantics(
      label: l10n.tapTempo,
      button: true,
      excludeSemantics: true,
      // A screen reader's double tap counts as one tap.
      onTap: tap,
      child: Listener(
        // On touch down, not on release: the tap lands with the hand.
        onPointerDown: (_) => tap(),
        // As wide as the room it is given (half the row): the chip itself
        // only takes the width of its label.
        child: LayoutBuilder(
          builder: (context, box) => RowButton(
            // The tap is counted by the Listener; this only shows the ripple.
            onPressed: () {},
            // Coloured: the one chip of the row that is a button to press.
            filled: true,
            label: SizedBox(
              // Less the button's own padding.
              width: math.max(0, box.maxWidth - rowButtonInset),
              child: Center(
                child: Text(
                  'TAP',
                  style: rowButtonStyle(
                    context,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )?.copyWith(letterSpacing: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
