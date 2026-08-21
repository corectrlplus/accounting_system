import '../models/transaction_context.dart';
import '../models/journal_entry_draft.dart';
import '../models/accounting_result.dart';

/// Contract for persisting balanced journal entries atomically with account & idempotency validation.
abstract class JournalEntryRepository {
  /// Validate referenced accounts, enforce idempotency, and persist journal entry header + lines atomically.
  Future<AccountingResult<dynamic>> persistJournalEntry({
    required JournalEntryDraft draft,
    required TransactionContext context,
  });
}
