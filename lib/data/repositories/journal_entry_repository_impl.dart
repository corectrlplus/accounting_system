import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';
import '../../domain/accounting/models/transaction_context.dart';
import '../../domain/accounting/models/journal_entry_draft.dart';
import '../../domain/accounting/models/accounting_result.dart';
import '../../domain/accounting/models/accounting_error.dart';
import '../../domain/accounting/repository/journal_entry_repository.dart';
import '../../core/errors/database_exception.dart';
import '../../core/money/money.dart';

/// Data layer implementation of [JournalEntryRepository] performing account validation,
/// idempotency checking, and atomic SQLite database persistence.
class JournalEntryRepositoryImpl implements JournalEntryRepository {
  final AppDatabase db;

  JournalEntryRepositoryImpl(this.db);

  @override
  Future<AccountingResult<JournalEntryData>> persistJournalEntry({
    required JournalEntryDraft draft,
    required TransactionContext context,
  }) async {
    // 1. Company Isolation Check on Context
    if (draft.companyId != context.companyId) {
      return AccountingResult.failure(
        CompanyMismatchError(
          expectedCompanyId: context.companyId,
          actualCompanyId: draft.companyId,
        ),
      );
    }

    // 2. Account Existence, Company Ownership, & Active Status Validation
    final accountIds = draft.lines.map((l) => l.accountId).toSet();
    for (final accId in accountIds) {
      final account = await (db.select(db.accounts)..where((a) => a.id.equals(accId))).getSingleOrNull();

      if (account == null) {
        return AccountingResult.failure(
          ValidationError(
            message: 'Account $accId does not exist',
            fieldName: 'accountId',
          ),
        );
      }

      if (account.companyId != context.companyId) {
        return AccountingResult.failure(
          CompanyMismatchError(
            expectedCompanyId: context.companyId,
            actualCompanyId: account.companyId,
          ),
        );
      }

      if (!account.isActive) {
        return AccountingResult.failure(
          ValidationError(
            message: 'Account $accId is inactive and cannot accept journal entries',
            fieldName: 'accountId',
          ),
        );
      }
    }

    // 3. Idempotency Check (Duplicate Transaction Protection)
    final existingEntry = await (db.select(db.journalEntries)
          ..where((j) => j.idempotencyKey.equals(draft.idempotencyKey) & j.companyId.equals(context.companyId)))
        .getSingleOrNull();

    if (existingEntry != null) {
      return AccountingResult.failure(
        IdempotencyError(idempotencyKey: draft.idempotencyKey),
      );
    }

    // 4. Draft Balance Check
    final balanceValidation = draft.validateBalance();
    if (balanceValidation.isFailure) {
      return AccountingResult.failure(balanceValidation.error);
    }

    // 5. Convert Draft to Drift Companions
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

    final lineCompanions = draft.lines.map((line) {
      return JournalEntryLinesCompanion.insert(
        id: '${draft.id}_line_${draft.lines.indexOf(line)}',
        companyId: draft.companyId,
        journalEntryId: draft.id,
        accountId: line.accountId,
        debitAmount: Value(line.debitAmount.amountMinor),
        creditAmount: Value(line.creditAmount.amountMinor),
        description: Value<String?>(line.description),
        createdAt: context.timestampMs,
      );
    }).toList();

    // 6. Atomic Persistence Execution
    try {
      await db.insertJournalEntryAtomic(
        header: headerCompanion,
        lines: lineCompanions,
      );

      final persisted = await (db.select(db.journalEntries)..where((j) => j.id.equals(draft.id))).getSingle();
      return AccountingResult.success(persisted);
    } on LedgerImbalanceException catch (e) {
      return AccountingResult.failure(
        ImbalanceError(
          totalDebit: Money.fromMinor(e.totalDebits, draft.currencyCode),
          totalCredit: Money.fromMinor(e.totalCredits, draft.currencyCode),
        ),
      );
    } catch (e) {
      return AccountingResult.failure(
        ValidationError(
          message: 'Failed to persist journal entry atomically: $e',
          fieldName: 'journalEntry',
        ),
      );
    }
  }
}
