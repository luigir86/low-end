import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../audio/audio_scope.dart';
import '../../audio/pitch.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/section_icons.dart';
import '../metronome/time_signature.dart';
import 'drone_controller.dart';
import 'drone_panel.dart';
import '../songs/example_song.dart';
import 'harmony.dart';
import 'harmony_names.dart';

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
          heading(l10n.keySheetTitle(keyName(drone, names))),
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
                  (
                    root: (drone.note.pitchClass + s.offset) % 12,
                    quality: s.quality,
                  ),
                  spell(
                    (drone.note.pitchClass + s.offset) % 12,
                    (drone.keyLetter + s.degree) % 7,
                    names,
                  ),
                  names,
                ),
              ),
            ),
        ],
        heading(l10n.legendTitle),
        swatch(
          LowEndColors.of(context).activeFill,
          l10n.legendRoot,
          border: colors.outline,
        ),
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
                  // Who made it known, the harmony, then the preset: the
                  // metronome's tempo and the piano's style, with the
                  // pictures of the metronome's tab and of the style menu.
                  isThreeLine: true,
                  subtitle: _SongPreset(song: song, names: names),
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

/// What a song sets, under its title: who made it known, its progression
/// and key, then its tempo beside the metronome and its style beside the
/// picture the style menu shows for it.
class _SongPreset extends StatelessWidget {
  const _SongPreset({required this.song, required this.names});

  final ExampleSong song;
  final NoteNames names;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    final size = (style?.fontSize ?? 14) * 1.3;
    // The time signature, only when it is not the usual 4/4: "2/4 · ♩ = 160".
    final s = song.signature;
    final meter = s == TimeSignature.fourFour ? '' : '${s.label} · ';
    WidgetSpan picture(Widget icon) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: IconTheme.merge(
          data: IconThemeData(
            size: size,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          child: icon,
        ),
      ),
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text:
                '${song.artist}\n'
                '${progressionShort(l10n, song.progression)} · '
                '${_songKey(song, names)}\n',
          ),
          picture(const SectionIcon(SectionGlyph.metronome)),
          TextSpan(text: '$meter${s.beatUnit.symbol} = ${song.bpm}'),
          const WidgetSpan(child: SizedBox(width: 16)),
          picture(styleIconOf(song.style)),
          TextSpan(text: styleNameOf(l10n, song.style)),
        ],
      ),
      maxLines: 3,
    );
  }
}

String _songKey(ExampleSong song, NoteNames names) {
  final tonic = Note(song.pitchClass, 4).name(names);
  final words = chordWords(names);
  return song.progression.minor
      ? words.droneChordMinor(tonic)
      : words.droneChordMajor(tonic);
}

/// The heading of a section of the example songs, as in the progression
/// menu: a full-width band, announced as a heading.
class _SongSection extends StatelessWidget {
  const _SongSection(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Container(
          width: double.infinity,
          color: LowEndColors.of(context).activeFill,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: LowEndColors.of(context).onActiveFill,
            ),
          ),
        ),
      ),
    );
  }
}
