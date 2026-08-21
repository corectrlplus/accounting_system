import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../core/errors/database_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/idempotency_generator.dart';
import '../../../data/database/app_database.dart';
import '../models/accounting_error.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../models/transaction_context.dart';

/// Financial Correction Engine implementing the Reversal Flow (Spec Section J).
///
/// Executes the canonical five-step reversal protocol for posted transactions:
/// 1. Fetch and validate the original journal entry is in 'posted' status.
/// 2. Fetch original journal entry lines.
/// 3. Create a reversal journal entry with swapped DR/CR amounts.
/// 4. Atomically: mark original entry as 'reversed', mark source document as
///    'reversed', and insert the new reversal entry.
/// 5. Link the reversal entry to the original via [JournalEntryData.reversedEntryId].
///
/// This engine operates directly on [AppDatabase] to guarantee multi-step atomicity
/// across both the journal entry and the source document tables, which cannot be
/// achieved through [JournalEntryRepository] alone.
@immutable
class ReversalEngine {
  final AppDatabase db;

  const ReversalEngine({required this.db});

  /// Reverse a posted journal entry and its associated source document.
  ///
  /// Performs the following atomically within a single SQLite transaction:
  /// - Validates the original entry exists and is in 'posted' status.
  /// - Marks the original entry status as 'reversed'.
  /// - Marks the associated source document status as 'reversed'.
  /// - Creates and inserts a new reversal journal entry with swapped DR/CR lines.
  /// - Links the reversal entry to the original via [JournalEntryData.reversedEntryId].
  ///
  /// Returns [AccountingResult.success] with the persisted reversal [JournalEntryData],
  /// or [AccountingResult.failure] with a typed [AccountingError] if validation fails.
  Future<AccountingResult<JournalEntryData>> reverse({
    required String originalEntryId,
    required TransactionContext context,
    required String reversalDescription,
  }) async {
    try {
      // ── Step 1: Fetch and validate the original entry ──────────────────────
      final original = await (db.select(db.journalEntries)
            ..where((j) => j.id.equals(originalEntryId)))
          .getSingleOrNull();

      if (original == null) {
        return AccountingResult.failure(
          ValidationError(
            message: 'Journal entry $originalEntryId not found',
            fieldName: 'entryId',
          ),
        );
      }

      if (original.status != 'posted') {
        return AccountingResult.failure(
          ImmutableLedgerError(entityId: originalEntryId),
        );
      }

      // ── Step 2: Fetch original lines ──────────────────────────────────────
      final originalLines = await (db.select(db.journalEntryLines)
            ..where((l) => l.journalEntryId.equals(originalEntryId)))
          .get();

      if (originalLines.isEmpty) {
        return AccountingResult.failure(
          ValidationError(
            message: 'Journal entry $originalEntryId has no lines',
            fieldName: 'lines',
          ),
        );
      }

      // ── Step 3: Build reversal draft (swapped DR/CR) ──────────────────────
      final reversalEntryId = IdempotencyGenerator.generateUuid();
      final entryNum = await _nextEntryNumber(original.companyId);
      final currency = original.currencyCode;

      final reversalLines = originalLines.map((line) {
        return JournalLineDraft(
          accountId: line.accountId,
          debitAmount: Money.fromMinor(line.creditAmount, currency),
          creditAmount: Money.fromMinor(line.debitAmount, currency),
          description: line.description,
        );
      }).toList();

      final draft = JournalEntryDraft(
        id: reversalEntryId,
        companyId: original.companyId,
        entryNumber: entryNum,
        dateMs: context.timestampMs,
        description: reversalDescription,
        sourceType: 'reversal',
        sourceId: reversalEntryId,
        isReversal: true,
        reversedEntryId: originalEntryId,
        status: 'posted',
        currencyCode: currency,
        idempotencyKey: '${original.idempotencyKey}:REV',
        createdBy: context.userId,
        lines: reversalLines,
      );

      // ── Step 4: Validate balance after swap ───────────────────────────────
      final balanceResult = draft.validateBalance();
      if (balanceResult.isFailure) {
        return AccountingResult.failure(balanceResult.error);
      }

      // ── Step 5: Atomic multi-table persistence ────────────────────────────
      await db.transaction(() async {
        // 5a. Mark original journal entry as reversed
        await (db.update(db.journalEntries)
              ..where((j) => j.id.equals(originalEntryId)))
            .write(const JournalEntriesCompanion(
              status: Value('reversed'),
            ));

        // 5b. Mark associated source document as reversed
        await _reverseDocument(original.sourceType, original.sourceId);

        // 5c. Insert reversal journal entry + lines atomically
        await db.insertJournalEntryAtomic(
          header: JournalEntriesCompanion.insert(
            id: reversalEntryId,
            companyId: original.companyId,
            entryNumber: entryNum,
            date: context.timestampMs,
            description: reversalDescription,
            sourceType: 'reversal',
            sourceId: reversalEntryId,
            isReversal: const Value(true),
            reversedEntryId: Value(originalEntryId),
            status: const Value('posted'),
            currencyCode: Value(currency),
            idempotencyKey: draft.idempotencyKey,
            createdBy: context.userId,
            createdAt: context.timestampMs,
            deviceId: context.deviceId,
          ),
          lines: draft.lines.asMap().entries.map((entry) {
            final idx = entry.key;
            final line = entry.value;
            return JournalEntryLinesCompanion.insert(
              id: '${reversalEntryId}_line_$idx',
              companyId: original.companyId,
              journalEntryId: reversalEntryId,
              accountId: line.accountId,
              debitAmount: Value(line.debitAmount.amountMinor),
              creditAmount: Value(line.creditAmount.amountMinor),
              description: Value<String?>(line.description),
              createdAt: context.timestampMs,
            );
          }).toList(),
        );
      });

      // ── Step 6: Return persisted reversal entry ───────────────────────────
      final persisted = await (db.select(db.journalEntries)
            ..where((j) => j.id.equals(reversalEntryId)))
          .getSingle();

      return AccountingResult.success(persisted);
    } on LedgerImbalanceException catch (e) {
      return AccountingResult.failure(
        ImbalanceError(
          totalDebit: Money.fromMinor(e.totalDebits, 'IQD'),
          totalCredit: Money.fromMinor(e.totalCredits, 'IQD'),
        ),
      );
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to reverse entry: $e',
          fieldName: 'reversal',
        ),
      );
    }
  }

  /// Mark the source document (sale, purchase, payment, etc.) as 'reversed'
  /// based on its [sourceType] and [sourceId].
  ///
  /// Each supported source type maps to its corresponding Drift table and
  /// updates the status field to 'reversed'.
  Future<void> _reverseDocument(String sourceType, String sourceId) async {
    switch (sourceType) {
      case 'sale':
        await (db.update(db.sales)..where((s) => s.id.equals(sourceId)))
            .write(const SalesCompanion(status: Value('reversed')));
        break;
      case 'purchase':
        await (db.update(db.purchases)..where((p) => p.id.equals(sourceId)))
            .write(const PurchasesCompanion(status: Value('reversed')));
        break;
      case 'customer_payment':
      case 'supplier_payment':
        await (db.update(db.payments)..where((p) => p.id.equals(sourceId)))
            .write(const PaymentsCompanion(status: Value('reversed')));
        break;
      case 'expense':
        await (db.update(db.expenses)..where((e) => e.id.equals(sourceId)))
            .write(const ExpensesCompanion(status: Value('reversed')));
        break;
      case 'worker_advance':
        await (db.update(db.workerAdvances)
              ..where((w) => w.id.equals(sourceId)))
            .write(const WorkerAdvancesCompanion(status: Value('reversed')));
        break;
      case 'worker_salary':
        await (db.update(db.workerSalaries)
              ..where((w) => w.id.equals(sourceId)))
            .write(const WorkerSalariesCompanion(status: Value('reversed')));
        break;
      case 'owner_withdrawal':
        await (db.update(db.ownerWithdrawals)
              ..where((w) => w.id.equals(sourceId)))
            .write(const OwnerWithdrawalsCompanion(status: Value('reversed')));
        break;
      case 'manufacturing':
        await (db.update(db.manufacturingJobs)
              ..where((m) => m.id.equals(sourceId)))
            .write(
                const ManufacturingJobsCompanion(status: Value('reversed')));
        break;
    }
  }

  /// Compute the next sequential journal entry number for the given company.
  ///
  /// Queries all existing entries for the company, finds the maximum entry number,
  /// and returns max + 1. Returns 1 if no entries exist.
  Future<int> _nextEntryNumber(String companyId) async {
    final entries = await (db.select(db.journalEntries)
          ..where((j) => j.companyId.equals(companyId)))
        .get();
    if (entries.isEmpty) return 1;
    return entries.map((e) => e.entryNumber).reduce((a, b) => a > b ? a : b) + 1;
  }
}
