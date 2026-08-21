import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// Payment method used for a worker salary payment.
enum WorkerSalaryPaymentMethod {
  /// Cash payment.
  cash,

  /// Bank transfer or electronic payment.
  bank,

  /// Other payment method.
  other,
}

/// Represents a worker salary transaction recorded in the accounting system.
///
/// A worker salary creates a journal entry that debits Direct Labor (5200)
/// for the gross salary and credits Cash/Bank for the net payment. Any advance
/// deduction reduces the cash outflow and credits the Worker Advances
/// Receivable (2200) account.
///
/// Invariant: [netPayment] == [grossSalary] - [advanceDeduction].
@immutable
class WorkerSalaryTransaction extends AccountingTransaction {
  /// The worker's unique identifier.
  final String workerId;

  /// The worker's advance receivable sub-account ID (2200).
  final String workerAccountId;

  /// The cash/bank account ID to credit (typically 1110 Cash on Hand or 1120 Bank).
  final String cashAccountAccountId;

  /// Gross salary before any deductions.
  final Money grossSalary;

  /// Amount deducted from salary to repay outstanding advances.
  ///
  /// Must be less than or equal to the worker's outstanding advance balance.
  final Money advanceDeduction;

  /// Net cash payment to the worker (grossSalary - advanceDeduction).
  final Money netPayment;

  /// Method of payment used.
  final WorkerSalaryPaymentMethod paymentMethod;

  const WorkerSalaryTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    required this.workerId,
    required this.workerAccountId,
    required this.cashAccountAccountId,
    required this.grossSalary,
    required this.advanceDeduction,
    required this.netPayment,
    required this.paymentMethod,
  });

  @override
  String get sourceType => 'worker_salary';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is WorkerSalaryTransaction &&
          workerId == other.workerId &&
          workerAccountId == other.workerAccountId &&
          cashAccountAccountId == other.cashAccountAccountId &&
          grossSalary == other.grossSalary &&
          advanceDeduction == other.advanceDeduction &&
          netPayment == other.netPayment &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      super.hashCode ^
      workerId.hashCode ^
      workerAccountId.hashCode ^
      cashAccountAccountId.hashCode ^
      grossSalary.hashCode ^
      advanceDeduction.hashCode ^
      netPayment.hashCode ^
      paymentMethod.hashCode;
}
