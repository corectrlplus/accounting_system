import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';
import '../engine/sale_transaction_engine.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/transactions/sale_transaction.dart';
import '../../accounting/repository/journal_entry_repository.dart';
import 'transaction_service.dart';

/// High-level service orchestrating the full sale transaction lifecycle.
///
/// Lifecycle:
/// 1. Validate cashReceived + creditAmount == totalAmount
/// 2. Build balanced journal entry via [SaleTransactionEngine]
/// 3. Compute next auto-incremented sale number
/// 4. Persist atomically: journal entry + sale header + sale items
/// 5. Return the created [SaleData]
@immutable
class SaleTransactionService extends TransactionService<SaleTransaction, SaleData> {
  final String cashAccountId;
  final String salesAccountId;

  const SaleTransactionService({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
    required this.cashAccountId,
    required this.salesAccountId,
  }) : super(db: db, journalRepo: journalRepo);

  @override
  Future<AccountingResult<SaleData>> execute(SaleTransaction tx) async {
    final totalAmount = tx.totalAmount;

    // 1. Validate payment amounts
    if (tx.cashReceived + tx.creditAmount != totalAmount) {
      return AccountingResult.failure(
        ValidationError(
          message:
              'Sale payment mismatch: cashReceived (${tx.cashReceived.amountMinor}) '
              '+ creditAmount (${tx.creditAmount.amountMinor}) '
              '!= totalAmount (${totalAmount.amountMinor})',
          fieldName: 'paymentAmounts',
        ),
      );
    }

    // 2. Build journal entry draft
    final engine = SaleTransactionEngine(
      repository: journalRepo,
      cashAccountId: cashAccountId,
      salesAccountId: salesAccountId,
    );
    final draftResult = engine.buildJournalEntry(tx);
    if (draftResult.isFailure) {
      return AccountingResult.failure(draftResult.error);
    }
    final draft = draftResult.value;

    // 3. Compute next sale number
    final saleNum = await _nextNumber(tx.companyId);

    // 4. Atomic persistence
    try {
      await db.transaction(() async {
        // Insert journal entry
        await persistJournalDraft(draft: draft, context: tx.context);

        // Insert sale header
        await db.into(db.sales).insert(
              SalesCompanion.insert(
                id: tx.transactionId,
                companyId: tx.companyId,
                customerId: Value<String?>.absent(),
                saleNumber: saleNum,
                date: tx.dateMs,
                totalAmount: totalAmount.amountMinor,
                cashReceived: Value(tx.cashReceived.amountMinor),
                creditAmount: Value(tx.creditAmount.amountMinor),
                paymentType: tx.paymentType.name,
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

        // Insert sale items
        for (var i = 0; i < tx.items.length; i++) {
          final item = tx.items[i];
          await db.into(db.saleItems).insert(
                SaleItemsCompanion.insert(
                  id: generateId(),
                  companyId: tx.companyId,
                  saleId: tx.transactionId,
                  description: item.description,
                  quantity: item.quantityMinor,
                  unitPrice: item.unitPrice.amountMinor,
                  totalPrice: item.totalPrice.amountMinor,
                  createdAt: tx.context.timestampMs,
                ),
              );
        }
      });

      final sale = await (db.select(db.sales)
            ..where((s) => s.id.equals(tx.transactionId)))
          .getSingle();

      return AccountingResult.success(sale);
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist sale transaction atomically: $e',
          fieldName: 'persistence',
        ),
      );
    }
  }

  Future<int> _nextNumber(String companyId) async {
    final sales = await (db.select(db.sales)
          ..where((s) => s.companyId.equals(companyId)))
        .get();
    return sales.isEmpty
        ? 1
        : (sales.map((s) => s.saleNumber).reduce((a, b) => a > b ? a : b) + 1);
  }
}
