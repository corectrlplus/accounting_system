import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// A single line item within a [SaleTransaction].
@immutable
class SaleItem {
  /// Human-readable description of the sold item.
  final String description;

  /// Quantity in integer minor units (quantity * 1000 for fractional support).
  final int quantityMinor;

  /// Unit price of the item.
  final Money unitPrice;

  /// Total price for this line item (quantity * unitPrice).
  final Money totalPrice;

  const SaleItem({
    required this.description,
    required this.quantityMinor,
    required this.unitPrice,
    required this.totalPrice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItem &&
          runtimeType == other.runtimeType &&
          description == other.description &&
          quantityMinor == other.quantityMinor &&
          unitPrice == other.unitPrice &&
          totalPrice == other.totalPrice;

  @override
  int get hashCode =>
      description.hashCode ^
      quantityMinor.hashCode ^
      unitPrice.hashCode ^
      totalPrice.hashCode;
}

/// Payment type for a sale transaction.
enum SalePaymentType {
  /// Full cash payment.
  cash,

  /// Full credit (accounts receivable).
  credit,

  /// Partial cash, partial credit.
  mixed,
}

/// Represents a sale transaction recorded in the accounting system.
///
/// A sale creates a journal entry that debits Cash/Accounts Receivable and
/// credits Sales Revenue. For mixed payments the cash portion debits the
/// Cash account and the credit portion debits Accounts Receivable.
@immutable
class SaleTransaction extends AccountingTransaction {
  /// Optional human-readable customer name for display purposes.
  final String? customerName;

  /// The customer's accounts-receivable sub-account ID (1131).
  final String customerAccountId;

  /// Line items included in this sale.
  final List<SaleItem> items;

  /// Payment classification for this sale.
  final SalePaymentType paymentType;

  /// Cash amount received from the customer.
  final Money cashReceived;

  /// Amount placed on credit (accounts receivable).
  final Money creditAmount;

  const SaleTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    this.customerName,
    required this.customerAccountId,
    required this.items,
    required this.paymentType,
    required this.cashReceived,
    required this.creditAmount,
  });

  /// Total amount of the sale, equal to the sum of all item totalPrice values.
  Money get totalAmount => items.fold(
        Money.zero(currencyCode),
        (sum, item) => sum + item.totalPrice,
      );

  @override
  String get sourceType => 'sale';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is SaleTransaction &&
          customerName == other.customerName &&
          customerAccountId == other.customerAccountId &&
          paymentType == other.paymentType &&
          cashReceived == other.cashReceived &&
          creditAmount == other.creditAmount;

  @override
  int get hashCode =>
      super.hashCode ^
      customerName.hashCode ^
      customerAccountId.hashCode ^
      paymentType.hashCode ^
      cashReceived.hashCode ^
      creditAmount.hashCode;
}
