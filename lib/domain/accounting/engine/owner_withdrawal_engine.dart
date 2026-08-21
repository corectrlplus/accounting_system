import 'package:meta/meta.dart';

import '../builder/journal_entry_builder.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/owner_withdrawal_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for owner withdrawal transactions.
///
/// Creates a balanced journal entry that debits Owner Drawings (3300) and
/// credits the cash/bank account. This reduces owner's equity without
/// affecting the income statement.
///
/// Account IDs are derived directly from [OwnerWithdrawalTransaction]:
/// - Debit: [OwnerWithdrawalTransaction.ownerDrawingAccountId] (3300)
/// - Credit: [OwnerWithdrawalTransaction.cashAccountAccountId]
@immutable
class OwnerWithdrawalEngine extends TransactionEngine<OwnerWithdrawalTransaction> {
  const OwnerWithdrawalEngine({
    required JournalEntryRepository repository,
  }) : super(repository);

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(OwnerWithdrawalTransaction tx) {
    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.ownerDrawingAccountId, amount: tx.amount)
        .addCredit(accountId: tx.cashAccountAccountId, amount: tx.amount)
        .build();
  }
}
