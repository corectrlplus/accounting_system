import 'package:meta/meta.dart';
import 'transaction_context.dart';

/// Abstract base class for all business transactions submitted to the Accounting Engine.
@immutable
abstract class AccountingTransaction {
  final String transactionId;
  final TransactionContext context;
  final String idempotencyKey;
  final int dateMs;
  final String currencyCode;
  final String description;

  const AccountingTransaction({
    required this.transactionId,
    required this.context,
    required this.idempotencyKey,
    required this.dateMs,
    required this.currencyCode,
    required this.description,
  });

  /// The business source type (e.g. 'sale', 'purchase', 'customer_payment', 'expense', etc.)
  String get sourceType;

  /// Shorthand getter for Company ID from context.
  String get companyId => context.companyId;

  /// Shorthand getter for User ID from context.
  String get userId => context.userId;

  /// Shorthand getter for Device ID from context.
  String get deviceId => context.deviceId;
}
