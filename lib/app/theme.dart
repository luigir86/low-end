import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'style.dart';

/// Low End's look, in one place: change a colour, a radius or a font weight
/// here and every screen follows, like the variables of a CSS stylesheet.
///
/// Two internal palettes, selected at build time without a user setting.
enum LowEndThemeVariant { woodAndBrass, anthraciteAndRed }

abstract final class Palette {
  /// The accent: the honey bronze of the lion on the icon.
  static const bronze = Color(0xFFD4A373);

  // The ground, from the darkest up.
  static const ebony = Color(0xFF141312);
  static const ebonyShade1 = Color(0xFF1C1B19);
  static const ebonyShade2 = Color(0xFF262422);
  static const ebonyShade3 = Color(0xFF312F2C);
  static const walnutDeep = Color(0xFF2B1D16);

  /// Shared pre-Flutter background on Android and web.
  static const startup = Color(0xFF181818);

  // Text.
  static const inkOnLight = Color(0xFF1E1C1A);
  static const inkOnDark = Color(0xFFEFEDEA);
  static const inkOnDarkMuted = Color(0xFFC9C5BF);

  // Tuner verdicts: green, amber and a pure red, told apart from the bronze
  // by their hue, so a verdict never reads as the app's own colour. The
  // green leans to teal: a player who cannot tell red from green
  // (protanopia, deuteranopia) sees it as a pale grey, not as a beige
  // next to the bronze and the yellow.
  static const inTune = Color(0xFF5FD7C8);
  static const close = Color(0xFFF2DA4E);
  static const off = Color(0xFFFF5F56);
}

/// Colours the Material …13944 tokens truncated…                 ? l10n.noteAlone
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

/// The picture of a line: the piano's chord written as in a score (whole
/// notes held a bar, quarter notes on every beat, quarter notes one after
/// the other for the arpeggio), footprints for the walking bass, a wave for
/// the held tone.
Widget _styleIcon(_StyleLine line) => switch (line) {
  _StyleLine.held => const StyleIcon(StyleGlyph.heldChord),
  _StyleLine.beat => const StyleIcon(StyleGlyph.struckChord),
  _StyleLine.arpeggio => const StyleIcon(StyleGlyph.arpeggio),
  _StyleLine.walking => const StyleIcon(StyleGlyph.footprints),
  _StyleLine.tone => const StyleIcon(StyleGlyph.wave),
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
