import 'package:flutter_test/flutter_test.dart';
import 'package:low_end/features/player/clock_text.dart';

void main() {
  test('minutes and seconds', () {
    expect(clockText(Duration.zero), '0:00');
    expect(clockText(const Duration(seconds: 5)), '0:05');
    expect(clockText(const Duration(seconds: 72)), '1:12');
    expect(clockText(const Duration(minutes: 20, seconds: 3)), '20:03');
  });

  test('hours when there are some', () {
    expect(
      clockText(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(clockText(const Duration(minutes: 59, seconds: 59)), '59:59');
  });

  test('a tenth, after the separator of the language', () {
    const t = Duration(minutes: 1, seconds: 12, milliseconds: 340);
    expect(clockText(t, tenths: true), '1:12.3');
    expect(clockText(t, tenths: true, decimalSeparator: ','), '1:12,3');
    // Tenths are cut, not rounded: 59.96 s never reads 0:60.
    expect(
      clockText(const Duration(milliseconds: 59960), tenths: true),
      '0:59.9',
    );
  });

  test('a time before the start reads as the start', () {
    expect(clockText(const Duration(seconds: -4)), '0:00');
  });
}
