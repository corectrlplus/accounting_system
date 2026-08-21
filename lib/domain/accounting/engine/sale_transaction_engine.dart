import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../builder/journal_entry_builder.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/sale_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for sale transactions.
///
/// Creates balanced journal entries for sales based on payment type:
/// - **Cash**: Debit Cash, Credit Sales Revenue.
/// - **Credit**: Debit Accounts Receivable, Credit Sales Revenue.
/// - **Mixed**: Debit Cash (cash portion), Debit Accounts Receivable (credit portion),
///   Credit Sales Revenue (total).
@immutable
class SaleTransactionEngine extends TransactionEngine<SaleTransaction> {
  final String cashAccountId;
  final String salesAccountId;

  const SaleTransactionEngine({
    required JournalEntryRepository repository,
    required this.cashAccountId,
    required this.salesAccountId,
  }) : super(repository);

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(SaleTransaction tx) {
    final totalAmount = tx.totalAmount;

    if (tx.paymentType == SalePaymentType.cash) {
      return _buildCashEntry(tx, totalAmount);
    } else if (tx.paymentType == SalePaymentType.credit) {
      return _buildCreditEntry(tx, totalAmount);
    } else {
      return _buildMixedEntry(tx, totalAmount);
    }
  }

  AccountingResult<JournalEntryDraft> _buildCashEntry(SaleTransaction tx, Money totalAmount) {
    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: cashAccountId, amount: totalAmount)
        .addCredit(accountId: salesAccountId, amount: totalAmount)
        .build();
  }

  AccountingResult<JournalEntryDraft> _buildCreditEntry(SaleTransaction tx, Money totalAmount) {
    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.customerAccountId, amount: totalAmount)
        .addCredit(accountId: salesAccountId, amount: totalAmount)
        .build();
  }

  AccountingResult<JournalEntryDraft> _buildMixedEntry(SaleTransaction tx, Money totalAmount) {
    final cashReceived = tx.cashReceived;
    final creditAmount = tx.creditAmount;

    final combined = cashReceived + creditAmount;
    if (combined != totalAmount) {
      return AccountingResult.failure(
        ValidationError(
          message:
              'Mixed sale cashReceived (${cashReceived.amountMinor}) + creditAmount (${creditAmount.amountMinor}) '
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
        .setIdempotencyKey(tx.idempotencyKey);

    if (cashReceived.isPositive) {
      builder.addDebit(accountId: cashAccountId, amount: cashReceived);
    }
    if (creditAmount.isPositive) {
      builder.addDebit(accountId: tx.customerAccountId, amount: creditAmount);
    }

    builder.addCredit(accountId: salesAccountId, amount: totalAmount);

    return builder.build();
  }
}
