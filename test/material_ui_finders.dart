// Finders that know the material_ui widgets. flutter_test's own
// `find.byTooltip` still checks flutter/material's Tooltip, which the app no
// longer uses since the move to package:material_ui (Flutter 3.50): a
// tooltip with excludeFromSemantics, or one not shown, is then not found.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Tooltip;

extension MaterialUiFinders on CommonFinders {
  /// Like `find.byTooltip`, for material_ui's [Tooltip].
  Finder tooltip(Pattern message, {bool skipOffstage = true}) {
    bool matches(String text) =>
        message is RegExp ? message.hasMatch(text) : text == message;
    return byWidgetPredicate((Widget widget) {
      if (widget is Tooltip) {
        final text = widget.message ?? widget.richMessage!.toPlainText();
        if ((widget.excludeFromSemantics ?? false) || text.isEmpty) {
          return matches(text);
        }
      }
      return widget is RawTooltip && matches(widget.semanticsTooltip ?? '');
    }, skipOffstage: skipOffstage);
  }
}
