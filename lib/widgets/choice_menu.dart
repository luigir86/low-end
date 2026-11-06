import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One line of a [showChoiceMenu]: the [title], and under it a [subtitle]
/// in the muted ink ("Like Autumn Leaves", the strings of an instrument); a
/// [leading] picture before them, as the note figures of the metronome. A
/// [section] different from the line before opens a new section of the
/// menu under that heading ("Jazz"); a [divided] line has a rule above it,
/// without a heading.
class Choice<T> {
  const Choice({
    required this.value,
    required this.title,
    this.subtitle,
    this.leading,
    this.section,
    this.divided = false,
  });

  final T value;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? section;
  final bool divided;
}

/// The one menu of the app, for every short list of choices: the
/// instrument of the tuner, what fills the beat, the chord and the
/// progression, the reference A and the in-tune zone in the settings.
///
/// It opens under the control that [anchor] is the context of, starting at
/// its edge and at least as wide as it, with the round corners and the
/// raised surface of the theme (`popupMenuTheme`). Every line is at least
/// 48 dp high, and the [selected] one is marked the same way as in the
/// lists of the sheets: its words in the accent and a tick at the end, so
/// that the choice is not told by colour alone (WCAG 1.4.1). A list longer
/// than the screen, as the thirty-one reference A's, opens scrolled to the
/// [selected] line, in the middle, so that it is seen at once with its
/// neighbours around it. Returns the value chosen, or null when the menu is
/// closed without a choice.
Future<T?> showChoiceMenu<T>({
  required BuildContext anchor,
  required List<Choice<T>> choices,
  required T? selected,
}) {
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final field = topLeft & box.size;
  // Under the field: its bottom edge is the top of the menu.
  final position = RelativeRect.fromLTRB(
    field.left,
    field.bottom,
    overlay.size.width - field.right,
    overlay.size.height - field.bottom,
  );
  return showMenu<T>(
    context: anchor,
    position: position,
    // No `initialValue`: it would paint the chosen line with a square grey
    // band, already told by its accent and tick; and the menu clips its
    // lines to its round corners.
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(
      minWidth: field.width,
      maxWidth: math.max(field.width, 320),
    ),
    items: [
      for (final (i, c) in choices.indexed) ...[
        if (c.section != null &&
            (i == 0 || choices[i - 1].section != c.section)) ...[
          if (i > 0) const PopupMenuDivider(),
          _SectionHeading<T>(c.section!),
        ] else if (c.divided && i > 0)
          const PopupMenuDivider(),
        PopupMenuItem<T>(
          value: c.value,
          child: _ChoiceLine(choice: c, selected: c.value == selected),
        ),
      ],
    ],
  );
}

class _ChoiceLine<T> extends StatefulWidget {
  const _ChoiceLine({required this.choice, required this.selected});

  final Choice<T> choice;
  final bool selected;

  @override
  State<_ChoiceLine<T>> createState() => _ChoiceLineState<T>();
}

class _ChoiceLineState<T> extends State<_ChoiceLine<T>> {
  @override
  void initState() {
    super.initState();
    // The chosen line brings itself to the middle of the menu as it opens,
    // at once: the menu is laid out at its full height from its first frame
    // (it only unfolds over it), and a short menu does not move.
    if (widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(context, alignment: 0.5);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final choice = widget.choice;
    final selected = widget.selected;
    final subtitle = choice.subtitle;
    return Semantics(
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (choice.leading != null) ...[
              choice.leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    choice.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // Its room kept on every line, so that the words line up.
            SizedBox(
              width: 36,
              child: selected
                  ? Icon(Icons.check, color: scheme.primary)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The heading of a section of the menu, in the small muted capitals of a
/// Material 3 list subheader; it cannot be chosen.
class _SectionHeading<T> extends PopupMenuEntry<T> {
  const _SectionHeading(this.text);

  final String text;

  @override
  double get height => 32;

  @override
  bool represents(T? value) => false;

  @override
  State<_SectionHeading<T>> createState() => _SectionHeadingState<T>();
}

class _SectionHeadingState<T> extends State<_SectionHeading<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Container(
        height: widget.height,
        alignment: AlignmentDirectional.bottomStart,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 4),
        child: Text(
          widget.text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
