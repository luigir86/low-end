import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The pieces of the row of controls under a dial, shared by the metronome,
/// the harmony and the tuner so that the three look the same: a field with
/// its name on the border, round-cornered chips and a plain icon
/// button in the primary colour (like the sound options).

/// A field in the style of the chord menu: its [label] written on the
/// border, the current [value] inside, a caret to say a touch opens a
/// choice. With [showLabel] false the border stays bare, as for the time
/// signature, where "4/4" says it all; the [label] is still what a screen
/// reader announces.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.showLabel = true,
    this.display,
  });

  final String label;
  final bool showLabel;
  final String value;

  /// Shown in place of [value] (the notes of a subdivision); [value] is
  /// still what a screen reader says.
  final Widget? display;

  /// Null: the field is dimmed and does nothing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      value: value,
      excludeSemantics: true,
      enabled: onTap != null,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.38 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: showLabel ? label : null,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.fromLTRB(12, 16, 4, 16),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 24,
              ),
            ),
            child:
                display ??
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
          ),
        ),
      ),
    );
  }
}

/// The height of a line of text in a row, and the padding above and below
/// the label of a button that makes it as tall as the field beside it (a
/// line, 16 dp of padding on both sides).
const rowLineHeight = 24.0;
const rowButtonPadding = 16.0;

/// Room a [RowButton] takes round its label, across.
const rowButtonInset = 24.0;

/// The space between two blocks of a row (a field, a button), the same in
/// every row of every section.
const rowGap = 8.0;

/// A button of the row: TAP, − and + on the metronome and the tuner. A
/// Material button, outlined; with [filled] a tonal one, to say that it is
/// the button to press (TAP), unlike the ones that only step a value.
/// With [onPressed] null it is dimmed (the end of a range).
class RowButton extends StatelessWidget {
  const RowButton({
    super.key,
    required this.label,
    this.tooltip,
    this.onPressed,
    this.filled = false,
    this.adjustment = false,
  });

  final Widget label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final bool adjustment;

  @override
  Widget build(BuildContext context) {
    // At least as tall as a line of text, so that an icon button grows with
    // large text as the field beside it does.
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.textScalerOf(context).scale(rowLineHeight),
      ),
      child: Center(widthFactor: 1, child: label),
    );
    // What a screen reader says: the tooltip is the name of an icon.
    final named = tooltip == null
        ? content
        : Semantics(label: tooltip, child: content);
    final padding = const EdgeInsets.symmetric(
      horizontal: rowButtonInset / 2,
      vertical: rowButtonPadding,
    );
    final colors = LowEndColors.of(context);
    final pale = adjustment && colors.filledSteps;
    final Widget button = filled || pale
        ? FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: pale
                  ? colors.stepFill
                  : colors.filledSteps
                  ? colors.activeFill
                  : Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: pale
                  ? colors.onStepFill
                  : colors.filledSteps
                  ? colors.onActiveFill
                  : Theme.of(context).colorScheme.onSecondaryContainer,
              padding: padding,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: named,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: padding,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: named,
          );
    return tooltip == null
        ? button
        : Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }
}

/// The text of a [RowButton]: bold, the size of a body.
TextStyle? rowButtonStyle(BuildContext context, {Color? color}) =>
    Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

/// The button at the end of the row (the pencil, the sound options): boxed
/// like the buttons beside it, with its icon in the ink of their text, so
/// that the row is a line of equal blocks. The gap before it is its own, or the gap after it when it
/// [leads] the row (the example songs).
class RowIconButton extends StatelessWidget {
  const RowIconButton({
    super.key,
    this.icon,
    this.picture,
    required this.tooltip,
    required this.onPressed,
    this.leads = false,
    this.filled = true,
  }) : assert((icon == null) != (picture == null));

  /// A Material icon, or else a [picture] of the size of one.
  final IconData? icon;
  final Widget? picture;
  final String tooltip;
  final VoidCallback onPressed;
  final bool leads;
  final bool filled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: leads
        ? const EdgeInsetsDirectional.only(end: rowGap)
        : const EdgeInsetsDirectional.only(start: rowGap),
    child: RowButton(
      filled: filled && LowEndColors.of(context).filledSteps,
      // The size and ink of an icon of the row, not the smaller one a
      // button gives its icons.
      label: IconTheme.merge(
        data: IconThemeData(
          size: 24,
          color: filled && LowEndColors.of(context).filledSteps
              ? LowEndColors.of(context).onActiveFill
              : Theme.of(context).colorScheme.onSurface,
        ),
        child: picture ?? Icon(icon),
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    ),
  );
}
