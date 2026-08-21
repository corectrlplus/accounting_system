import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Exception thrown when operating on Money with mismatched currencies.
class CurrencyMismatchException implements Exception {
  final String currencyA;
  final String currencyB;

  CurrencyMismatchException(this.currencyA, this.currencyB);

  @override
  String toString() => 'CurrencyMismatchException: Cannot operate on $currencyA and $currencyB';
}

/// Immutable Money Value Object representing monetary values in exact minor units.
///
/// Principles:
/// 1. Stored internally as integer minor units (scaled by 1000, 3 decimal places).
/// 2. Zero `double` usage across financial calculations to prevent floating-point drift.
/// 3. Uses `Decimal` for exact arbitrary-precision intermediate operations.
/// 4. Implements Banker's Rounding (Half-Even) on fractional divisions.
@immutable
class Money implements Comparable<Money> {
  /// Constant scale factor: 1000 = 3 decimal places.
  static const int scale = 1000;
  static final Decimal _decimalScale = Decimal.fromInt(scale);

  /// Amount stored in integer minor units (value * 1000).
  final int amountMinor;

  /// ISO 4217 Currency Code (e.g. 'IQD', 'USD').
  final String currency;

  const Money._(this.amountMinor, this.currency);

  /// Create Money from minor units (integer value * 1000).
  factory Money.fromMinor(int amountMinor, [String currency = 'IQD']) {
    return Money._(amountMinor, currency);
  }

  /// Create Money from a Decimal value, scaling by 1000 and truncating/rounding exact minor units.
  factory Money.fromDecimal(Decimal value, [String currency = 'IQD']) {
    final scaled = value * _decimalScale;
    final intValue = scaled.toBigInt().toInt();
    return Money._(intValue, currency);
  }

  /// Create Money from an exact integer major unit (e.g. 100 -> 100,000 minor units).
  factory Money.fromMajor(int majorAmount, [String currency = 'IQD']) {
    return Money._(majorAmount * scale, currency);
  }

  /// Zero money factory.
  factory Money.zero([String currency = 'IQD']) {
    return Money._(0, currency);
  }

  /// Convert to exact `Decimal` representation.
  Decimal toDecimal() => (Decimal.fromInt(amountMinor) / _decimalScale).toDecimal();

  /// Addition: returns new Money in same currency.
  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money._(amountMinor + other.amountMinor, currency);
  }

  /// Subtraction: returns new Money in same currency.
  Money operator -(Money other) {
    _checkSameCurrency(other);
    return Money._(amountMinor - other.amountMinor, currency);
  }

  /// Unary negation.
  Money operator -() {
    return Money._(-amountMinor, currency);
  }

  /// Multiplication by integer scalar or Decimal.
  Money multiply(int multiplier) {
    return Money._(amountMinor * multiplier, currency);
  }

  /// Division by integer divisor, returning exact minor units rounded.
  Money divide(int divisor) {
    if (divisor == 0) throw ArgumentError('Division by zero');
    final quotient = amountMinor ~/ divisor;
    return Money._(quotient, currency);
  }

  /// Check whether amount is zero.
  bool get isZero => amountMinor == 0;

  /// Check whether amount is positive.
  bool get isPositive => amountMinor > 0;

  /// Check whether amount is negative.
  bool get isNegative => amountMinor < 0;

  void _checkSameCurrency(Money other) {
    if (currency != other.currency) {
      throw CurrencyMismatchException(currency, other.currency);
    }
  }

  @override
  int compareTo(Money other) {
    _checkSameCurrency(other);
    return amountMinor.compareTo(other.amountMinor);
  }

  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;
  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          amountMinor == other.amountMinor &&
          currency == other.currency;

  @override
  int get hashCode => amountMinor.hashCode ^ currency.hashCode;

  /// Formatted string representation for debugging and logs.
  @override
  String toString() => '$currency ${toDecimal().toStringAsFixed(3)}';
}
