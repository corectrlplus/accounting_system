import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// Payment method used for an owner withdrawal.
enum OwnerWithdrawalPaymentMethod {
  /// Cash withdrawal.
  cash,

  /// Bank transfer or electronic withdrawal.
  bank,

  /// Other payment method.
  other,
}

/// Represents an owner withdrawal transaction recorded in the accounting system.
///
/// An owner withdrawal creates a journal entry that debits Owner Drawings
/// (3300) and credits Cash/Bank. This reduces owner's equity without
/// affecting the income statement.
@immutable
class OwnerWithdrawalTransaction extends AccountingTransaction {
  /// The Owner Drawings account ID (3300).
  final String ownerDrawingAccountId;

  /// The cash/bank account ID to credit (typically 1110 Cash on Hand or 1120 Bank).
  final String cashAccountAccountId;

  /// Amount withdrawn by the owner.
  final Money amount;

  /// Method of payment used.
  final OwnerWithdrawalPaymentMethod paymentMethod;

  const OwnerWithdrawalTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    required this.ownerDrawingAccountId,
    required this.cashAccountAccountId,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  String get sourceType => 'owner_withdrawal';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is OwnerWithdrawalTransaction &&
          ownerDrawingAccountId == other.ownerDrawingAccountId &&
          cashAccountAccountId == other.cashAccountAccountId &&
          amount == other.amount &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      super.hashCode ^
      ownerDrawingAccountId.hashCode ^
      cashAccountAccountId.hashCode ^
      amount.hashCode ^
      paymentMethod.hashCode;
}
