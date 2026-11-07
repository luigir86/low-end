import 'package:flutter/material.dart';

import '../audio/audio_scope.dart';
import '../audio/pitch.dart';
import '../l10n/app_localizations.dart';
import 'choice_menu.dart';
import 'number_sheet.dart';
import 'row_controls.dart';

/// The reference A, also in the settings, at hand on the tuner: a field with
/// its name on the border, − and + to step through the hertz from 415 to
/// 445, and a pencil to type a pitch or choose one of the standard ones. The
/// same pieces as the rows of the metronome and the harmony.
class ReferencePitchRow extends StatelessWidget {
  const ReferencePitchRow({super.key});

  /// The standard pitches offered by the pencil: baroque, Verdi's, concert
  /// pitch and the orchestras'.
  static const standard = [415.0, 432.0, 440.0, 442.0];

  /// The names of the [standard] pitches, under them in the lists.
  static Map<double, String> standardNames(AppLocalizations l10n) => {
    415.0: l10n.pitchBaroque,
    432.0: l10n.pitchVerdi,
    440.0: l10n.pitchConcert,
    442.0: l10n.pitchOrchestras,
  };

  @override
  Widget build(BuildContext context) {
    final settings = AudioScope.of(context).settings;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final a4 = settings.a4;
        void step(double delta) => settings.setReferencePitch(a4 + delta);
        return Row(
          children: [
            Expanded(
              child: LabeledField(
                label: l10n.referencePitch,
                value: '${a4.round()} Hz',
                onTap: () => _choose(context),
              ),
            ),
            const SizedBox(width: rowGap),
            RowButton(
              adjustment: true,
              label: const Icon(Icons.remove, size: 24),
              tooltip: l10n.lowerPitch,
              onPressed: a4 > minReferencePitch ? () => step(-1) : null,
            ),
            const SizedBox(width: rowGap),
            RowButton(
              adjustment: true,
              label: const Icon(Icons.add, size: 24),
              tooltip: l10n.higherPitch,
              onPressed: a4 < maxReferencePitch ? () => step(1) : null,
            ),
            RowIconButton(
              icon: Icons.edit_outlined,
              tooltip: l10n.choosePitch,
              onPressed: () => _choose(context),
            ),
          ],
        );
      },
    );
  }

  /// A pitch typed in, with the four standard ones to choose from.
  Future<void> _choose(BuildContext context) async {
    final settings = AudioScope.of(context).settings;
    final l10n = AppLocalizations.of(context);
    final names = standardNames(l10n);
    final hz = await showNumberSheet(
      context,
      title: l10n.referencePitch,
      unit: 'Hz',
      current: settings.a4.round(),
      min: minReferencePitch.round(),
      max: maxReferencePitch.round(),
      fieldKey: const Key('pitchField'),
      shortcuts: [
        for (final hz in standard)
          Choice(
            value: hz.round(),
            title: '${hz.round()} Hz',
            subtitle: names[hz],
          ),
      ],
    );
    if (hz != null) settings.setReferencePitch(hz.toDouble());
  }
}
