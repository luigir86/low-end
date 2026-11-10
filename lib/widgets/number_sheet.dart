import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'choice_menu.dart';

/// The one sheet for typing a number, opened by the pencil of a row: the
/// tempo, the reference A. A sheet from the bottom, titled like the other
/// sheets, with the number to type, the range under it, the usual values to
/// touch (the [shortcuts], the [current] one ticked like in a menu) and OK.
/// The keyboard opens only when the number is touched, so the sheet rises
/// alone and a shortcut is one touch away; touching the number selects it
/// all, so that typing replaces it.
///
/// Returns the number typed, kept within [min]..[max], or a shortcut
/// touched; null when closed, or with nothing typed.
Future<int?> showNumberSheet(
  BuildContext context, {
  required String title,
  required String unit,
  required int current,
  required int min,
  required int max,
  required List<Choice<int>> shortcuts,
  Key? fieldKey,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _NumberSheet(
    title: title,
    unit: unit,
    current: current,
    min: min,
    max: max,
    shortcuts: shortcuts,
    fieldKey: fieldKey,
  ),
);

class _NumberSheet extends StatefulWidget {
  const _NumberSheet({
    required this.title,
    required this.unit,
    required this.current,
    required this.min,
    required this.max,
    required this.shortcuts,
    required this.fieldKey,
  });

  final String title;
  final String unit;
  final int current;
  final int min;
  final int max;
  final List<Choice<int>> shortcuts;
  final Key? fieldKey;

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late final _text = TextEditingController(text: '${widget.current}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_selectAllOnFocus);
  }

  /// After the frame, so that the touch placing the cursor comes first.
  void _selectAllOnFocus() {
    if (!_focus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focus.hasFocus) return;
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_text.text);
    Navigator.of(context).pop(n?.clamp(widget.min, widget.max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        // Above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: widget.fieldKey,
                controller: _text,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffixText: widget.unit,
                  helperText: '${widget.min}–${widget.max}',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            for (final c in widget.shortcuts)
              ChoiceTile(
                title: Text(c.title),
                subtitle: c.subtitle == null ? null : Text(c.subtitle!),
                selected: c.value == widget.current,
                onTap: () => Navigator.of(context).pop(c.value),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(material.okButtonLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
