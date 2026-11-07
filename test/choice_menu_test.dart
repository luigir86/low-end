import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/theme.dart';
import 'package:low_end/widgets/choice_menu.dart';

void main() {
  testWidgets('the chosen line uses a rounded accent and a tick', (
    tester,
  ) async {
    final theme = LowEndTheme.dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (field) => TextButton(
                onPressed: () => showChoiceMenu(
                  anchor: field,
                  selected: 1,
                  choices: const [
                    Choice(value: 0, title: 'Zero'),
                    Choice(value: 1, title: 'One'),
                    Choice(value: 2, title: 'Two'),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    final fieldBottom = tester.getBottomLeft(find.text('Open')).dy;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // No grey band behind the chosen line.
    final bands = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((b) => b.color == theme.highlightColor);
    expect(bands, isEmpty);
    expect(find.byIcon(Icons.check), findsOneWidget);
    // The menu opens under the field with its first line first, not moved
    // up to put the chosen line there.
    expect(tester.getTopLeft(find.text('Zero')).dy, greaterThan(fieldBottom));
    // Its lines are clipped to its round corners.
    final menu = tester.widget<Material>(
      find
          .ancestor(of: find.text('Zero'), matching: find.byType(Material))
          .last,
    );
    expect(menu.clipBehavior, Clip.antiAlias);
  });

  testWidgets('a long menu opens with the chosen line in the middle', (
    tester,
  ) async {
    // The thirty-one reference A's of the settings, 440 chosen: it is far
    // down the list, and must be seen at once without scrolling.
    await tester.pumpWidget(
      MaterialApp(
        theme: LowEndTheme.dark,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Builder(
              builder: (field) => TextButton(
                onPressed: () => showChoiceMenu(
                  anchor: field,
                  selected: 440,
                  choices: [
                    for (var hz = 415; hz <= 445; hz++)
                      Choice(value: hz, title: '$hz Hz'),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final chosen = tester.getCenter(find.text('440 Hz'));
    final first = tester.getCenter(find.text('415 Hz'));
    // The chosen line is on the screen, about in the middle of the menu,
    // and the first ones have scrolled away above it.
    expect(chosen.dy, greaterThan(0));
    expect(chosen.dy, lessThan(screen.height));
    expect(first.dy, lessThan(0));
    final menu = tester.getRect(
      find
          .ancestor(of: find.text('440 Hz'), matching: find.byType(Material))
          .last,
    );
    expect((chosen.dy - menu.center.dy).abs(), lessThan(48));
    // And it is chosen with one touch.
    await tester.tap(find.text('440 Hz'));
    await tester.pumpAndSettle();
    expect(find.text('440 Hz'), findsNothing);
  });
}
