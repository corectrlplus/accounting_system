import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../core/sync/idempotency_generator.dart';
import '../../../data/database/app_database.dart';
import '../models/accounting_result.dart';
import '../models/accounting_transaction.dart';
import '../models/journal_entry_draft.dart';
import '../models/transaction_context.dart';
import '../../accounting/repository/journal_entry_repository.dart';

/// Abstract base class for high-level transaction services that orchestrate
/// the full transaction lifecycle: validate inputs, create business document
/// records, build journal entries via engines, and persist everything atomically.
///
/// Subclasses implement [execute] to define their specific validation rules,
/// engine invocation, and atomic persistence logic.
@immutable
abstract class TransactionService<T extends AccountingTransaction, R> {
  final AppDatabase db;
  final JournalEntryRepository journalRepo;

  const TransactionService({required this.db, required this.journalRepo});

  /// Full atomic execution: validate, create document, build + persist journal entry.
  ///
  /// Returns [AccountingResult] containing the created business document on
  /// success, or a typed [AccountingError] on failure.
  Future<AccountingResult<R>> execute(T transaction);

  /// Convert a [JournalEntryDraft] to Drift companions and persist the journal
  /// entry header + lines atomically via [AppDatabase.insertJournalEntryAtomic].
  ///
  /// This helper allows services to include journal entry persistence inside
  /// a larger [db.transaction] alongside business document inserts.
  @protected
  Future<JournalEntryData> persistJournalDraft({
    required JournalEntryDraft draft,
    required TransactionContext context,
  }) async {
    final headerCompanion = JournalEntriesCompanion.insert(
      id: draft.id,
      companyId: draft.companyId,
      entryNumber: draft.entryNumber ?? 0,
      date: draft.dateMs,
      description: draft.description,
      reference: Value<String?>(draft.reference),
      sourceType: draft.sourceType,
      sourceId: draft.sourceId,
      isReversal: Value(draft.isReversal),
      reversedEntryId: Value<String?>(draft.reversedEntryId),
      status: Value(draft.status),
      currencyCode: Value(draft.currencyCode),
      idempotencyKey: draft.idempotencyKey,
      createdBy: draft.createdBy,
      createdAt: context.timestampMs,
      deviceId: context.deviceId,
    );

    final lineCompanions = draft.lines.asMap().entries.map((entry) {
      final line = entry.value;
      return JournalEntryLinesCompanion.insert(
        id: '${draft.id}_line_${entry.key}',
        companyId: draft.companyId,
        journalEntryId: draft.id,
        accountId: line.accountId,
        debitAmount: Value(line.debitAmount.amountMinor),
        creditAmount: Value(line.creditAmount.amountMinor),
        description: Value<String?>(line.description),
        createdAt: context.timestampMs,
      );
    }).toList();

    await db.insertJournalEntryAtomic(
      header: headerCompanion,
      lines: lineCompanions,
    );

    final persisted = await (db.select(db.journalEntries)
          ..where((j) => j.id.equals(draft.id)))
        .getSingle();

    return persisted;
  }

  /// Generate a new UUID v4 for document and journal entry IDs.
  @protected
  String generateId() => IdempotencyGenerator.generateUuid();
}
