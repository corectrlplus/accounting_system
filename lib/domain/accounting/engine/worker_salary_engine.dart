import 'package:meta/meta.dart';

import '../builder/journal_entry_builder.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transactions/worker_salary_transaction.dart';
import '../repository/journal_entry_repository.dart';
import 'transaction_engine.dart';

/// Transaction engine for worker salary transactions.
///
/// Creates a balanced journal entry for salary payments:
/// - **Always**: Debit Direct Labor (5200) for [WorkerSalaryTransaction.grossSalary].
/// - **If advance deduction > 0**: Credit Worker Advances Receivable for the deduction.
/// - **Always**: Credit Cash/Bank for [WorkerSalaryTransaction.netPayment].
///
/// Invariant: grossSalary == advanceDeduction + netPayment.
@immutable
class WorkerSalaryEngine extends TransactionEngine<WorkerSalaryTransaction> {
  final String directLaborAccountId;

  const WorkerSalaryEngine({
    required JournalEntryRepository repository,
    required this.directLaborAccountId,
  }) : super(repository);

  @override
  AccountingResult<JournalEntryDraft> buildJournalEntry(WorkerSalaryTransaction tx) {
    final combined = tx.advanceDeduction + tx.netPayment;
    if (combined != tx.grossSalary) {
      return AccountingResult.failure(
        ValidationError(
          message:
              'Worker salary imbalance: advanceDeduction (${tx.advanceDeduction.amountMinor}) '
              '+ netPayment (${tx.netPayment.amountMinor}) '
              '!= grossSalary (${tx.grossSalary.amountMinor})',
          fieldName: 'salaryAmounts',
        ),
      );
    }

    final builder = JournalEntryBuilder()
        .setContext(tx.context)
        .setSource(sourceType: tx.sourceType, sourceId: tx.transactionId)
        .setDescription(tx.description)
        .setCurrency(tx.currencyCode)
        .setIdempotencyKey(tx.idempotencyKey)
        .addDebit(accountId: directLaborAccountId, amount: tx.grossSalary);

    if (tx.advanceDeduction.isPositive) {
      builder.addCredit(accountId: tx.workerAccountId, amount: tx.advanceDeduction);
    }

    builder.addCredit(accountId: tx.cashAccountAccountId, amount: tx.netPayment);

    return builder.build();
  }
}
