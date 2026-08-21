import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';
import '../engine/supplier_payment_engine.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/transactions/supplier_payment_transaction.dart';
import '../../accounting/repository/journal_entry_repository.dart';
import 'transaction_service.dart';

/// High-level service orchestrating the full supplier payment lifecycle.
///
/// Lifecycle:
/// 1. Validate amount > 0
/// 2. Build balanced journal entry via [SupplierPaymentEngine]
/// 3. Compute next auto-incremented payment number
/// 4. Persist atomically: journal entry + payment record
/// 5. Return the created [PaymentData]
@immutable
class SupplierPaymentService extends TransactionService<SupplierPaymentTransaction, PaymentData> {
  final String cashAccountId;
  final String bankAccountId;

  const SupplierPaymentService({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
    required this.cashAccountId,
    required this.bankAccountId,
  }) : super(db: db, journalRepo: journalRepo);

  @override
  Future<AccountingResult<PaymentData>> execute(SupplierPaymentTransaction tx) async {
    // 1. Validate amount
    if (!tx.amount.isPositive) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Supplier payment amount must be positive, got ${tx.amount.amountMinor}',
          fieldName: 'amount',
        ),
      );
    }

    // 2. Build journal entry draft
    final engine = SupplierPaymentEngine(
      repository: journalRepo,
      cashAccountId: cashAccountId,
      bankAccountId: bankAccountId,
    );
    final draftResult = engine.buildJournalEntry(tx);
    if (draftResult.isFailure) {
      return AccountingResult.failure(draftResult.error);
    }
    final draft = draftResult.value;

    // 3. Compute next payment number
    final paymentNum = await _nextNumber(tx.companyId);

    // 4. Atomic persistence
    try {
      await db.transaction(() async {
        // Insert journal entry
        await persistJournalDraft(draft: draft, context: tx.context);

        // Insert payment record
        await db.into(db.payments).insert(
              PaymentsCompanion.insert(
                id: tx.transactionId,
                companyId: tx.companyId,
                paymentNumber: paymentNum,
                date: tx.dateMs,
                amount: tx.amount.amountMinor,
                paymentMethod: tx.paymentMethod.name,
                direction: 'outgoing',
                customerId: Value<String?>.absent(),
                supplierId: Value<String?>(tx.supplierId),
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
      });

      final payment = await (db.select(db.payments)
            ..where((p) => p.id.equals(tx.transactionId)))
          .getSingle();

      return AccountingResult.success(payment);
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist supplier payment atomically: $e',
          fieldName: 'persistence',
        ),
      );
    }
  }

  Future<int> _nextNumber(String companyId) async {
    final payments = await (db.select(db.payments)
          ..where((p) => p.companyId.equals(companyId) & p.direction.equals('outgoing')))
        .get();
    return payments.isEmpty
        ? 1
        : (payments.map((p) => p.paymentNumber).reduce((a, b) => a > b ? a : b) + 1);
  }
}
