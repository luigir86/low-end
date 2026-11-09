import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/app/app_navigation.dart';
import 'package:low_end/app/home_shell.dart';
import 'package:low_end/app/low_end_app.dart';
import 'package:low_end/app/settings.dart';
import 'package:low_end/app/style.dart';
import 'package:low_end/app/theme.dart';
import 'package:low_end/audio/audio_scope.dart';
import 'package:low_end/audio/click_output.dart';
import 'package:low_end/audio/mic_input.dart';
import 'package:low_end/audio/tone_output.dart';
import 'package:low_end/widgets/navigation_edge.dart';
import 'package:low_end/widgets/section_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The web app on a computer: a mouse, and a window wider than tall, so the
/// tabs are the rail. A real click often moves the mouse a pixel or two.
void main() {
  Future<AppNavigation> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'seen_guide': true,
      'seen_swipe_hint': true,
    });
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      LowEndApp(
        toneOutput: SilentToneOutput(),
        clickOutput: SilentClickOutput(),
        micInput: FakeMicInput(),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    return AudioScope.of(tester.element(find.byType(HomeShell))).navigation;
  }

  testWidgets(
    'the tabs on the ground keep an accent playing dot on another tab',
    (tester) async {
      final navigation = await open(tester, const Size(900, 1600));
      final scope = AudioScope.of(tester.element(find.byType(HomeShell)));
      final colors = LowEndColors.of(tester.element(find.byType(HomeShell)));
      final theme = Theme.of(tester.element(find.byType(HomeShell)));
      final selected = theme.navigationBarTheme.iconTheme!.resolve({
        WidgetState.selected,
      })!;
      final idle = theme.navigationBarTheme.iconTheme!.resolve({})!;
      expect(selected.color, colors.bottomNavigationSelectedInk);
      expect(idle.color, colors.bottomNavigationInk);
      // No pill: the open section is the light colour, its icon filled.
      expect(
        theme.navigationBarTheme.indicatorColor,
        colors.bottomNavigationIndicator,
      );
      expect(
        tester
            .widget<AppBar>(find.byKey(const Key('appFrame')))
            .backgroundColor,
        colors.navigationBackground,
      );

      await scope.metronome.start();
      navigation.open(AppSection.player);
      await tester.pumpAndSettle();
      expect(navigation.section, AppSection.player);
      final metro = find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'Metronome',
      );
      final dot = find.descendant(of: metro, matching: find.byType(Badge));
      expect(dot, findsOneWidget);
      final badge = tester.widget<Badge>(dot);
      expect(badge.isLabelVisible, isTrue);
      // The accent, as TAP: it reads on the dark bar.
      expect(
        badge.backgroundColor ?? theme.badgeTheme.backgroundColor,
        colors.activeFill,
      );
      final tuner = find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.label == 'Tuner',
      );
      expect(
        find.descendant(of: tuner, matching: find.byType(Badge)),
        findsNothing,
      );
      await scope.metronome.stop();
      await tester.pump();
      expect(tester.widget<Badge>(dot).isLabelVisible, isFalse);
    },
  );

  for (final (inset, bar) in [(0.0, 48.0), (24.0, 64.0), (48.0, 96.0)]) {
    testWidgets('icons centred in the dark band, system inset $inset', (
      tester,
    ) async {
      tester.view.padding = FakeViewPadding(bottom: inset);
      await open(tester, const Size(900, 1600));
      final nav = tester.getRect(find.byType(NavigationBar));
      final icon = tester.getRect(
        find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.byType(SectionIcon),
            )
            .first,
      );
      expect(nav.height, closeTo(bar, 0.01));
      // Gesture navigation: centred in the whole band. Three buttons:
      // centred in the 48 dp above them, which are the system's.
      final band = inset < 48 ? nav : nav.topLeft & Size(nav.width, 48);
      expect(icon.center.dy, closeTo(band.center.dy, 0.01));
    });
  }

  testWidgets('one accent line fading into the ground tops the tabs', (
    tester,
  ) async {
    await open(tester, const Size(900, 1600));
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    await tester.pumpAndSettle();
    final frame = find.byKey(const Key('bottomNavigationFrame'));
    final rect = tester.getRect(frame);
    final barRect = tester.getRect(find.byType(NavigationBar));
    final colors = LowEndColors.of(tester.element(frame));
    final edge = tester.widget<Container>(frame).decoration! as NavigationEdge;
    // The tabs reach the bottom edge: no second line under them.
    expect(rect.bottom, 1600);
    expect(barRect.bottom, 1600);
    // 8 dp of the screen's ground, then the line over the tabs.
    expect(barRect.top - rect.top, 8 + LowEndShape.navigationLine);
    expect(edge.side, NavigationEdgeSide.top);
    expect(edge.accent, colors.activeFill);
    expect(edge.ground, colors.bottomNavigationBackground);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).backgroundColor,
      Colors.transparent,
    );
    // The glow ends before the icons.
    final icon = tester.getRect(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.byType(SectionIcon),
          )
          .first,
    );
    expect(
      icon.top,
      greaterThanOrEqualTo(barRect.top + LowEndShape.navigationGlow),
    );
    final appBar = tester.widget<AppBar>(find.byKey(const Key('appFrame')));
    expect(
      appBar.systemOverlayStyle!.systemNavigationBarIconBrightness,
      Brightness.light,
    );
  });

  /// A mouse click on [at] that moves [by] while the button is down.
  Future<void> click(
    WidgetTester tester,
    TestGesture mouse,
    Offset at,
    Offset by,
  ) async {
    await mouse.moveTo(at);
    await mouse.down(at);
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.moveTo(at + by);
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.up();
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [
    ('rail', const Size(1600, 900)),
    ('bottom bar', const Size(900, 1600)),
  ]) {
    testWidgets('a mouse click that moves a little changes tab ($name)', (
      tester,
    ) async {
      final navigation = await open(tester, size);
      expect(navigation.section, AppSection.drone);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      for (final (tab, section) in [
        ('Tuner', AppSection.tuner),
        ('Metronome', AppSection.metronome),
        ('Harmony', AppSection.drone),
      ]) {
        await click(
          tester,
          mouse,
          tester.getCenter(
            name == 'rail' ? find.text(tab) : find.byTooltip(tab),
          ),
          const Offset(1, 3),
        );
        expect(navigation.section, section);
      }
    });
  }

  testWidgets('a mouse drag on the rail does not flip the section', (
    tester,
  ) async {
    final navigation = await open(tester, const Size(1600, 900));
    final rail = find.byKey(const Key('tabRail'));
    final at = tester.getTopLeft(rail) + const Offset(40, 40);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.down(at);
    for (var i = 1; i <= 5; i++) {
      await mouse.moveTo(at + Offset(0, 20.0 * i));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await mouse.up();
    await tester.pumpAndSettle();
    expect(navigation.section, AppSection.drone);
  });

  // Windows with "Animation effects" off: the browser asks for reduced
  // motion, and the page must still go to the tab.
  for (final (name, size) in [
    ('rail', const Size(1600, 900)),
    ('bottom bar', const Size(900, 1600)),
  ]) {
    testWidgets('with the animations off a tab shows its section ($name)', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final navigation = await open(tester, size);
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      for (final (tab, section) in [
        ('Tuner', AppSection.tuner),
        ('Metronome', AppSection.metronome),
        ('Harmony', AppSection.drone),
      ]) {
        await tester.tap(name == 'rail' ? find.text(tab) : find.byTooltip(tab));
        await tester.pumpAndSettle();
        expect(navigation.section, section);
        expect(pages.page, section.index.toDouble());
      }
    });
  }
}
