import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../accounting_transaction.dart';

/// A single line item within a [PurchaseTransaction].
@immutable
class PurchaseItem {
  /// Human-readable description of the purchased item.
  final String description;

  /// Quantity in integer minor units (quantity * 1000 for fractional support).
  final int quantityMinor;

  /// Unit price of the item.
  final Money unitPrice;

  /// Total price for this line item (quantity * unitPrice).
  final Money totalPrice;

  const PurchaseItem({
    required this.description,
    required this.quantityMinor,
    required this.unitPrice,
    required this.totalPrice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseItem &&
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

/// Payment type for a purchase transaction.
enum PurchasePaymentType {
  /// Full cash payment.
  cash,

  /// Full credit (accounts payable).
  credit,

  /// Partial cash, partial credit.
  mixed,
}

/// Accounting nature of a purchase, determining the debit target account.
enum PurchaseAccountingNature {
  /// Purchase of inventory items (debit 1140 Inventory).
  inventory,

  /// Purchase of raw materials (debit 5100 Direct Materials).
  materials,

  /// Purchase for operating expenses (debit 6000-series).
  operatingExpense,

  /// Purchase of services.
  service,

  /// Other purchase types.
  other,
}

/// Represents a purchase transaction recorded in the accounting system.
///
/// A purchase creates a journal entry that debits the target account
/// (e.g. Inventory, Materials, or an Expense account) and credits Cash /
/// Accounts Payable depending on the payment type.
@immutable
class PurchaseTransaction extends AccountingTransaction {
  /// Optional human-readable supplier name for display purposes.
  final String? supplierName;

  /// The supplier's accounts-payable sub-account ID (2110).
  final String supplierAccountId;

  /// The account ID to debit, determined by [accountingNature].
  ///
  /// For example:
  /// - Inventory purchases → 1140 (Inventory)
  /// - Materials → 5100 (Direct Materials)
  /// - Operating expense → 6000-series account
  final String targetAccountId;

  /// Line items included in this purchase.
  final List<PurchaseItem> items;

  /// Payment classification for this purchase.
  final PurchasePaymentType paymentType;

  /// Cash amount paid to the supplier.
  final Money cashPaid;

  /// Amount placed on credit (accounts payable).
  final Money creditAmount;

  /// Accounting nature determining the debit side of the journal entry.
  final PurchaseAccountingNature accountingNature;

  const PurchaseTransaction({
    required super.transactionId,
    required super.context,
    required super.idempotencyKey,
    required super.dateMs,
    required super.currencyCode,
    required super.description,
    this.supplierName,
    required this.supplierAccountId,
    required this.targetAccountId,
    required this.items,
    required this.paymentType,
    required this.cashPaid,
    required this.creditAmount,
    required this.accountingNature,
  });

  /// Total amount of the purchase, equal to the sum of all item totalPrice values.
  Money get totalAmount => items.fold(
        Money.zero(currencyCode),
        (sum, item) => sum + item.totalPrice,
      );

  @override
  String get sourceType => 'purchase';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is PurchaseTransaction &&
          supplierName == other.supplierName &&
          supplierAccountId == other.supplierAccountId &&
          targetAccountId == other.targetAccountId &&
          paymentType == other.paymentType &&
          cashPaid == other.cashPaid &&
          creditAmount == other.creditAmount &&
          accountingNature == other.accountingNature;

  @override
  int get hashCode =>
      super.hashCode ^
      supplierName.hashCode ^
      supplierAccountId.hashCode ^
      targetAccountId.hashCode ^
      paymentType.hashCode ^
      cashPaid.hashCode ^
      creditAmount.hashCode ^
      accountingNature.hashCode;
}
