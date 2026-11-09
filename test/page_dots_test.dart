import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/theme.dart';
import 'package:low_end/widgets/page_dots.dart';

void main() {
  Future<void> pump(WidgetTester tester, int count) => tester.pumpWidget(
    MaterialApp(
      theme: LowEndTheme.dark,
      home: Center(child: PageDots(count: count, current: 0, size: 7)),
    ),
  );

  Finder rows() =>
      find.descendant(of: find.byType(PageDots), matching: find.byType(Row));

  testWidgets('up to eight dots stay in one row', (tester) async {
    await pump(tester, 8);
    expect(rows(), findsOneWidget);
  });

  testWidgets('a twelve-bar blues is three rows of four', (tester) async {
    await pump(tester, 12);
    expect(rows(), findsNWidgets(3));
    for (final row in tester.widgetList<Row>(rows())) {
      expect(row.children, hasLength(4));
    }
    // One row of twelve was 140 wide and spilled over the ring.
    expect(tester.getSize(find.byType(PageDots)).width, lessThan(60));
  });
}
