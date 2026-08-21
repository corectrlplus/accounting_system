import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';
import '../engine/manufacturing_job_engine.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/transactions/manufacturing_job_transaction.dart';
import '../../accounting/repository/journal_entry_repository.dart';
import 'transaction_service.dart';

/// High-level service orchestrating the full manufacturing job lifecycle.
///
/// Lifecycle:
/// 1. Validate totalCost > 0
/// 2. Build balanced journal entry via [ManufacturingJobEngine]
/// 3. Compute next auto-incremented job number
/// 4. Persist atomically: journal entry + manufacturing job record
/// 5. Return the created [ManufacturingJobData]
@immutable
class ManufacturingJobService extends TransactionService<ManufacturingJobTransaction, ManufacturingJobData> {
  const ManufacturingJobService({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
  }) : super(db: db, journalRepo: journalRepo);

  @override
  Future<AccountingResult<ManufacturingJobData>> execute(ManufacturingJobTransaction tx) async {
    // 1. Validate total cost
    if (!tx.totalCost.isPositive) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Manufacturing job total cost must be positive, got ${tx.totalCost.amountMinor}',
          fieldName: 'totalCost',
        ),
      );
    }

    // 2. Build journal entry draft
    final engine = ManufacturingJobEngine(repository: journalRepo);
    final draftResult = engine.buildJournalEntry(tx);
    if (draftResult.isFailure) {
      return AccountingResult.failure(draftResult.error);
    }
    final draft = draftResult.value;

    // 3. Compute next job number
    final jobNum = await _nextNumber(tx.companyId);

    // 4. Atomic persistence
    try {
      await db.transaction(() async {
        // Insert journal entry
        await persistJournalDraft(draft: draft, context: tx.context);

        // Insert manufacturing job record
        await db.into(db.manufacturingJobs).insert(
              ManufacturingJobsCompanion.insert(
                id: tx.transactionId,
                companyId: tx.companyId,
                jobNumber: jobNum,
                workshopId: tx.workshopId,
                workType: tx.workType,
                scenario: tx.scenario.name,
                accountingTreatment: tx.accountingTreatment.name,
                totalCost: tx.totalCost.amountMinor,
                date: tx.dateMs,
                customerId: Value<String?>(tx.customerId),
                responsiblePerson: Value<String?>.absent(),
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

      final job = await (db.select(db.manufacturingJobs)
            ..where((m) => m.id.equals(tx.transactionId)))
          .getSingle();

      return AccountingResult.success(job);
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist manufacturing job atomically: $e',
          fieldName: 'persistence',
        ),
      );
    }
  }

  Future<int> _nextNumber(String companyId) async {
    final jobs = await (db.select(db.manufacturingJobs)
          ..where((j) => j.companyId.equals(companyId)))
        .get();
    return jobs.isEmpty
        ? 1
        : (jobs.map((j) => j.jobNumber).reduce((a, b) => a > b ? a : b) + 1);
  }
}
