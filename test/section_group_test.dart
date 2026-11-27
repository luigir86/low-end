import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/theme.dart';
import 'package:low_end/widgets/section_group.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('a section title is a heading in the text colour, no band', (
    tester,
  ) async {
    final theme = LowEndTheme.dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: SectionGroup(title: 'Blues', children: [Text('Mr. P.C.')]),
        ),
      ),
    );
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('Blues')),
      matchesSemantics(label: 'Blues', isHeader: true),
    );
    handle.dispose();
    // The title is not painted on a fill of the accent any more.
    final fill = LowEndColors.of(tester.element(find.text('Blues'))).activeFill;
    expect(
      find.ancestor(
        of: find.text('Blues'),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.color == fill,
        ),
      ),
      findsNothing,
    );
    expect(tester.widget<Text>(find.text('Blues')).style?.color, isNot(fill));
    expect(find.text('Mr. P.C.'), findsOneWidget);
  });
}
