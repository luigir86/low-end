import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/brand.dart';
import 'package:low_end/app/startup_reveal.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('startup reveals live content with reduced motion $reduced', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: reduced);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(LowEndBrand.mark),
          tester.element(find.byType(SizedBox).last),
        ),
      );
      var taps = 0;
      await tester.pumpWidget(
        StartupReveal(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Ready'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Content is built and usable while the brand is still on top.
      await tester.tap(find.text('Ready'));
      expect(taps, 1);
      if (!reduced) {
        expect(find.byType(FadeTransition), findsWidgets);
        expect(find.byType(Image), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 90));
        expect(find.byType(Image), findsOneWidget);
      }
      await tester.pump(LowEndBrand.transition);
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.text('Ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposing the startup during its first frame is safe', (
    tester,
  ) async {
    await tester.pumpWidget(const StartupReveal(child: SizedBox()));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
