import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../../../data/database/app_database.dart';
import '../engine/worker_salary_engine.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/transactions/worker_salary_transaction.dart';
import '../../accounting/repository/journal_entry_repository.dart';
import 'transaction_service.dart';

/// High-level service orchestrating the full worker salary lifecycle.
///
/// Lifecycle:
/// 1. Validate advanceDeduction + netPayment == grossSalary
/// 2. Optionally verify advance deduction does not exceed outstanding advance balance
/// 3. Build balanced journal entry via [WorkerSalaryEngine]
/// 4. Persist atomically: journal entry + worker salary record
/// 5. Return the created [WorkerSalaryData]
@immutable
class WorkerSalaryService extends TransactionService<WorkerSalaryTransaction, WorkerSalaryData> {
  final String directLaborAccountId;

  const WorkerSalaryService({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
    required this.directLaborAccountId,
  }) : super(db: db, journalRepo: journalRepo);

  @override
  Future<AccountingResult<WorkerSalaryData>> execute(WorkerSalaryTransaction tx) async {
    // 1. Validate salary amounts invariant
    if (tx.advanceDeduction + tx.netPayment != tx.grossSalary) {
      return AccountingResult.failure(
        ValidationError(
          message:
              'Worker salary invariant violated: advanceDeduction (${tx.advanceDeduction.amountMinor}) '
              '+ netPayment (${tx.netPayment.amountMinor}) '
              '!= grossSalary (${tx.grossSalary.amountMinor})',
          fieldName: 'salaryAmounts',
        ),
      );
    }

    // 2. Validate advance deduction is non-negative
    if (tx.advanceDeduction.isNegative) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Advance deduction cannot be negative, got ${tx.advanceDeduction.amountMinor}',
          fieldName: 'advanceDeduction',
        ),
      );
    }

    // 3. Validate net payment is non-negative
    if (tx.netPayment.isNegative) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Net payment cannot be negative, got ${tx.netPayment.amountMinor}',
          fieldName: 'netPayment',
        ),
      );
    }

    // 4. Check advance balance if deduction > 0
    if (tx.advanceDeduction.isPositive) {
      final availableAdvance = await _deriveAdvanceBalance(
        workerId: tx.workerId,
        workerAccountId: tx.workerAccountId,
        companyId: tx.companyId,
      );
      if (tx.advanceDeduction > availableAdvance) {
        return AccountingResult.failure(
          InsufficientAdvanceBalanceError(
            workerId: tx.workerId,
            availableAdvance: availableAdvance,
            attemptedDeduction: tx.advanceDeduction,
          ),
        );
      }
    }

    // 5. Build journal entry draft
    final engine = WorkerSalaryEngine(
      repository: journalRepo,
      directLaborAccountId: directLaborAccountId,
    );
    final draftResult = engine.buildJournalEntry(tx);
    if (draftResult.isFailure) {
      return AccountingResult.failure(draftResult.error);
    }
    final draft = draftResult.value;

    // 6. Atomic persistence
    try {
      await db.transaction(() async {
        // Insert journal entry
        await persistJournalDraft(draft: draft, context: tx.context);

        // Insert worker salary record
        await db.into(db.workerSalaries).insert(
              WorkerSalariesCompanion.insert(
                id: tx.transactionId,
                companyId: tx.companyId,
                workerId: tx.workerId,
                date: tx.dateMs,
                grossSalary: tx.grossSalary.amountMinor,
                advanceDeduction: Value(tx.advanceDeduction.amountMinor),
                netPayment: tx.netPayment.amountMinor,
                paymentMethod: Value(tx.paymentMethod.name),
                journalEntryId: draft.id,
                status: const Value('posted'),
                notes: Value<String?>.absent(),
                createdBy: tx.userId,
                idempotencyKey: tx.idempotencyKey,
                createdAt: tx.context.timestampMs,
                updatedAt: tx.context.timestampMs,
                deviceId: tx.deviceId,
              ),
            );
      });

      final salary = await (db.select(db.workerSalaries)
            ..where((w) => w.id.equals(tx.transactionId)))
          .getSingle();

      return AccountingResult.success(salary);
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist worker salary atomically: $e',
          fieldName: 'persistence',
        ),
      );
    }
  }

  /// Derive the worker's outstanding advance balance from journal entry lines.
  ///
  /// The Worker Advances Receivable account (2200) is debited when advances are
  /// given and credited when salary deductions occur. The running balance equals
  /// SUM(debit) - SUM(credit) for this asset-type account.
  Future<Money> _deriveAdvanceBalance({
    required String workerId,
    required String workerAccountId,
    required String companyId,
  }) async {
    final totalDebit = await _sumJournalLines(
      accountId: workerAccountId,
      companyId: companyId,
      isDebit: true,
    );
    final totalCredit = await _sumJournalLines(
      accountId: workerAccountId,
      companyId: companyId,
      isDebit: false,
    );

    return Money.fromMinor(totalDebit - totalCredit);
  }

  Future<int> _sumJournalLines({
    required String accountId,
    required String companyId,
    required bool isDebit,
  }) async {
    final lines = await (db.select(db.journalEntryLines)
          ..where((l) => l.accountId.equals(accountId) & l.companyId.equals(companyId)))
        .get();

    int total = 0;
    for (final line in lines) {
      total += isDebit ? line.debitAmount : line.creditAmount;
    }
    return total;
  }
}
