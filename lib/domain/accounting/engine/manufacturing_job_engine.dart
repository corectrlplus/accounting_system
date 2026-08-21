import 'package:meta/meta.dart';

import '../builder/journal_entry_builder.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/manufacturing_job_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for manufacturing job transactions.
///
/// Creates a balanced journal entry that debits the target cost account
/// (determined by [ManufacturingJobTransaction.scenario] and
/// [ManufacturingJobTransaction.accountingTreatment]) and credits the
/// cash/bank account.
///
/// Account IDs are derived directly from [ManufacturingJobTransaction]:
/// - Debit: [ManufacturingJobTransaction.targetAccountId]
/// - Credit: [ManufacturingJobTransaction.cashAccountAccountId]
@immutable
class ManufacturingJobEngine extends TransactionEngine<ManufacturingJobTransaction> {
  const ManufacturingJobEngine({
    required JournalEntryRepository repository,
  }) : super(repository);

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(ManufacturingJobTransaction tx) {
    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.targetAccountId, amount: tx.totalCost)
        .addCredit(accountId: tx.cashAccountAccountId, amount: tx.totalCost)
        .build();
  }
}
