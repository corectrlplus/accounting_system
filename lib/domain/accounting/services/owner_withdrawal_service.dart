import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';
import '../engine/owner_withdrawal_engine.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/transactions/owner_withdrawal_transaction.dart';
import '../../accounting/repository/journal_entry_repository.dart';
import 'transaction_service.dart';

/// High-level service orchestrating the full owner withdrawal lifecycle.
///
/// Lifecycle:
/// 1. Validate amount > 0
/// 2. Build balanced journal entry via [OwnerWithdrawalEngine]
/// 3. Persist atomically: journal entry + owner withdrawal record
/// 4. Return the created [OwnerWithdrawalData]
@immutable
class OwnerWithdrawalService extends TransactionService<OwnerWithdrawalTransaction, OwnerWithdrawalData> {
  const OwnerWithdrawalService({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
  }) : super(db: db, journalRepo: journalRepo);

  @override
  Future<AccountingResult<OwnerWithdrawalData>> execute(OwnerWithdrawalTransaction tx) async {
    // 1. Validate amount
    if (!tx.amount.isPositive) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Owner withdrawal amount must be positive, got ${tx.amount.amountMinor}',
          fieldName: 'amount',
        ),
      );
    }

    // 2. Build journal entry draft
    final engine = OwnerWithdrawalEngine(repository: journalRepo);
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

        // Insert owner withdrawal record
        await db.into(db.ownerWithdrawals).insert(
              OwnerWithdrawalsCompanion.insert(
                id: tx.transactionId,
                companyId: tx.companyId,
                date: tx.dateMs,
                amount: tx.amount.amountMinor,
                paymentMethod: Value(tx.paymentMethod.name),
                description: Value<String?>(tx.description),
                journalEntryId: draft.id,
                status: const Value('posted'),
                createdBy: tx.userId,
                idempotencyKey: tx.idempotencyKey,
                createdAt: tx.context.timestampMs,
                updatedAt: tx.context.timestampMs,
                deviceId: tx.deviceId,
              ),
            );
      });

      final withdrawal = await (db.select(db.ownerWithdrawals)
            ..where((o) => o.id.equals(tx.transactionId)))
          .getSingle();

      return AccountingResult.success(withdrawal);
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist owner withdrawal atomically: $e',
          fieldName: 'persistence',
        ),
      );
    }
  }
}
