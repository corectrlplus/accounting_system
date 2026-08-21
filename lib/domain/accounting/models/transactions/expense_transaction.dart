import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// Payment method used for an expense.
enum ExpensePaymentMethod {
  /// Cash payment.
  cash,

  /// Bank transfer or electronic payment.
  bank,

  /// Other payment method.
  other,
}

/// Represents an expense transaction recorded in the accounting system.
///
/// An expense creates a journal entry that debits the expense account
/// (e.g. 6100 Rent, 6200 Utilities, 6300 Office Supplies) and credits
/// the cash/bank account from which the payment was made.
@immutable
class ExpenseTransaction extends AccountingTransaction {
  /// The expense category identifier for reporting and classification.
  final String expenseCategoryId;

  /// The account ID to debit (the expense account, e.g. 6100, 6200).
  final String expenseAccountAccountId;

  /// The cash/bank account ID to credit (typically 1110 Cash on Hand or 1120 Bank).
  final String cashAccountAccountId;

  /// Amount of the expense.
  final Money amount;

  /// Method of payment used.
  final ExpensePaymentMethod paymentMethod;

  const ExpenseTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    required this.expenseCategoryId,
    required this.expenseAccountAccountId,
    required this.cashAccountAccountId,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  String get sourceType => 'expense';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ExpenseTransaction &&
          expenseCategoryId == other.expenseCategoryId &&
          expenseAccountAccountId == other.expenseAccountAccountId &&
          cashAccountAccountId == other.cashAccountAccountId &&
          amount == other.amount &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      super.hashCode ^
      expenseCategoryId.hashCode ^
      expenseAccountAccountId.hashCode ^
      cashAccountAccountId.hashCode ^
      amount.hashCode ^
      paymentMethod.hashCode;
}
