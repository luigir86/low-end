import 'package:flutter/material.dart';

import '../audio/audio_scope.dart';
import '../audio/pitch.dart';
import '../l10n/app_localizations.dart';
import '../widgets/choice_menu.dart';
import '../widgets/reference_pitch_row.dart';
import '../widgets/row_controls.dart';
import 'about.dart';
import 'guide.dart';
import 'settings.dart';
import 'theme.dart';

/// The settings in three groups (the whole app, the tuner, the harmony), then
/// the thanks, the guide and the About box.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AudioScope.of(context).settings;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final names = settings.noteNames(Localizations.localeOf(context));
          final pitchNames = ReferencePitchRow.standardNames(l10n);
          final example = const Note(
            9,
            4,
          ).label(names, numbering: settings.octaveNumbering);
          return ListView(
            // Its own padding replaces the one a list adds by itself: the end
            // scrolls clear of the navigation bar, and the rows of a notch in
            // landscape (the title bar has taken the top).
            padding:
                MediaQuery.paddingOf(context) +
                const EdgeInsets.symmetric(vertical: 8),
            children: [
              // What the whole app speaks and shows.
              _Section(title: l10n.settingsGeneral),
              ListTile(
                // The field is taller than a one-line tile: room around it.
                contentPadding: _MenuField.tilePadding,
                title: Text(l10n.languageLabel),
                trailing: _MenuField<String>(
                  key: const Key('languageMenu'),
                  label: l10n.languageLabel,
                  width: _MenuField.wide,
                  // '' is the phone's language: a menu closed without a
                  // choice gives null.
                  selected: settings.languageCode ?? '',
                  choices: [
                    Choice(value: '', title: l10n.languageSystem),
                    // Each language in its own name, so it can be found
                    // whatever the app is showing.
                    const Choice(value: 'en', title: 'English'),
                    const Choice(value: 'it', title: 'Italiano'),
                    const Choice(value: 'es', title: 'Español'),
                    const Choice(value: 'fr', title: 'Français'),
                  ],
                  onSelected: (code) =>
                      settings.setLanguage(code.isEmpty ? null : code),
                ),
              ),
              ListTile(
                // The field is taller than a one-line tile: room around it.
                contentPadding: _MenuField.tilePadding,
                title: Text(l10n.noteNamesLabel),
                trailing: _MenuField<NoteNaming>(
                  key: const Key('noteNamesMenu'),
                  label: l10n.noteNamesLabel,
                  width: _MenuField.wide,
                  selected: settings.naming,
                  choices: [
                    Choice(value: NoteNaming.auto, title: l10n.noteNamesAuto),
                    Choice(
                      value: NoteNaming.solfege,
                      title: l10n.noteNamesSolfege,
                    ),
                    Choice(
                      value: NoteNaming.letters,
                      title: l10n.noteNamesLetters,
                    ),
                  ],
                  onSelected: settings.setNaming,
                ),
              ),
              SwitchListTile(
                value: settings.keepScreenOn,
                onChanged: settings.setKeepScreenOn,
                title: Text(l10n.keepScreenOnTitle),
                subtitle: Text(l10n.keepScreenOnSubtitle),
              ),
              SwitchListTile(
                value: settings.gesturesLocked,
                onChanged: settings.setGesturesLocked,
                title: Text(l10n.gesturesLockedTitle),
                subtitle: Text(l10n.gesturesLockedSubtitle),
              ),
              ListTile(
                title: Text(l10n.octaveNumberingLabel),
                subtitle: Text(l10n.octaveNumberingHint),
                trailing: _MenuField<OctaveNumbering>(
                  key: const Key('octaveNumberingMenu'),
                  label: l10n.octaveNumberingLabel,
                  width: _MenuField.wide,
                  selected: settings.octaveNumbering,
                  choices: [
                    // Each with what it calls the A of 440 Hz and a bass's
                    // low E.
                    for (final (numbering, title, short) in [
                      (
                        OctaveNumbering.scientific,
                        l10n.octaveScientific,
                        l10n.octaveScientificShort,
                      ),
                      (OctaveNumbering.italian, l10n.octaveItalian, null),
                    ])
                      Choice(
                        value: numbering,
                        title: title,
                        short: short,
                        subtitle: l10n.octaveExamples(
                          const Note(9, 4).label(names, numbering: numbering),
                          const Note(4, 1).label(names, numbering: numbering),
                        ),
                      ),
                  ],
                  onSelected: settings.setOctaveNumbering,
                ),
              ),
              const Divider(),
              // Everything the tuner compares with, together.
              _Section(title: l10n.tunerTab),
              ListTile(
                title: Text(l10n.referencePitch),
                subtitle: Text(l10n.referencePitchHint(example)),
                // The field announces its name too, not only "440 Hz".
                trailing: _MenuField<double>(
                  key: const Key('referencePitchMenu'),
                  label: l10n.referencePitch,
                  selected: settings.a4,
                  choices: [
                    // The named ones (baroque, concert pitch...) say so,
                    // to be found at a glance among the thirty-one.
                    for (final hz in referencePitches)
                      Choice(
                        value: hz,
                        title: '${hz.round()} Hz',
                        subtitle: pitchNames[hz],
                      ),
                  ],
                  onSelected: settings.setReferencePitch,
                ),
              ),
              ListTile(
                title: Text(l10n.inTuneZoneTitle),
                subtitle: Text(l10n.inTuneZoneSubtitle),
                trailing: _MenuField<double>(
                  key: const Key('inTuneZoneMenu'),
                  label: l10n.inTuneZoneTitle,
                  selected: settings.inTuneCents,
                  choices: [
                    for (final cents in AppSettings.inTuneChoices)
                      Choice(
                        value: cents,
                        title: l10n.centsValue('±${cents.round()}'),
                      ),
                  ],
                  onSelected: settings.setInTuneCents,
                ),
              ),
              ListTile(
                title: Text(l10n.transpositionTitle),
                subtitle: Text(l10n.transpositionSubtitle),
              ),
              // The key the instrument's written C sounds; C is concert
              // pitch.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Semantics(
                  label: l10n.transpositionTitle,
                  container: true,
                  child: SegmentedButton<Transposition>(
                    key: const Key('transposition'),
                    showSelectedIcon: false,
                    segments: [
                      for (final t in Transposition.values)
                        ButtonSegment(
                          value: t,
                          label: Text(Note(t.key, 4).name(names)),
                          tooltip: t == Transposition.c
                              ? l10n.transpositionConcert
                              : null,
                        ),
                    ],
                    selected: {settings.transposition},
                    onSelectionChanged: (s) =>
                        settings.setTransposition(s.first),
                  ),
                ),
              ),
              const Divider(),
              _Section(title: l10n.harmonyTab),
              ListTile(
                contentPadding: _MenuField.tilePadding,
                title: Text(l10n.circleLayoutLabel),
                trailing: _MenuField<CircleLayout>(
                  key: const Key('circleLayoutMenu'),
                  label: l10n.circleLayoutLabel,
                  width: _MenuField.wide,
                  selected: settings.circleLayout,
                  choices: [
                    Choice(
                      value: CircleLayout.fifths,
                      title: l10n.circleLayoutFifths,
                      short: l10n.circleLayoutFifthsShort,
                    ),
                    Choice(
                      value: CircleLayout.chromatic,
                      title: l10n.circleLayoutChromatic,
                      short: l10n.circleLayoutChromaticShort,
                    ),
                  ],
                  onSelected: settings.setCircleLayout,
                ),
              ),
              const Divider(),
              _Section(title: l10n.thanksTitle),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(l10n.thanksText),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  // A link out, said by its icon and its words.
                  child: OutlinedButton.icon(
                    key: const Key('orchestraLink'),
                    onPressed: () => openLink(orchestraUrl),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(l10n.thanksInstagram),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.help_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(l10n.guideTitle),
                onTap: () => showGuide(context),
              ),
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(l10n.aboutTooltip),
                onTap: () => showLowEndAbout(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(color: LowEndColors.of(context).activeFill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: LowEndColors.of(context).onActiveFill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A setting chosen from a list: the field of the rows under the dials, its
/// name left to the line it ends, opening the menu of the whole app.
class _MenuField<T> extends StatelessWidget {
  const _MenuField({
    super.key,
    required this.label,
    required this.selected,
    required this.choices,
    required this.onSelected,
    this.width = 136,
  });

  /// For words rather than numbers: "Follow the language".
  static const double wide = 176;

  /// Around a tile whose only line is its title, so that two such fields
  /// one under the other do not touch. Across, the Material 3 list tile's
  /// own (16 dp before, 24 after), so that every field and switch of the
  /// page ends on the same line.
  static const tilePadding = EdgeInsetsDirectional.fromSTEB(16, 4, 24, 4);

  final String label;
  final double width;
  final T selected;
  final List<Choice<T>> choices;
  final ValueChanged<T> onSelected;

  static String _shown<T>(Choice<T> c) => c.short ?? c.title;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: LabeledField(
      label: label,
      showLabel: false,
      value: _shown(choices.firstWhere((c) => c.value == selected)),
      onTap: () async {
        final picked = await showChoiceMenu(
          anchor: context,
          selected: selected,
          choices: choices,
        );
        if (picked != null) onSelected(picked);
      },
    ),
  );
}
