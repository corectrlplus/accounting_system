import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../builder/journal_entry_builder.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/purchase_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for purchase transactions.
///
/// Creates balanced journal entries for purchases based on payment type:
/// - **Cash**: Debit target account (inventory/materials/expense), Credit Cash.
/// - **Credit**: Debit target account, Credit Accounts Payable.
/// - **Mixed**: Debit target account (total), Credit Cash (cash portion),
///   Credit Accounts Payable (credit portion).
@immutable
class PurchaseTransactionEngine extends TransactionEngine<PurchaseTransaction> {
  final String cashAccountId;

  const PurchaseTransactionEngine({
    required JournalEntryRepository repository,
    required this.cashAccountId,
  }) : super(repository);

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(PurchaseTransaction tx) {
    final totalAmount = tx.totalAmount;

    if (tx.paymentType == PurchasePaymentType.cash) {
      return _buildCashEntry(tx, totalAmount);
    } else if (tx.paymentType == PurchasePaymentType.credit) {
      return _buildCreditEntry(tx, totalAmount);
    } else {
      return _buildMixedEntry(tx, totalAmount);
    }
  }

  AccountingResult<JournalEntryDraft> _buildCashEntry(PurchaseTransaction tx, Money totalAmount) {
    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.targetAccountId, amount: totalAmount)
        .addCredit(accountId: cashAccountId, amount: totalAmount)
        .build();
  }

  AccountingResult<JournalEntryDraft> _buildCreditEntry(PurchaseTransaction tx, Money totalAmount) {
    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.targetAccountId, amount: totalAmount)
        .addCredit(accountId: tx.supplierAccountId, amount: totalAmount)
        .build();
  }

  AccountingResult<JournalEntryDraft> _buildMixedEntry(PurchaseTransaction tx, Money totalAmount) {
    final cashPaid = tx.cashPaid;
    final creditAmount = tx.creditAmount;

    final combined = cashPaid + creditAmount;
    if (combined != totalAmount) {
      return AccountingResult.failure(
        ValidationError(
          message:
              'Mixed purchase cashPaid (${cashPaid.amountMinor}) + creditAmount (${creditAmount.amountMinor}) '
              'does not equal totalAmount (${totalAmount.amountMinor})',
          fieldName: 'paymentAmounts',
        ),
      );
    }

    final builder = JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.targetAccountId, amount: totalAmount);

    if (cashPaid.isPositive) {
      builder.addCredit(accountId: cashAccountId, amount: cashPaid);
    }
    if (creditAmount.isPositive) {
      builder.addCredit(accountId: tx.supplierAccountId, amount: creditAmount);
    }

    return builder.build();
  }
}
