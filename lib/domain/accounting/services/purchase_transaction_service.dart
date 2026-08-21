import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';
import '../engine/purchase_transaction_engine.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/transactions/purchase_transaction.dart';
import '../../accounting/repository/journal_entry_repository.dart';
import 'transaction_service.dart';

/// High-level service orchestrating the full purchase transaction lifecycle.
///
/// Lifecycle:
/// 1. Validate cashPaid + creditAmount == totalAmount
/// 2. Build balanced journal entry via [PurchaseTransactionEngine]
/// 3. Compute next auto-incremented purchase number
/// 4. Persist atomically: journal entry + purchase header + purchase items
/// 5. Return the created [PurchaseData]
@immutable
class PurchaseTransactionService extends TransactionService<PurchaseTransaction, PurchaseData> {
  final String cashAccountId;

  const PurchaseTransactionService({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
    required this.cashAccountId,
  }) : super(db: db, journalRepo: journalRepo);

  @override
  Future<AccountingResult<PurchaseData>> execute(PurchaseTransaction tx) async {
    final totalAmount = tx.totalAmount;

    // 1. Validate payment amounts
    if (tx.cashPaid + tx.creditAmount != totalAmount) {
      return AccountingResult.failure(
        ValidationError(
          message:
              'Purchase payment mismatch: cashPaid (${tx.cashPaid.amountMinor}) '
              '+ creditAmount (${tx.creditAmount.amountMinor}) '
              '!= totalAmount (${totalAmount.amountMinor})',
          fieldName: 'paymentAmounts',
        ),
      );
    }

    // 2. Build journal entry draft
    final engine = PurchaseTransactionEngine(
      repository: journalRepo,
      cashAccountId: cashAccountId,
    );
    final draftResult = engine.buildJournalEntry(tx);
    if (draftResult.isFailure) {
      return AccountingResult.failure(draftResult.error);
    }
    final draft = draftResult.value;

    // 3. Compute next purchase number
    final purchaseNum = await _nextNumber(tx.companyId);

    // 4. Atomic persistence
    try {
      await db.transaction(() async {
        // Insert journal entry
        await persistJournalDraft(draft: draft, context: tx.context);

        // Insert purchase header
        await db.into(db.purchases).insert(
              PurchasesCompanion.insert(
                id: tx.transactionId,
                companyId: tx.companyId,
                supplierId: Value<String?>.absent(),
                purchaseNumber: purchaseNum,
                date: tx.dateMs,
                totalAmount: totalAmount.amountMinor,
                cashPaid: Value(tx.cashPaid.amountMinor),
                creditAmount: Value(tx.creditAmount.amountMinor),
                paymentType: tx.paymentType.name,
                accountingNature: tx.accountingNature.name,
                targetAccountId: tx.targetAccountId,
                currencyCode: Value(tx.currencyCode),
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

        // Insert purchase items
        for (var i = 0; i < tx.items.length; i++) {
          final item = tx.items[i];
          await db.into(db.purchaseItems).insert(
                PurchaseItemsCompanion.insert(
                  id: generateId(),
                  companyId: tx.companyId,
                  purchaseId: tx.transactionId,
                  description: item.description,
                  quantity: item.quantityMinor,
                  unitPrice: item.unitPrice.amountMinor,
                  totalPrice: item.totalPrice.amountMinor,
                  createdAt: tx.context.timestampMs,
                ),
              );
        }
      });

      final purchase = await (db.select(db.purchases)
            ..where((p) => p.id.equals(tx.transactionId)))
          .getSingle();

      return AccountingResult.success(purchase);
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist purchase transaction atomically: $e',
          fieldName: 'persistence',
        ),
      );
    }
  }

  Future<int> _nextNumber(String companyId) async {
    final purchases = await (db.select(db.purchases)
          ..where((p) => p.companyId.equals(companyId)))
        .get();
    return purchases.isEmpty
        ? 1
        : (purchases.map((p) => p.purchaseNumber).reduce((a, b) => a > b ? a : b) + 1);
  }
}
