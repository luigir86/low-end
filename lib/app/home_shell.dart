import 'package:flutter/material.dart';

import '../audio/audio_scope.dart';
import '../features/metronome/metronome_screen.dart';
import '../features/tuner/drone/drone_panel.dart';
import '../features/tuner/tuner_panel.dart';
import '../l10n/app_localizations.dart';
import '../widgets/dial.dart';
import '../widgets/flip_detector.dart';
import '../widgets/section_float.dart';
import '../widgets/section_icons.dart';
import 'app_navigation.dart';
import 'guide.dart';
import 'settings_page.dart';
import 'style.dart';
import 'theme.dart';

/// Main screen with bottom navigation between the app's sections.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// One per [AppSection], in the same order.
  static const _screens = [MetronomeScreen(), DronePanel(), TunerPanel()];

  /// Swiping moves between the sections; a tap on a tab or an action link
  /// moves the page to match.
  final _pages = PageController();

  /// The scroll of each section's page, for the disc under them.
  final _scrolls = SectionScrolls();

  /// Keeps the sections' state when the phone turns and the pages move from
  /// under the bottom bar to beside the rail.
  final _pagesKey = GlobalKey();

  /// True while the page slides to a section chosen elsewhere, so that the
  /// sections it crosses are not opened one after the other.
  var _sliding = false;

  /// True while the guide of the first launch is open.
  var _guideOpen = false;

  @override
  void initState() {
    super.initState();
    // The first time, the guide to the gestures.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = AudioScope.of(context).settings;
      if (settings.seenGuide) return;
      // The swipe hint waits for the guide to close, then still comes the
      // first time the phone is sideways (see [_hintSwipe]).
      settings.markGuideSeen();
      _guideOpen = true;
      showGuide(context).whenComplete(() {
        _guideOpen = false;
        // Builds again, so that a phone already sideways gets its hint.
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _scrolls.dispose();
    super.dispose();
  }

  Future<void> _showSection(AppSection section) async {
    if (!_pages.hasClients) return;
    final page = _pages.page?.round() ?? 0;
    if (page == section.index) return;
    _sliding = true;
    try {
      await _pages.animateToPage(
        section.index,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Durations.medium1,
        curve: Easing.standard,
      );
    } finally {
      _sliding = false;
    }
  }

  /// A vertical flick in landscape: [direction] +1 is the next section.
  void _flip(int direction) {
    final navigation = AudioScope.of(context).navigation;
    final i = navigation.section.index + direction;
    if (i < 0 || i >= AppSection.values.length) return;
    navigation.open(AppSection.values[i]);
  }

  /// The first time the phone is turned sideways, says once how to change
  /// section there: the guide shown at the first launch was read with the
  /// phone upright, where the swipe is the other way.
  void _hintSwipe({required bool landscape, required bool locked}) {
    final settings = AudioScope.of(context).settings;
    // Not at the very first launch: the guide opens then.
    if (!landscape ||
        locked ||
        _guideOpen ||
        settings.seenSwipeHint ||
        !settings.seenGuide) {
      return;
    }
    settings.markSwipeHintSeen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).swipeHint)),
      );
    });
  }

  /// A tap on a tab goes to its section; what plays is started and stopped
  /// from the section itself (the middle of its dial).
  void _onDestination(int i) =>
      AudioScope.of(context).navigation.open(AppSection.values[i]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The settings page or a dialog on top hides the tuner, and the
    // microphone must stop with it (see AppNavigation.tunerVisible).
    final route = ModalRoute.of(context);
    final navigation = AudioScope.of(context).navigation;
    // Not while building, since the tuner's own widgets listen to the
    // change; read again then, in case the page came and went meanwhile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) navigation.setCovered(!(route?.isCurrent ?? true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AudioScope.of(context);
    final navigation = scope.navigation;
    return ListenableBuilder(
      listenable: Listenable.merge([navigation, scope.settings]),
      builder: (context, _) {
        final section = navigation.section;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSection(navigation.section);
        });
        final landscape = DialLayout.isLandscape(context);
        final locked = scope.settings.gesturesLocked;
        _hintSwipe(landscape: landscape, locked: locked);
        final pages = Stack(
          children: [
            // The disc stays still under the pages: moving between sections
            // only the ring and the controls come and go over it.
            Positioned.fill(
              child: DialBackdrop(
                pages: _pages,
                scrolls: _scrolls,
                landscape: landscape,
                disc: LowEndColors.of(context).disc,
                hub: Theme.of(context).colorScheme.surface,
              ),
            ),
            // Tells the app when the sections stop sliding (see
            // AppNavigation.sliding); the pages' own scrolls are deeper.
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.depth == 0) {
                  if (n is ScrollStartNotification) {
                    navigation.sliding.value = true;
                  } else if (n is ScrollEndNotification) {
                    navigation.sliding.value = false;
                  }
                }
                return false;
              },
              child: PageView(
                key: _pagesKey,
                controller: _pages,
                // Landscape: the tabs are a column, so the sections follow
                // vertically, by a flick on the dial or the rail (see
                // FlipDetector), not on the rows, which scroll.
                scrollDirection: landscape ? Axis.vertical : Axis.horizontal,
                physics: landscape || locked
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (i) {
                  if (!_sliding) navigation.open(AppSection.values[i]);
                },
                children: [
                  for (var i = 0; i < _screens.length; i++)
                    SectionFloat(
                      pages: _pages,
                      index: i,
                      scrolls: _scrolls,
                      child: _KeepAlive(
                        // The page view slides its pages; they stay in place
                        // and float (see [SectionFloat.page]).
                        child: SectionFloat.page(
                          pages: _pages,
                          index: i,
                          axis: landscape ? Axis.vertical : Axis.horizontal,
                          direction: Directionality.of(context),
                          // The sections out of sight keep their state but
                          // not their animations: a metronome playing behind
                          // the tuner runs no frames for a ring nobody sees.
                          child: TickerMode(
                            enabled: i == section.index,
                            child: _screens[i],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 4,
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.settingsTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                ),
              ),
            ),
          ],
        );
        // In the order of AppSection.
        final entries = [
          (
            section: AppSection.metronome,
            glyph: SectionGlyph.metronome,
            label: l10n.metronomeTab,
          ),
          (
            section: AppSection.drone,
            glyph: SectionGlyph.piano,
            label: l10n.harmonyTab,
          ),
          (
            section: AppSection.tuner,
            glyph: SectionGlyph.tuningFork,
            label: l10n.tunerTab,
          ),
        ];
        return Scaffold(
          // No title bar: the three sections share the whole height, and the
          // name lives in About. Settings is the one button left, in the corner.
          body: SectionFlip(
            onFlip: locked ? null : _flip,
            child: SafeArea(
              bottom: false,
              child: landscape
                  ? Row(
                      children: [
                        FlipDetector(
                          child: SizedBox(
                            width: LowEndShape.railWidth,
                            child: NavigationRail(
                              key: const Key('tabRail'),
                              selectedIndex: section.index,
                              onDestinationSelected: _onDestination,
                              labelType: NavigationRailLabelType.all,
                              groupAlignment: 0,
                              destinations: [
                                for (final e in entries)
                                  NavigationRailDestination(
                                    icon: _TabIcon(
                                      section: e.section,
                                      icon: SectionIcon(e.glyph),
                                    ),
                                    selectedIcon: _TabIcon(
                                      section: e.section,
                                      icon: SectionIcon(e.glyph, filled: true),
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(e.label),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: pages),
                      ],
                    )
                  : pages,
            ),
          ),
          // The tabs only go to a section; each one starts and stops its own
          // sound (the middle of the dial).
          bottomNavigationBar: landscape
              ? null
              : NavigationBar(
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : Durations.medium1,
                  selectedIndex: section.index,
                  onDestinationSelected: _onDestination,
                  destinations: [
                    for (final e in entries)
                      NavigationDestination(
                        icon: _TabIcon(
                          section: e.section,
                          icon: SectionIcon(e.glyph),
                        ),
                        selectedIcon: _TabIcon(
                          section: e.section,
                          icon: SectionIcon(e.glyph, filled: true),
                        ),
                        label: e.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// The icon of a tab, with a dot while its section plays: from the tuner or
/// the other section, the click or the harmony going on is seen, not only
/// heard. The tuner makes no sound, so its tab never has one.
class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.section, required this.icon});

  final AppSection section;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final scope = AudioScope.of(context);
    final sound = switch (section) {
      AppSection.metronome => scope.metronome,
      AppSection.drone => scope.drone,
      AppSection.tuner => null,
    };
    if (sound == null) return icon;
    // Only the icon listens: the bar is not built again on every change.
    return ListenableBuilder(
      listenable: sound,
      builder: (context, _) {
        final playing = switch (section) {
          AppSection.metronome => scope.metronome.isPlaying,
          AppSection.drone => scope.drone.isPlaying,
          AppSection.tuner => false,
        };
        return Semantics(
          value: playing ? AppLocalizations.of(context).sectionPlaying : null,
          child: Badge(isLabelVisible: playing, child: icon),
        );
      },
    );
  }
}

/// Keeps a section alive while it is off screen (its state, and the
/// microphone and sound it manages, must not restart on every swipe).
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
