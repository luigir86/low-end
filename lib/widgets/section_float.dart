import 'package:flutter/material.dart';

/// The vertical scroll of each section's page (it scrolls with very large
/// text), so that the disc under the pages can follow the page on screen.
class SectionScrolls extends ChangeNotifier {
  final _offsets = List<double>.filled(4, 0);

  double operator [](int i) => _offsets[i];

  void operator []=(int i, double value) {
    if (_offsets[i] == value) return;
    _offsets[i] = value;
    notifyListeners();
  }

  /// The scroll under the pages at [page] (fractional while sliding).
  double at(double page) {
    final low = page.floor().clamp(0, _offsets.length - 1);
    final high = page.ceil().clamp(0, _offsets.length - 1);
    return _offsets[low] + (_offsets[high] - _offsets[low]) * (page - low);
  }
}

/// What a section needs to float in over the fixed disc instead of sliding
/// with it. The pages of the shell stay where they are (see [SectionFloat.page])
/// and each section fades its ring and drifts its rows by how far it is from
/// the one on screen.
class SectionFloat extends InheritedWidget {
  const SectionFloat({
    super.key,
    required this.pages,
    required this.index,
    required this.scrolls,
    required super.child,
  });

  final PageController pages;

  /// This section, in the order of the pages.
  final int index;
  final SectionScrolls scrolls;

  static SectionFloat? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SectionFloat>();

  /// How far this section is from the one on screen: 0 on screen, −1 when
  /// it waits one page to the right (or below), 1 when it has just left to
  /// the left (or above).
  double get away => awayOf(pages, index);

  /// The page on screen, or null while the page view has not measured itself
  /// (a frame while it is built again): nothing is moved or hidden then.
  static double? pageIfKnown(PageController pages) =>
      pages.hasClients && pages.position.haveDimensions ? pages.page : null;

  static double awayOf(PageController pages, int index) {
    final page = pageIfKnown(pages);
    return page == null ? 0 : page - index;
  }

  static double pageOf(PageController pages) =>
      pageIfKnown(pages) ?? pages.initialPage.toDouble();

  /// Opacity of a section [away] pages from the screen: the one leaving
  /// fades out as the one coming fades in, not both at half.
  static double opacity(double away) =>
      Easing.standardAccelerate.transform((1 - away.abs()).clamp(0.0, 1.0));

  /// Keeps the page where the dial is whatever the pages do: the page view
  /// slides its pages, this takes the slide back so that all sections are in
  /// one place, and the page is out of the way (not built on screen, not
  /// touched) unless it is the one on screen or moving in or out. Wraps the
  /// section in the page.
  static Widget page({
    required PageController pages,
    required int index,
    required Axis axis,
    required TextDirection direction,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: pages,
      child: child,
      builder: (context, child) {
        final away = awayOf(pages, index);
        final extent = pages.hasClients && pages.position.haveDimensions
            ? pages.position.viewportDimension
            : 0.0;
        final sign = axis == Axis.horizontal && direction == TextDirection.rtl
            ? -1.0
            : 1.0;
        return Offstage(
          offstage: away.abs() >= 1,
          child: IgnorePointer(
            ignoring: away.abs() > 0.5,
            child: Transform.translate(
              offset: axis == Axis.horizontal
                  ? Offset(sign * away * extent, 0)
                  : Offset(0, away * extent),
              // The whole section fades at once, its ring and its rows
              // together: one layer to blend at each frame of a slide
              // instead of one for the ring and one for each row, which a
              // phone's browser was slow to draw. Drawn once and only moved
              // and faded while it slides (RepaintBoundary).
              child: Opacity(
                opacity: opacity(away),
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The ring and the hub of a section: they stay on the disc and fade
  /// with their section (see [page]).
  static Widget ring(BuildContext context, Widget child) => child;

  /// A row of controls: it fades with its section (see [page]) and drifts a
  /// little the way the finger goes, over the still disc.
  static Widget row(BuildContext context, Widget child, {required Axis axis}) {
    final float = of(context);
    if (float == null) return child;
    return AnimatedBuilder(
      animation: float.pages,
      child: child,
      builder: (context, child) {
        final pages = float.pages;
        final extent = pages.hasClients && pages.position.haveDimensions
            ? pages.position.viewportDimension
            : 0.0;
        final drift = -float.away * extent * _drift;
        return Transform.translate(
          offset: axis == Axis.horizontal ? Offset(drift, 0) : Offset(0, drift),
          child: child,
        );
      },
    );
  }

  /// How much of a page's slide the rows keep: a drift, not a slide.
  static const _drift = 0.2;

  @override
  bool updateShouldNotify(SectionFloat old) =>
      pages != old.pages || index != old.index || scrolls != old.scrolls;
}
