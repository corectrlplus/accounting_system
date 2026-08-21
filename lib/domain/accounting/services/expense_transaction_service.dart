import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';
import '../engine/expense_engine.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/transactions/expense_transaction.dart';
import '../../accounting/repository/journal_entry_repository.dart';
import 'transaction_service.dart';

/// High-level service orchestrating the full expense transaction lifecycle.
///
/// Lifecycle:
/// 1. Validate amount > 0
/// 2. Build balanced journal entry via [ExpenseEngine]
/// 3. Compute next auto-incremented expense number
/// 4. Persist atomically: journal entry + expense record
/// 5. Return the created [ExpenseData]
@immutable
class ExpenseTransactionService extends TransactionService<ExpenseTransaction, ExpenseData> {
  const ExpenseTransactionService({
    required AppDatabase db,
    required JournalEntryRepository journalRepo,
  }) : super(db: db, journalRepo: journalRepo);

  @override
  Future<AccountingResult<ExpenseData>> execute(ExpenseTransaction tx) async {
    // 1. Validate amount
    if (!tx.amount.isPositive) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Expense amount must be positive, got ${tx.amount.amountMinor}',
          fieldName: 'amount',
        ),
      );
    }

    // 2. Build journal entry draft
    final engine = ExpenseEngine(repository: journalRepo);
    final draftResult = engine.buildJournalEntry(tx);
    if (draftResult.isFailure) {
      return AccountingResult.failure(draftResult.error);
    }
    final draft = draftResult.value;

    // 3. Compute next expense number
    final expenseNum = await _nextNumber(tx.companyId);

    // 4. Atomic persistence
    try {
      await db.transaction(() async {
        // Insert journal entry
        await persistJournalDraft(draft: draft, context: tx.context);

        // Insert expense record
        await db.into(db.expenses).insert(
              ExpensesCompanion.insert(
                id: tx.transactionId,
                companyId: tx.companyId,
                expenseNumber: expenseNum,
                date: tx.dateMs,
                amount: tx.amount.amountMinor,
                expenseCategoryId: tx.expenseCategoryId,
                paymentMethod: tx.paymentMethod.name,
                description: Value<String?>(tx.description),
                currencyCode: Value(tx.currencyCode),
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

      final expense = await (db.select(db.expenses)
            ..where((e) => e.id.equals(tx.transactionId)))
          .getSingle();

      return AccountingResult.success(expense);
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist expense transaction atomically: $e',
          fieldName: 'persistence',
        ),
      );
    }
  }

  Future<int> _nextNumber(String companyId) async {
    final expenses = await (db.select(db.expenses)
          ..where((e) => e.companyId.equals(companyId)))
        .get();
    return expenses.isEmpty
        ? 1
        : (expenses.map((e) => e.expenseNumber).reduce((a, b) => a > b ? a : b) + 1);
  }
}
