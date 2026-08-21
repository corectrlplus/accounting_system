import 'package:meta/meta.dart';
import 'accounting_error.dart';

/// Strongly-typed functional Result wrapper for Accounting Engine operations.
@immutable
class AccountingResult<T> {
  final T? _value;
  final AccountingError? _error;
  final bool isSuccess;

  const AccountingResult._({T? value, AccountingError? error, required this.isSuccess})
      : _value = value,
        _error = error;

  /// Construct a successful result.
  factory AccountingResult.success(T value) {
    return AccountingResult._(value: value, isSuccess: true);
  }

  /// Construct a failed result with an explicit AccountingError.
  factory AccountingResult.failure(AccountingError error) {
    return AccountingResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;

  /// Get value or throw StateError if result is failure.
  T get value {
    if (!isSuccess) {
      throw StateError('Cannot access value on failed AccountingResult: $_error');
    }
    return _value as T;
  }

  /// Get error or throw StateError if result is success.
  AccountingError get error {
    if (isSuccess) {
      throw StateError('Cannot access error on successful AccountingResult');
    }
    return _error!;
  }

  /// Match result state cleanly.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AccountingError error) onFailure,
  }) {
    if (isSuccess) {
      return onSuccess(_value as T);
    } else {
      return onFailure(_error!);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountingResult<T> &&
          runtimeType == other.runtimeType &&
          isSuccess == other.isSuccess &&
          _value == other._value &&
          _error == other._error;

  @override
  int get hashCode => isSuccess.hashCode ^ _value.hashCode ^ _error.hashCode;

  @override
  String toString() {
    return isSuccess ? 'AccountingResult.success($_value)' : 'AccountingResult.failure($_error)';
  }
}
