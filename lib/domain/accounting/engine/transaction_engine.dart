import '../../../data/database/app_database.dart';
import '../models/accounting_transaction.dart';
import '../models/accounting_result.dart';
import '../models/journal_entry_draft.dart';
import '../repository/journal_entry_repository.dart';

/// Abstract base class for transaction engines that convert domain transactions
/// into balanced, validated journal entries and persist them atomically.
///
/// Each concrete engine encapsulates the accounting rules for a specific transaction
/// type (sale, purchase, payment, etc.) and delegates persistence to a
/// [JournalEntryRepository].
///
/// Subclasses must implement [buildJournalEntry] to construct the balanced
/// journal entry draft for their specific transaction type.
abstract class TransactionEngine<T extends AccountingTransaction> {
  final JournalEntryRepository repository;

  const TransactionEngine(this.repository);

  /// Validate business rules, build a balanced journal entry, and persist atomically.
  ///
  /// Returns [AccountingResult] containing the persisted [JournalEntryData] on
  /// success, or a typed [AccountingError] on failure.
  Future<AccountingResult<JournalEntryData>> execute(T transaction) async {
    final draftResult = buildJournalEntry(transaction);
    if (draftResult.isFailure) {
      return AccountingResult.failure(draftResult.error);
    }
    final result = await repository.persistJournalEntry(
      draft: draftResult.value,
      context: transaction.context,
    );
    if (result.isFailure) {
      return AccountingResult.failure(result.error);
    }
    return AccountingResult.success(result.value as JournalEntryData);
  }

  /// Subclasses implement this to build the balanced journal entry draft.
  ///
  /// Must return a balanced [JournalEntryDraft] where total debits equal
  /// total credits, or an [AccountingResult.failure] if validation fails.
  AccountingResult<JournalEntryDraft> buildJournalEntry(T transaction);
}
