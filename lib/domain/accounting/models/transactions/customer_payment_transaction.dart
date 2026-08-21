import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// Payment method used by the customer.
enum CustomerPaymentMethod {
  /// Cash payment received in hand.
  cash,

  /// Bank transfer or electronic payment.
  bank,

  /// Other payment method.
  other,
}

/// Represents an incoming customer payment recorded in the accounting system.
///
/// A customer payment creates a journal entry that debits Cash/Bank and
/// credits Accounts Receivable (the customer's sub-account under 1131).
@immutable
class CustomerPaymentTransaction extends AccountingTransaction {
  /// The customer's unique identifier.
  final String customerId;

  /// The customer's accounts-receivable sub-account ID (1131).
  final String customerAccountId;

  /// Payment amount received from the customer.
  final Money amount;

  /// Method of payment received.
  final CustomerPaymentMethod paymentMethod;

  const CustomerPaymentTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    required this.customerId,
    required this.customerAccountId,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  String get sourceType => 'customer_payment';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is CustomerPaymentTransaction &&
          customerId == other.customerId &&
          customerAccountId == other.customerAccountId &&
          amount == other.amount &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode =>
      super.hashCode ^
      customerId.hashCode ^
      customerAccountId.hashCode ^
      amount.hashCode ^
      paymentMethod.hashCode;
}
