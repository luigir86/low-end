import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/features/player/marquee.dart';

const _long = 'A very long title of a song that cannot fit · and its artist';

Widget _host(
  String text, {
  bool playing = false,
  bool reduce = false,
  double width = 120,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: Marquee(
            key: const Key('marquee'),
            text: text,
            style: const TextStyle(fontSize: 14),
            playing: playing,
          ),
        ),
      ),
    ),
  ),
);

Offset _textAt(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text));

void main() {
  testWidgets('a text that fits stays still and centred', (tester) async {
    await tester.pumpWidget(_host('Blue Bossa', width: 400));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Blue Bossa'), findsOneWidget);
  });

  testWidgets('a long text waits a second, goes by once and stops at its '
      'start in under five seconds', (tester) async {
    await tester.pumpWidget(_host(_long));
    final start = _textAt(tester, _long);
    // The wait.
    await tester.pump(const Duration(milliseconds: 900));
    expect(_textAt(tester, _long), start);
    // Going.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.hasRunningAnimations, isTrue);
    expect(_textAt(tester, _long).dx, lessThan(start.dx));
    // Done within the five seconds a pass may last (after the wait).
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_textAt(tester, _long), start);
  });

  testWidgets('each start of play makes a new pass', (tester) async {
    await tester.pumpWidget(_host(_long));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 6));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(_host(_long, playing: true));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with animations off it never moves and ends in dots', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_long, reduce: true));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.hasRunningAnimations, isFalse);
    final text = tester.widget<Text>(find.text(_long));
    expect(text.overflow, TextOverflow.ellipsis);
  });

  test('the walk is three seconds at most and never faster than needed', () {
    expect(Marquee.walk(60), const Duration(seconds: 2));
    expect(Marquee.walk(90), const Duration(seconds: 3));
    expect(Marquee.walk(300), const Duration(seconds: 3));
  });
}
