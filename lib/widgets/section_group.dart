import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';

/// A titled group of lines (Settings, the example songs): its title in the
/// ivory of the text, announced as a heading, over a thin line of the accent
/// that fades into the ground, like the line over the tabs; then its lines.
/// It replaced a full-width band of the accent (27 November 2026).
class SectionGroup extends StatelessWidget {
  const SectionGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = LowEndColors.of(context).activeFill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0)],
                    ),
                  ),
                  child: const SizedBox(height: 1),
                ),
              ],
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
