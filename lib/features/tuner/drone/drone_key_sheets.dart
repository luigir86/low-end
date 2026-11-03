import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../audio/audio_scope.dart';
import '../../../audio/pitch.dart';
import '../../../l10n/app_localizations.dart';
import '../../metronome/time_signature.dart';
import 'drone_controller.dart';
import 'drone_panel.dart';
import 'example_song.dart';
import 'harmony.dart';

/// The key written out: "La maggiore", "C minor", spelled as the key is
/// (D♭ major, not C♯).
String keyName(AppLocalizations l10n, DroneController drone, NoteNames names) {
  final tonic = spell(drone.note.pitchClass, drone.keyLetter, names);
  return drone.keyIsMinor
      ? l10n.droneChordMinor(tonic)
      : l10n.droneChordMajor(tonic);
}

/// A progression by its numerals, or the name of the blues, which is too long
/// to list (the key says whether it is minor): "II–V–I", "Blues".
String progressionShort(AppLocalizations l10n, Progression p) => switch (p) {
  Progression.minorTwoFiveOne => 'II–V–I',
  Progression.blues || Progression.minorBlues => l10n.progressionBluesShort,
  _ => progressionName(l10n, p),
};

/// "II–V–I in La maggiore": what is being practised, and in which key.
String keyLine(AppLocalizations l10n, DroneController drone, NoteNames names) =>
    l10n.keyLine(
      progressionShort(l10n, drone.progression),
      keyName(l10n, drone, names),
    );

/// The name of a degree of the scale, [degree] 0 for the tonic.
String degreeName(AppLocalizations l10n, int degree, {bool minor = false}) =>
    switch (degree) {
      0 => l10n.degreeName1,
      1 => l10n.degreeName2,
      2 => l10n.degreeName3,
      3 => l10n.degreeName4,
      4 => l10n.degreeName5,
      5 => l10n.degreeName6,
      _ => minor ? l10n.degreeName7Minor : l10n.degreeName7,
    };

/// Tells what a Roman numeral on the circle stands for, and what the colours
/// and dots mean. With [numeral] (the one touched) its row is marked.
Future<void> showKeySheet(BuildContext context, {String? numeral}) {
  final scope = AudioScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: Listenable.merge([scope.drone, scope.settings]),
          builder: (context, _) => _KeySheet(
            drone: scope.drone,
            names: scope.settings.noteNames(Localizations.localeOf(context)),
            numeral: numeral,
          ),
        ),
      ),
    ),
  );
}

class _KeySheet extends StatelessWidget {
  const _KeySheet({
    required this.drone,
    required this.names,
    required this.numeral,
  });

  final DroneController drone;
  final NoteNames names;
  final String? numeral;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final disc = LowEndColors.of(context).disc;
    final showsKey = drone.showsKey;
    // Each chord once, in the order of the progression: VI twice in the
    // circle of fifths, as Am7 and as the A7 that turns it around.
    final seen = <(String, ChordQuality)>{};
    final steps = [
      for (final s in drone.progression.steps)
        if (seen.add((s.numeral, s.quality))) s,
    ];
    Widget heading(String text) => Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(color: colors.primary),
        ),
      ),
    );
    Widget swatch(Color fill, String text, {Color? border}) => ListTile(
      dense: true,
      leading: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: border == null ? null : Border.all(color: border, width: 1.2),
        ),
      ),
      title: Text(text),
    );
    Widget note(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showsKey) ...[
          heading(l10n.keySheetTitle(keyName(l10n, drone, names))),
          for (final s in steps)
            ListTile(
              // The second chord on a numeral (A7 after Am7) adds its kind.
              key: ValueKey(
                steps.indexWhere((o) => o.numeral == s.numeral) ==
                        steps.indexOf(s)
                    ? 'degree-${s.numeral}'
                    : 'degree-${s.numeral}-${s.quality.name}',
              ),
              selected: s.numeral == numeral,
              leading: SizedBox(
                width: 40,
                child: Text(
                  s.numeral,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(degreeName(l10n, s.degree, minor: drone.keyIsMinor)),
              subtitle: Text(
                chordSymbol(
                  l10n,
                  (
                    root: (drone.note.pitchClass + s.offset) % 12,
                    quality: s.quality,
                  ),
                  spell(
                    (drone.note.pitchClass + s.offset) % 12,
                    (drone.keyLetter + s.degree) % 7,
                    names,
                  ),
                ),
              ),
            ),
        ],
        heading(l10n.legendTitle),
        swatch(colors.primary, l10n.legendRoot),
        swatch(colors.secondary, l10n.legendChord),
        swatch(colors.outlineVariant, l10n.legendInKey, border: colors.outline),
        swatch(Color.lerp(disc, colors.surface, 0.6)!, l10n.legendOutOfKey),
        note(l10n.legendNumerals),
        note(l10n.legendDots),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// The list of example songs; choosing one applies it and closes the list.
Future<void> showSongsSheet(BuildContext context) {
  final scope = AudioScope.of(context);
  // A jazz standard may be chosen: its double bass is read meanwhile.
  scope.drone.prepareBass();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final l10n = AppLocalizations.of(sheet);
      final names = scope.settings.noteNames(Localizations.localeOf(sheet));
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.songsTitle,
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l10n.songsSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheet).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(sheet).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final (i, song) in exampleSongs.indexed) ...[
                // The sections of the progression menu, in the same order.
                if (i == 0 ||
                    exampleSongs[i - 1].progression.section !=
                        song.progression.section) ...[
                  if (i > 0) const Divider(),
                  _SongSection(
                    progressionSectionName(l10n, song.progression.section),
                  ),
                ],
                ListTile(
                  key: ValueKey('song-${song.title}'),
                  title: Text(song.title),
                  // Who made it known, then what it sets.
                  isThreeLine: true,
                  subtitle: Text(
                    '${song.artist}\n'
                    '${progressionShort(l10n, song.progression)} · '
                    '${_songKey(l10n, song, names)} · '
                    '${BeatUnit.quarter.symbol} = ${song.bpm}',
                  ),
                  // A jazz standard starts on the walking bass.
                  trailing: song.walking
                      ? Icon(
                          Icons.directions_walk,
                          semanticLabel: l10n.styleWalking,
                        )
                      : null,
                  onTap: () {
                    applySong(
                      song,
                      drone: scope.drone,
                      metronome: scope.metronome,
                    );
                    Navigator.of(sheet).pop();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

String _songKey(AppLocalizations l10n, ExampleSong song, NoteNames names) {
  final tonic = Note(song.pitchClass, 4).name(names);
  return song.progression.minor
      ? l10n.droneChordMinor(tonic)
      : l10n.droneChordMajor(tonic);
}

/// The entry added at the end of the sound options: the legend. [panel] is
/// the context of the harmony tab, which outlives the options sheet that it
/// closes.
class LegendTile extends StatelessWidget {
  const LegendTile({super.key, required this.panel});

  final BuildContext panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.legendButton),
          onTap: () {
            Navigator.of(context).pop();
            if (panel.mounted) showKeySheet(panel);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The heading of a section of the example songs, as in the progression
/// menu: small muted words, announced as a heading.
class _SongSection extends StatelessWidget {
  const _SongSection(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
