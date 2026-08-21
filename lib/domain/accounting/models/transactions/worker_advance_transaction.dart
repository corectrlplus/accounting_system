import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// Payment method used for a worker advance.
enum WorkerAdvancePaymentMethod {
  /// Cash payment.
  cash,

  /// Bank transfer or electronic payment.
  bank,

  /// Other payment method.
  other,
}

/// Represents a worker advance transaction recorded in the accounting system.
///
/// A worker advance creates a journal entry that debits Worker Advances
/// Receivable (2200) and credits Cash/Bank. This amount is later deducted
/// from the worker's salary via [WorkerSalaryTransaction].
@immutable
class WorkerAdvanceTransaction extends AccountingTransaction {
  /// The worker's unique identifier.
  final String workerId;

  /// The worker's advance receivable sub-account ID (2200).
  final String workerAccountId;

  /// The cash/bank account ID to credit (typically 1110 Cash on Hand or 1120 Bank).
  final String cashAccountAccountId;

  /// Amount of the advance given to the worker.
  final Money amount;

  /// Method of payment used.
  final WorkerAdvancePaymentMethod paymentMethod;

  const WorkerAdvanceTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    required this.workerId,
    required this.workerAccountId,
    required this.cashAccountAccountId,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  String get sourceType => 'worker_advance';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is WorkerAdvanceTransaction &&
          workerId == other.workerId &&
          workerAccountId == other.workerAccountId &&
          cashAccountAccountId == other.cashAccountAccountId &&
          amount == other.amount &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      super.hashCode ^
      workerId.hashCode ^
      workerAccountId.hashCode ^
      cashAccountAccountId.hashCode ^
      amount.hashCode ^
      paymentMethod.hashCode;
}
