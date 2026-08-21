import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import '../../lib/core/money/money.dart';

void main() {
  group('Money Value Object Tests', () {
    test('1. Scale factor factor 1000 conversion', () {
      final m1 = Money.fromMinor(1500000500, 'IQD');
      expect(m1.amountMinor, equals(1500000500));
      expect(m1.toDecimal(), equals(Decimal.parse('1500000.500')));

      final m2 = Money.fromMajor(100, 'IQD');
      expect(m2.amountMinor, equals(100000));
      expect(m2.toDecimal(), equals(Decimal.parse('100.000')));
    });

    test('2. Exact Decimal conversion without floating-point loss', () {
      final dec = Decimal.parse('123456.789');
      final m = Money.fromDecimal(dec, 'IQD');
      expect(m.amountMinor, equals(123456789));
      expect(m.toDecimal(), equals(dec));
    });

    test('3. Money Arithmetic: Addition & Subtraction', () {
      final a = Money.fromMinor(500000, 'IQD');
      final b = Money.fromMinor(300000, 'IQD');

      final sum = a + b;
      expect(sum.amountMinor, equals(800000));

      final diff = a - b;
      expect(diff.amountMinor, equals(200000));
    });

    test('4. Currency Mismatch throws Exception', () {
      final iqd = Money.fromMinor(1000, 'IQD');
      final usd = Money.fromMinor(1000, 'USD');

      expect(() => iqd + usd, throwsA(isA<CurrencyMismatchException>()));
    });

    test('5. Comparisons & Negation', () {
      final m100 = Money.fromMajor(100, 'IQD');
      final m200 = Money.fromMajor(200, 'IQD');

      expect(m100 < m200, isTrue);
      expect(m200 > m100, isTrue);
      expect(m100 == Money.fromMajor(100, 'IQD'), isTrue);
      expect((-m100).amountMinor, equals(-100000));
    });

    test('6. Division & Zero Division Guard (Invalid Monetary Values)', () {
      final m = Money.fromMinor(100000, 'IQD');
      final half = m.divide(2);
      expect(half.amountMinor, equals(50000));

      expect(() => m.divide(0), throwsA(isA<ArgumentError>()));
    });
  });
}
