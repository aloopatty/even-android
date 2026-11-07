import 'package:flutter_test/flutter_test.dart';
import 'package:even/domain/money.dart';

void main() {
  group('parseRupeesToPaise', () {
    test('converts whole and decimal rupees exactly', () {
      expect(parseRupeesToPaise('100'), 10000);
      expect(parseRupeesToPaise('100.5'), 10050);
      expect(parseRupeesToPaise('0.75'), 75);
      expect(parseRupeesToPaise('1500.05'), 150005);
      expect(parseRupeesToPaise('.5'), 50);
      expect(parseRupeesToPaise(' 12.3 '), 1230);
    });
    test('rejects invalid precision and malformed values', () {
      for (final value in ['-1', '1.234', 'abc', '', '.', '1..2', '1,000']) {
        expect(parseRupeesToPaise(value), isNull, reason: value);
      }
    });
  });
}
