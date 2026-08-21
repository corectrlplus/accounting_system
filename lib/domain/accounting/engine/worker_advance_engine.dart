import 'package:meta/meta.dart';

import '../builder/journal_entry_builder.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/worker_advance_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for worker advance transactions.
///
/// Creates a balanced journal entry that debits the Worker Advances Receivable
/// sub-account (2200) and credits the cash/bank account. This advance is
/// later deducted from the worker's salary via [WorkerSalaryEngine].
///
/// Account IDs are derived directly from [WorkerAdvanceTransaction]:
/// - Debit: [WorkerAdvanceTransaction.workerAccountId] (2200 series)
/// - Credit: [WorkerAdvanceTransaction.cashAccountAccountId]
@immutable
class WorkerAdvanceEngine extends TransactionEngine<WorkerAdvanceTransaction> {
  const WorkerAdvanceEngine({
    required JournalEntryRepository repository,
  }) : super(repository);

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(WorkerAdvanceTransaction tx) {
    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.workerAccountId, amount: tx.amount)
        .addCredit(accountId: tx.cashAccountAccountId, amount: tx.amount)
        .build();
  }
}
