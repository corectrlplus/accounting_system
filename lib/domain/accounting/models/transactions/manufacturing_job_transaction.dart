import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// Scenario under which the manufacturing job is performed.
enum ManufacturingScenario {
  /// Work performed by an external party (debited to External Manufacturing 7300).
  external,

  /// Work performed internally by the owner's own workshop.
  ownerInternal,

  /// Internal work tracked at cost (debited to relevant cost accounts).
  internalCost,
}

/// Accounting treatment determining how the job cost is classified.
enum ManufacturingAccountingTreatment {
  /// Treated as manufacturing revenue.
  revenue,

  /// Treated as a cost of manufacturing.
  costOfManufacturing,

  /// Direct labor cost.
  directLabor,

  /// Materials cost.
  materials,

  /// Manufacturing overhead.
  overhead,
}

/// Payment method used for a manufacturing job.
enum ManufacturingPaymentMethod {
  /// Cash payment.
  cash,

  /// Bank transfer or electronic payment.
  bank,

  /// Other payment method.
  other,
}

/// Represents a manufacturing job transaction recorded in the accounting system.
///
/// The journal entry depends on [scenario] and [accountingTreatment]:
///
/// - **External**: Debits External Manufacturing (7300), credits Cash/Bank.
/// - **Owner Internal**: Debits the target cost account, credits Cash/Bank.
/// - **Internal Cost**: Debits the relevant COGS account, credits the
///   appropriate cost pool.
///
/// The [targetAccountId] should correspond to the account determined by
/// [accountingTreatment] and [scenario].
@immutable
class ManufacturingJobTransaction extends AccountingTransaction {
  /// The workshop where the manufacturing job was performed.
  final String workshopId;

  /// Free-text description of the type of work performed.
  final String workType;

  /// Manufacturing scenario determining the accounting flow.
  final ManufacturingScenario scenario;

  /// Accounting treatment determining the debit classification.
  final ManufacturingAccountingTreatment accountingTreatment;

  /// The account ID to debit, derived from [scenario] and [accountingTreatment].
  ///
  /// Examples:
  /// - External → 7300 (External Manufacturing)
  /// - Internal cost + materials → 5100 (Direct Materials)
  /// - Internal cost + labor → 5200 (Direct Labor)
  /// - Internal cost + overhead → 5300 (Manufacturing Overhead)
  final String targetAccountId;

  /// The cash/bank account ID to credit (typically 1110 Cash on Hand or 1120 Bank).
  final String cashAccountAccountId;

  /// Total cost of the manufacturing job.
  final Money totalCost;

  /// Optional customer ID if the job is for a specific customer.
  final String? customerId;

  /// Payment method used.
  final ManufacturingPaymentMethod paymentMethod;

  const ManufacturingJobTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    required this.workshopId,
    required this.workType,
    required this.scenario,
    required this.accountingTreatment,
    required this.targetAccountId,
    required this.cashAccountAccountId,
    required this.totalCost,
    this.customerId,
    required this.paymentMethod,
  });

  @override
  String get sourceType => 'manufacturing';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ManufacturingJobTransaction &&
          workshopId == other.workshopId &&
          workType == other.workType &&
          scenario == other.scenario &&
          accountingTreatment == other.accountingTreatment &&
          targetAccountId == other.targetAccountId &&
          cashAccountAccountId == other.cashAccountAccountId &&
          totalCost == other.totalCost &&
          customerId == other.customerId &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      super.hashCode ^
      workshopId.hashCode ^
      workType.hashCode ^
      scenario.hashCode ^
      accountingTreatment.hashCode ^
      targetAccountId.hashCode ^
      cashAccountAccountId.hashCode ^
      totalCost.hashCode ^
      customerId.hashCode ^
      paymentMethod.hashCode;
}
