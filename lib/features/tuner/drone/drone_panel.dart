import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/settings.dart';
import '../../../app/style.dart';
import '../../../widgets/row_controls.dart';
import '../../../app/theme.dart';
import '../../../audio/audio_scope.dart';
import '../../../audio/pitch.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/choice_menu.dart';
import '../../../widgets/dial.dart';
import '../../../widgets/style_icons.dart';
import '../../../widgets/page_dots.dart';
import 'drone_controller.dart';
import 'drone_key_sheets.dart';
import 'harmony.dart';

/// The twelve notes in circle-of-fifths order, C at the top and clockwise:
/// each step is a fifth up, so the neighbours of a key are its closest
/// relatives.
const circleOfFifths = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5];

/// The same twelve notes in semitones, C at the top: the order of the frets.
const chromaticCircle = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

/// The notes round the dial, clockwise from the top, as the player chose.
List<int> circleOrder(CircleLayout layout) => switch (layout) {
  CircleLayout.fifths => circleOfFifths,
  CircleLayout.chromatic => chromaticCircle,
};

/// The drone: the twelve notes as segments of the dial, round the circle of
/// fifths. Touching a segment plays that note and keeps it lit; touching
/// another switches to it; touching the lit one again stops it.
class DronePanel extends StatelessWidget {
  const DronePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AudioScope.of(context);
    final drone = scope.drone;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([drone, scope.settings]),
      builder: (context, _) {
        final names = scope.settings.noteNames(Localizations.localeOf(context));
        return DialLayout(
          dial: _FifthsDial(
            drone: drone,
            names: names,
            order: circleOrder(scope.settings.circleLayout),
          ),
          upper: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VoicingSwitch(drone: drone),
              if (drone.audioFailed)
                Semantics(
                  liveRegion: true,
                  // In a browser it is almost always a download that failed.
                  child: Text(
                    kIsWeb ? l10n.audioDownloadFailed : l10n.audioUnavailable,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
          lower: _ChordMenu(drone: drone),
        );
      },
    );
  }
}

class _FifthsDial extends StatelessWidget {
  const _FifthsDial({
    required this.drone,
    required this.names,
    required this.order,
  });

  final DroneController drone;
  final NoteNames names;
  final List<int> order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final playing = drone.isPlaying ? drone.rootPitchClass : null;
    // The rest of the chord, lit in a second colour while it sounds.
    final chord = drone.isPlaying ? drone.chordTones : const <int>{};
    // With a progression selected: the key's seven notes in front of the
    // rest.
    final tonic = drone.showsKey ? drone.note.pitchClass : null;
    final keyNotes = drone.keyNotes;
    // The notes that recede into the disc, still there to be touched: out of
    // the key in a progression; otherwise, while it sounds, all but those
    // sounding, so that a lit note always means one heard.
    final receding = <int>{
      for (var pc = 0; pc < 12; pc++)
        if (keyNotes.isNotEmpty
            ? !keyNotes.contains(pc)
            : playing != null && pc != playing && !chord.contains(pc))
          pc,
    };
    // The Roman numerals of the progression, written small on the notes
    // they stand on, and not moving: you read II, then go to V.
    final degrees = drone.degreeLabels;
    // A note in the key is written as the key writes it (C♭ in G♭ major);
    // one out of the key but in the chord sounding, as the chord writes it
    // in the hub (D♯ in B7, G♭ in A♭7); the others as chosen, and a hold on
    // C♯ or F♯ writes them the other way.
    final sounding = drone.isPlaying ? drone.currentChord : null;
    final chordSpelling = sounding == null
        ? const <int, String>{}
        : {
            for (final (i, name) in _chordNotes(
              sounding,
              drone.rootLetter,
              names,
            ).indexed)
              (sounding.root +
                          (i == 0 ? 0 : sounding.quality.semitones[i - 1])) %
                      12:
                  name,
          };
    String nameOf(int pc, {bool flat = false}) {
      final letter = drone.keyLetterOf(pc);
      return letter != null
          ? spell(pc, letter, names)
          : chordSpelling[pc] ?? Note(pc, drone.octave).name(names, flat: flat);
    }

    bool canRespell(int pc) =>
        DroneController.respellable.contains(pc) &&
        (drone.keyLetterOf(pc) == null || pc == tonic);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // For a frame the dial can get almost no room (for instance while
        // the app rebuilds after a language change): draw nothing then.
        if (size.shortestSide < 120) return const SizedBox.shrink();
        final dial = DialGeometry(size);
        // A touch area per note, as wide as the ring is thick.
        final key = math.max(48.0, dial.ringWidth);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FifthsPainter(
                  order: order,
                  playing: playing,
                  chord: chord,
                  receding: receding,
                  colors: theme.colorScheme,
                  disc: LowEndColors.of(context).disc,
                ),
              ),
            ),
            for (var i = 0; i < 12; i++)
              Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: dial.ringPoint(i * math.pi / 6),
                  width: key,
                  height: key,
                ),
                child: _NoteKey(
                  name: nameOf(order[i], flat: drone.spelledFlat(order[i])),
                  playing: playing == order[i],
                  inChord: chord.contains(order[i]),
                  degree: degrees[order[i]],
                  // Touching the numeral says what the degree is.
                  onDegreeTap: (numeral) =>
                      showKeySheet(context, numeral: numeral),
                  receding: receding.contains(order[i]),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    drone.tapNote(order[i]);
                  },
                  // C♯ or D♭, F♯ or G♭: the other name is written small
                  // under it, and holding the key switches to it, with the
                  // chords of its key.
                  respelling: canRespell(order[i])
                      ? Note(
                          order[i],
                          drone.octave,
                        ).name(names, flat: !drone.spelledFlat(order[i]))
                      : null,
                  onLongPress: () => drone.toggleSpelling(order[i]),
                ),
              ),
            // What is sounding, in the hub; large text shrinks to fit.
            // Touching the hub stops the drone, or plays the last note
            // again, like the metronome's ring.
            Center(
              child: SizedBox.square(
                dimension: dial.hub * 2,
                child: Semantics(
                  button: true,
                  label: drone.isPlaying
                      ? l10n.droneStop
                      : l10n.playSound(
                          spell(drone.note.pitchClass, drone.keyLetter, names),
                        ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        drone.toggle();
                      },
                      child: Center(
                        child: SizedBox.square(
                          dimension: dial.hub * math.sqrt2,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: dial.hub * math.sqrt2,
                              child: _DialCenter(drone: drone, names: names),
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

/// The ring of twelve segments: the root playing lit, the rest of a chord
/// in a second colour. The Roman numerals of a progression are written on
/// the keys themselves ([_NoteKey]), not painted here.
class _FifthsPainter extends CustomPainter {
  _FifthsPainter({
    required this.order,
    required this.playing,
    required this.chord,
    required this.receding,
    required this.colors,
    required this.disc,
  });

  final List<int> order;
  final int? playing;
  final Set<int> chord;

  /// The notes that recede into the disc (still there to be touched).
  final Set<int> receding;
  final ColorScheme colors;
  final Color disc;

  @override
  void paint(Canvas canvas, Size size) {
    final dial = DialGeometry(size);
    const step = math.pi / 6;
    for (var i = 0; i < 12; i++) {
      final pc = order[i];
      final lit = playing == pc;
      final inChord = chord.contains(pc);
      final recedes = receding.contains(pc);
      final start = i * step - step / 2 + DialGeometry.gap / 2;
      const sweep = step - DialGeometry.gap;
      dial.paintSegment(
        canvas,
        startAngle: start,
        sweep: sweep,
        color: lit
            ? colors.primary
            : inChord
            ? colors.secondary
            : recedes
            ? Color.lerp(disc, colors.surface, 0.6)!
            : colors.outlineVariant,
        border: colors.outline,
      );
    }
  }

  @override
  bool shouldRepaint(_FifthsPainter old) =>
      !listEquals(old.order, order) ||
      old.playing != playing ||
      !setEquals(old.chord, chord) ||
      !setEquals(old.receding, receding) ||
      old.colors != colors ||
      old.disc != disc;
}

/// The touch area and label of one segment; the segment itself is painted
/// by [_FifthsPainter].
class _NoteKey extends StatelessWidget {
  const _NoteKey({
    required this.name,
    required this.playing,
    required this.inChord,
    required this.degree,
    required this.onDegreeTap,
    required this.receding,
    required this.onTap,
    required this.respelling,
    required this.onLongPress,
  });

  final String name;
  final bool playing;

  /// The note recedes: out of the key shown, or not sounding while others
  /// do.
  final bool receding;

  /// Sounding as part of the chord built on the note playing.
  final bool inChord;
  final VoidCallback onTap;

  /// The Roman numeral of the progression on this note ("V"), or null.
  final String? degree;

  /// Called with the numeral when it is touched, rather than the note.
  final void Function(String numeral) onDegreeTap;

  /// The other way to write the note (D♭ for C♯), or null if there is none.
  final String? respelling;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final respelling = this.respelling;
    return Semantics(
      button: true,
      selected: playing,
      // Says what a touch will do, not just the note name.
      label: playing ? l10n.stopSound(name) : l10n.playSound(name),
      onLongPressHint: respelling == null ? null : l10n.writeAs(respelling),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: respelling == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onLongPress();
                },
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The function in the progression, small and still, on
                    // the line of the note: a line of its own made the label
                    // taller than the key on a narrow phone.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (degree != null) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onDegreeTap(degree!),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 4,
                              ),
                              child: Text(
                                degree!,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: playing
                                      ? colors.onPrimary
                                      : inChord
                                      ? colors.onSecondary
                                      : colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: playing
                                ? colors.onPrimary
                                : inChord
                                ? colors.onSecondary
                                : receding
                                ? colors.onSurfaceVariant
                                : colors.onSurface,
                            // Bold for the root, so it stands out by more
                            // than colour alone.
                            fontWeight: playing
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    // The other way to write it, small: F♯ over G♭.
                    if (respelling != null)
                      Text(
                        respelling,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: playing
                              ? colors.onPrimary
                              : inChord
                              ? colors.onSecondary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the hub says: the hint, or what sounds, or, while the piano waits for
/// the metronome's bar line, the seconds to go (as on the metronome).
class _DialCenter extends StatefulWidget {
  const _DialCenter({required this.drone, required this.names});

  final DroneController drone;
  final NoteNames names;

  @override
  State<_DialCenter> createState() => _DialCenterState();
}

class _DialCenterState extends State<_DialCenter> {
  /// Redraws the countdown, only while there is one.
  Timer? _timer;

  DroneController get drone => widget.drone;
  NoteNames get names => widget.names;

  void _sync(bool waiting) {
    if (waiting && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        if (drone.waitLeft == null) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
    } else if (!waiting) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // In a progression, the key in words: "II–V–I in La maggiore".
    final keyText = drone.showsKey ? keyLine(l10n, drone, names) : null;
    if (!drone.isPlaying) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (keyText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                keyText,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          Text(l10n.droneHint, textAlign: TextAlign.center, style: muted),
        ],
      );
    }
    // The note in the ink of the text, as on the other dials: the tab's
    // colour is on the ring.
    final noteStyle = theme.textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    final root = Note(drone.rootPitchClass, drone.octave);
    // Spelled as in the key: D♯ in C♯ minor, G♭ in D♭.
    final rootName = spell(root.pitchClass, drone.rootLetter, names);
    final chord = drone.currentChord;
    // Waiting for a bar line (the metronome's, or the loop's own while the
    // old one fades): the beats to go, in the muted ink, and under them what
    // is about to come in.
    final left = drone.waitLeft;
    final beats = drone.beatsLeft;
    final waiting = beats != null && left! >= const Duration(milliseconds: 300);
    _sync(left != null);
    if (waiting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$beats',
            style: noteStyle?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            chord != null ? chordSymbol(l10n, chord, rootName) : rootName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ],
      );
    }
    // Touched, and not yet heard: the recordings (in a browser the audio
    // engine too) are still being read or downloaded. Something turns, and
    // says what is happening, so that the wait does not look like a fault.
    if (drone.showsWait) {
      return Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text(
              chord != null ? chordSymbol(l10n, chord, rootName) : rootName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              kIsWeb && drone.startsSlowly
                  ? l10n.soundsDownloadingSlowly
                  : l10n.soundsPreparing,
              textAlign: TextAlign.center,
              style: muted,
            ),
          ],
        ),
      );
    }
    final inProgression = drone.voicing == DroneVoicing.progression;
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: rootName),
                TextSpan(
                  text:
                      '${root.octaveIn(names, numbering: AudioScope.of(context).settings.octaveNumbering)}',
                  style: LowEndType.octave(noteStyle),
                ),
              ],
            ),
            style: noteStyle,
            textAlign: TextAlign.center,
          ),
          if (chord != null)
            Text(
              chordSymbol(l10n, chord, rootName),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          // The chord written out: Si Re Fa♯. Its root's frequency would
          // mislead, so the hertz are only for a note alone.
          if (chord != null)
            Text(
              _chordNotes(chord, drone.rootLetter, names).join(' '),
              textAlign: TextAlign.center,
              style: muted,
            )
          else
            Text(
              l10n.frequencyHz(drone.frequency.toStringAsFixed(1)),
              style: muted,
            ),
          if (inProgression) ...[
            if (keyText != null)
              Text(keyText, textAlign: TextAlign.center, style: muted),
            const SizedBox(height: 6),
            PageDots(
              count: drone.progression.steps.length,
              current: drone.step,
              // Twelve bars of blues need smaller dots to fit.
              size: drone.progression.steps.length > 6 ? 7 : 10,
            ),
          ],
        ],
      ),
    );
  }
}

/// The name of a kind of chord, as listed in the chord menu.
String chordName(AppLocalizations l10n, ChordQuality chord) => switch (chord) {
  ChordQuality.major => l10n.chordMajor,
  ChordQuality.minor => l10n.chordMinor,
  ChordQuality.dominant => l10n.chordDominant,
  ChordQuality.dominantFlat9 => l10n.chordDominantFlat9,
  ChordQuality.major7 => l10n.chordMajor7,
  ChordQuality.minor7 => l10n.chordMinor7,
  ChordQuality.halfDiminished => l10n.chordHalfDiminished,
  ChordQuality.diminished => l10n.chordDiminished,
  ChordQuality.sus4 => l10n.chordSus4,
};

/// A chord on [note], as musicians write it: "A major", "La minore", "A7",
/// "Rem7", "Domaj7".
String chordSymbol(AppLocalizations l10n, DroneChord chord, String note) =>
    switch (chord.quality) {
      ChordQuality.major => l10n.droneChordMajor(note),
      ChordQuality.minor => l10n.droneChordMinor(note),
      ChordQuality.dominant => l10n.droneChordSeventh(note),
      ChordQuality.dominantFlat9 => '${note}7♭9',
      ChordQuality.major7 => '${note}maj7',
      ChordQuality.minor7 => '${note}m7',
      ChordQuality.halfDiminished => l10n.droneChordHalfDiminished(note),
      ChordQuality.diminished => l10n.droneChordDiminished(note),
      ChordQuality.sus4 => '${note}sus4',
    };

/// The name of a progression, as listed in its menu.
String progressionName(AppLocalizations l10n, Progression p) => switch (p) {
  Progression.twoFiveOne => 'II–V–I',
  Progression.minorTwoFiveOne => l10n.progressionMinorTwoFiveOne,
  Progression.circleOfFifths => l10n.progressionCircleOfFifths,
  Progression.oneSixTwoFive => 'I–VI–II–V',
  Progression.blues => l10n.progressionBlues,
  Progression.minorBlues => l10n.progressionMinorBlues,
  Progression.oneSixFourFive => 'I–VI–IV–V',
  Progression.oneFiveSixFour => 'I–V–VI–IV',
  Progression.andalusian => 'I–♭VII–♭VI–V',
};

/// The well-known song a progression is named after in the menu.
String progressionSong(Progression p) => switch (p) {
  Progression.twoFiveOne => 'Tune Up',
  Progression.minorTwoFiveOne => 'Blue Bossa',
  Progression.circleOfFifths => 'Autumn Leaves',
  Progression.oneSixTwoFive => 'I Got Rhythm',
  Progression.blues => 'Sweet Home Chicago',
  Progression.minorBlues => 'Mr. P.C.',
  Progression.oneSixFourFive => 'Stand by Me',
  Progression.oneFiveSixFour => 'With or Without You',
  Progression.andalusian => 'Hit the Road Jack',
};

/// The heading of a section of the progression menu.
String progressionSectionName(AppLocalizations l10n, ProgressionSection s) =>
    switch (s) {
      ProgressionSection.popRock => l10n.progressionSectionPopRock,
      ProgressionSection.blues => l10n.progressionSectionBlues,
      ProgressionSection.jazz => l10n.progressionSectionJazz,
    };

/// The line under the name in the menu: "Like With or Without You"; for I–VI–IV–V,
/// I–♭VII–♭VI–V and I–VI–II–V also their common names, the "giro di Do" of
/// Italian musicians, the Andalusian cadence and the Anatole of jazz
/// musicians.
String progressionNote(AppLocalizations l10n, Progression p) => switch (p) {
  Progression.oneSixFourFive => l10n.progressionGiroLike(progressionSong(p)),
  Progression.andalusian => l10n.progressionAndalusianLike(progressionSong(p)),
  Progression.oneSixTwoFive => l10n.progressionAnatoleLike(progressionSong(p)),
  _ => l10n.progressionLike(progressionSong(p)),
};

/// Chord (the note alone being one of them) or Progression, full width, as
/// tall as the other sections' first row.
class _VoicingSwitch extends StatelessWidget {
  const _VoicingSwitch({required this.drone});

  final DroneController drone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progression = drone.voicing == DroneVoicing.progression;
    // A field like the metronome's and the tuner's first row.
    return Builder(
      builder: (field) => LabeledField(
        key: const Key('voicingMenu'),
        label: l10n.voicingLabel,
        value: progression ? l10n.progressionLabel : l10n.chordLabel,
        onTap: () async {
          final p = await showChoiceMenu<bool>(
            anchor: field,
            selected: progression,
            choices: [
              Choice(
                value: false,
                title: l10n.chordLabel,
                subtitle: l10n.voicingChordHint,
              ),
              Choice(
                value: true,
                title: l10n.progressionLabel,
                subtitle: l10n.voicingProgressionHint,
              ),
            ],
          );
          if (p == null) return;
          // Back from a progression, the note alone or the chord last chosen.
          drone.setVoicing(p ? DroneVoicing.progression : drone.chordVoicing);
        },
      ),
    );
  }
}

/// What the chord menu offers: the note alone, or a chord built on it.
typedef _ChordChoice = ({DroneVoicing voicing, ChordQuality? quality});

/// Which chord (the note alone first) or which progression; the button for
/// the sound options beside it, and before a progression the example songs.
class _ChordMenu extends StatelessWidget {
  const _ChordMenu({required this.drone});

  final DroneController drone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const _ChordChoice alone = (voicing: DroneVoicing.root, quality: null);
    final _ChordChoice current = drone.voicing == DroneVoicing.chord
        ? (voicing: DroneVoicing.chord, quality: drone.chord)
        : alone;
    final inProgression = drone.voicing == DroneVoicing.progression;
    return Row(
      children: [
        // The example songs set the key, the progression and the tempo:
        // in sight beside the progressions, not inside the options.
        if (inProgression)
          RowIconButton(
            key: const Key('songsButton'),
            icon: Icons.library_music_outlined,
            tooltip: l10n.songsTitle,
            leads: true,
            onPressed: () => showSongsSheet(context),
          ),
        Expanded(
          // The field shows just the name once chosen (the song would not
          // fit); the menu lists it with its note under it.
          child: Builder(
            builder: (field) => inProgression
                ? LabeledField(
                    key: const Key('progressionMenu'),
                    label: l10n.progressionLabel,
                    // The switch above already names it.
                    showLabel: false,
                    value: progressionName(l10n, drone.progression),
                    onTap: () async {
                      final p = await showChoiceMenu(
                        anchor: field,
                        selected: drone.progression,
                        choices: [
                          for (final p in Progression.values)
                            Choice(
                              value: p,
                              title: progressionName(l10n, p),
                              subtitle: progressionNote(l10n, p),
                              section: progressionSectionName(l10n, p.section),
                            ),
                        ],
                      );
                      if (p != null) drone.setProgression(p);
                    },
                  )
                : LabeledField(
                    key: const Key('chordMenu'),
                    label: l10n.chordLabel,
                    // The switch above already names it.
                    showLabel: false,
                    value: current.quality == null
                        ? l10n.noteAlone
                        : chordName(l10n, current.quality!),
                    onTap: () async {
                      final c = await showChoiceMenu<_ChordChoice>(
                        anchor: field,
                        selected: current,
                        choices: [
                          Choice(value: alone, title: l10n.noteAlone),
                          for (final q in ChordQuality.values)
                            Choice(
                              value: (voicing: DroneVoicing.chord, quality: q),
                              title: chordName(l10n, q),
                            ),
                        ],
                      );
                      if (c == null) return;
                      if (c.quality case final q?) drone.setChord(q);
                      drone.setVoicing(c.voicing);
                    },
                  ),
          ),
        ),
        _StyleButton(drone: drone),
      ],
    );
  }
}

/// The lines of the style menu: the four ways the piano plays, at the
/// metronome's tempo, then the held tone and, apart, the legend.
enum _StyleLine {
  held(DroneStyle.held),
  beat(DroneStyle.beat),
  arpeggio(DroneStyle.arpeggio),
  walking(DroneStyle.walking),
  tone(null),
  legend(null);

  const _StyleLine(this.piano);

  /// The style of the piano, null for the held tone and the legend.
  final DroneStyle? piano;

  /// The line of what Harmony plays now.
  static _StyleLine of(DroneController drone) =>
      drone.usesPiano ? values.firstWhere((l) => l.piano == drone.style) : tone;
}

/// The picture of a line: a long line for the chord held a bar, strokes for
/// the beats, a climb for the arpeggio, footprints for the walking bass, a
/// wave for the held tone.
Widget _styleIcon(_StyleLine line) => switch (line) {
  _StyleLine.held => const Icon(Icons.horizontal_rule),
  _StyleLine.beat => const StyleIcon(StyleGlyph.beats),
  _StyleLine.arpeggio => const Icon(Icons.trending_up),
  _StyleLine.walking => const StyleIcon(StyleGlyph.footprints),
  _StyleLine.tone => const Icon(Icons.waves),
  _StyleLine.legend => const Icon(Icons.info_outline),
};

String _styleName(AppLocalizations l10n, _StyleLine line) => switch (line) {
  _StyleLine.held => l10n.styleHeld,
  _StyleLine.beat => l10n.styleBeat,
  _StyleLine.arpeggio => l10n.styleArpeggio,
  _StyleLine.walking => l10n.styleWalking,
  _StyleLine.tone => l10n.continuousToneTitle,
  _StyleLine.legend => l10n.legendButton,
};

/// The button at the end of the chord row: the picture of the style
/// playing, so that it is in sight, and under it the menu of the styles.
/// The screen reader hears its name ("Style: Walking bass").
class _StyleButton extends StatelessWidget {
  const _StyleButton({required this.drone});

  final DroneController drone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metronome = AudioScope.of(context).metronome;
    final current = _StyleLine.of(drone);
    return Builder(
      builder: (button) => RowIconButton(
        key: const Key('styleButton'),
        picture: _styleIcon(current),
        tooltip: l10n.styleButton(_styleName(l10n, current)),
        onPressed: () async {
          // The piano keeps the metronome's time, wherever it is set: said
          // over its four styles.
          final tempo = l10n.styleTempo(
            '${metronome.signature.beatUnit.symbol} = ${metronome.bpm}',
            metronome.signature.label,
          );
          final line = await showChoiceMenu<_StyleLine>(
            anchor: button,
            selected: current,
            choices: [
              for (final l in _StyleLine.values)
                if (l.piano == null || drone.hasPiano)
                  Choice(
                    value: l,
                    title: _styleName(l10n, l),
                    subtitle: l == _StyleLine.tone
                        ? l10n.continuousToneSubtitle
                        : null,
                    leading: _styleIcon(l),
                    section: l.piano != null ? tempo : null,
                    // The held tone after the piano, the legend after all.
                    divided:
                        l == _StyleLine.legend ||
                        (l == _StyleLine.tone && drone.hasPiano),
                  ),
            ],
          );
          if (line == null) return;
          if (line == _StyleLine.legend) {
            if (context.mounted) unawaited(showKeySheet(context));
            return;
          }
          if (line.piano case final piano?) drone.setStyle(piano);
          drone.setContinuous(line == _StyleLine.tone);
        },
      ),
    );
  }
}

/// The notes of [chord], root first, spelled by thirds from the letter of the
/// root: C E G, D♭ F A♭.
List<String> _chordNotes(DroneChord chord, int rootLetter, NoteNames names) => [
  spell(chord.root, rootLetter, names),
  for (final (i, s) in chord.quality.semitones.indexed)
    spell(
      (chord.root + s) % 12,
      (rootLetter + chord.quality.letterSteps[i]) % 7,
      names,
    ),
];

/// The picture of a piano style, the same as in the style menu: what the
/// example songs show beside the style they set.
Widget styleIconOf(DroneStyle style) =>
    _styleIcon(_StyleLine.values.firstWhere((l) => l.piano == style));

/// The name of a piano style, as in the style menu.
String styleNameOf(AppLocalizations l10n, DroneStyle style) =>
    _styleName(l10n, _StyleLine.values.firstWhere((l) => l.piano == style));
