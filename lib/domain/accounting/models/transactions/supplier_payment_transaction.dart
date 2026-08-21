import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// Payment method used for the supplier payment.
enum SupplierPaymentMethod {
  /// Cash payment made in hand.
  cash,

  /// Bank transfer or electronic payment.
  bank,

  /// Other payment method.
  other,
}

/// Represents an outgoing supplier payment recorded in the accounting system.
///
/// A supplier payment creates a journal entry that debits Accounts Payable
/// (the supplier's sub-account under 2110) and credits Cash/Bank.
@immutable
class SupplierPaymentTransaction extends AccountingTransaction {
  /// The supplier's unique identifier.
  final String supplierId;

  /// The supplier's accounts-payable sub-account ID (2110).
  final String supplierAccountId;

  /// Payment amount made to the supplier.
  final Money amount;

  /// Method of payment made.
  final SupplierPaymentMethod paymentMethod;

  const SupplierPaymentTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    required this.supplierId,
    required this.supplierAccountId,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  String get sourceType => 'supplier_payment';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is SupplierPaymentTransaction &&
          supplierId == other.supplierId &&
          supplierAccountId == other.supplierAccountId &&
          amount == other.amount &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      super.hashCode ^
      supplierId.hashCode ^
      supplierAccountId.hashCode ^
      amount.hashCode ^
      paymentMethod.hashCode;
}
