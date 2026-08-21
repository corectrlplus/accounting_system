import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';
import '../engine/worker_advance_engine.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/transactions/worker_advance_transaction.dart';
import '../../accounting/repository/journal_entry_repository.dart';
import 'transaction_service.dart';

/// High-level service orchestrating the full worker advance lifecycle.
///
/// Lifecycle:
/// 1. Validate amount > 0
/// 2. Build balanced journal entry via [WorkerAdvanceEngine]
/// 3. Persist atomically: journal entry + worker advance record
/// 4. Return the created [WorkerAdvanceData]
@immutable
class WorkerAdvanceService extends TransactionService<WorkerAdvanceTransaction, WorkerAdvanceData> {
  const WorkerAdvanceService({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
  }) : super(db: db, journalRepo: journalRepo);

  @override
  Future<AccountingResult<WorkerAdvanceData>> execute(WorkerAdvanceTransaction tx) async {
    // 1. Validate amount
    if (!tx.amount.isPositive) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Worker advance amount must be positive, got ${tx.amount.amountMinor}',
          fieldName: 'amount',
        ),
      );
    }

    // 2. Build journal entry draft
    final engine = WorkerAdvanceEngine(repository: journalRepo);
    final draftResult = engine.buildJournalEntry(tx);
    if (draftResult.isFailure) {
      return AccountingResult.failure(draftResult.error);
    }
    final draft = draftResult.value;

    // 3. Atomic persistence
    try {
      await db.transaction(() async {
        // Insert journal entry
        await persistJournalDraft(draft: draft, context: tx.context);

        // Insert worker advance record
        await db.into(db.workerAdvances).insert(
              WorkerAdvancesCompanion.insert(
                id: tx.transactionId,
                companyId: tx.companyId,
                workerId: tx.workerId,
                date: tx.dateMs,
                amount: tx.amount.amountMinor,
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

      final advance = await (db.select(db.workerAdvances)
            ..where((w) => w.id.equals(tx.transactionId)))
          .getSingle();

      return AccountingResult.success(advance);
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist worker advance atomically: $e',
          fieldName: 'persistence',
        ),
      );
    }
  }
}
