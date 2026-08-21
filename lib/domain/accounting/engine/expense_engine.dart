import 'package:meta/meta.dart';

import '../builder/journal_entry_builder.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/expense_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for expense transactions.
///
/// Creates a balanced journal entry that debits the expense account
/// (e.g. 6100 Rent, 6200 Utilities) and credits the cash/bank account
/// from which the payment was made.
///
/// Account IDs are derived directly from [ExpenseTransaction]:
/// - Debit: [ExpenseTransaction.expenseAccountAccountId]
/// - Credit: [ExpenseTransaction.cashAccountAccountId]
@immutable
class ExpenseEngine extends TransactionEngine<ExpenseTransaction> {
  const ExpenseEngine({
    required JournalEntryRepository repository,
  }) : super(repository);

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(ExpenseTransaction tx) {
    return JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: tx.expenseAccountAccountId, amount: tx.amount)
        .addCredit(accountId: tx.cashAccountAccountId, amount: tx.amount)
        .build();
  }
}
