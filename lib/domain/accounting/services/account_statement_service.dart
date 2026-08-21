import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

/// Account statement / ledger report service providing a chronological view
/// of all journal entry line activity for a specific account.
///
/// Produces a running balance ledger showing each transaction's debit/credit
/// impact and the cumulative balance after each entry. This is the standard
/// "T-account" ledger view used in financial reporting and auditing.
///
/// Supports optional date range filtering to generate statements for specific
/// accounting periods.
@immutable
class AccountStatementService {
  final AppDatabase db;

  const AccountStatementService(this.db);

  /// Get the complete account statement (ledger) for the specified account.
  ///
  /// Returns a chronologically sorted list of [AccountStatementLine] entries,
  /// each containing the journal entry reference, debit/credit amounts, and
  /// the running balance after that entry.
  ///
  /// The running balance direction follows standard accounting conventions:
  /// - **Debit-normal** (asset, cogs, expense): balance += (debit - credit)
  /// - **Credit-normal** (liability, equity, revenue): balance += (credit - debit)
  ///
  /// Parameters:
  /// - [accountId]: The account to generate the statement for.
  /// - [fromDateMs]: Optional start date filter (Unix ms). Entries before this
  ///   date are excluded. If null, no lower bound is applied.
  /// - [toDateMs]: Optional end date filter (Unix ms). Entries after this date
  ///   are excluded. If null, no upper bound is applied.
  ///
  /// Returns an empty list if the account does not exist or has no activity
  /// within the specified date range.
  Future<List<AccountStatementLine>> getAccountStatement(
    String accountId, {
    int? fromDateMs,
    int? toDateMs,
  }) async {
    // ── Fetch account to determine balance direction ────────────────────────
    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(accountId)))
        .getSingleOrNull();

    if (account == null) return [];

    final isDebitNormal = ['asset', 'cogs', 'expense']
        .contains(account.type.toLowerCase());

    // ── Fetch all journal entry lines for this account ──────────────────────
    final lines = await (db.select(db.journalEntryLines)
          ..where((l) => l.accountId.equals(accountId)))
        .get();

    // ── Build statement lines with running balance ──────────────────────────
    final statementLines = <AccountStatementLine>[];
    int runningBalance = 0;

    for (final line in lines) {
      // Fetch the parent journal entry for date and metadata
      final entry = await (db.select(db.journalEntries)
            ..where((j) => j.id.equals(line.journalEntryId)))
          .getSingleOrNull();

      if (entry == null) continue;

      // Apply date range filters
      if (fromDateMs != null && entry.date < fromDateMs) continue;
      if (toDateMs != null && entry.date > toDateMs) continue;

      // Update running balance based on account type
      runningBalance += isDebitNormal
          ? (line.debitAmount - line.creditAmount)
          : (line.creditAmount - line.debitAmount);

      statementLines.add(AccountStatementLine(
        entryId: entry.id,
        entryNumber: entry.entryNumber,
        dateMs: entry.date,
        description: entry.description,
        sourceType: entry.sourceType,
        isReversal: entry.isReversal,
        debitAmount: line.debitAmount,
        creditAmount: line.creditAmount,
        runningBalance: runningBalance,
      ));
    }

    // Sort chronologically by date
    statementLines.sort((a, b) => a.dateMs.compareTo(b.dateMs));

    return statementLines;
  }
}

/// A single line in the account statement representing one journal entry's
/// impact on the account balance.
@immutable
class AccountStatementLine {
  /// The journal entry identifier this line belongs to.
  final String entryId;

  /// The sequential entry number within the company.
  final int entryNumber;

  /// The journal entry date as Unix milliseconds timestamp.
  final int dateMs;

  /// The journal entry description.
  final String description;

  /// The source transaction type (sale, purchase, customer_payment, etc.).
  final String sourceType;

  /// Whether this journal entry is a reversal entry.
  final bool isReversal;

  /// The debit amount in minor units (x1000) for this line.
  final int debitAmount;

  /// The credit amount in minor units (x1000) for this line.
  final int creditAmount;

  /// The cumulative account balance in minor units (x1000) after this entry.
  final int runningBalance;

  const AccountStatementLine({
    required this.entryId,
    required this.entryNumber,
    required this.dateMs,
    required this.description,
    required this.sourceType,
    required this.isReversal,
    required this.debitAmount,
    required this.creditAmount,
    required this.runningBalance,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountStatementLine &&
          runtimeType == other.runtimeType &&
          entryId == other.entryId &&
          entryNumber == other.entryNumber &&
          dateMs == other.dateMs &&
          description == other.description &&
          sourceType == other.sourceType &&
          isReversal == other.isReversal &&
          debitAmount == other.debitAmount &&
          creditAmount == other.creditAmount &&
          runningBalance == other.runningBalance;

  @override
  int get hashCode =>
      entryId.hashCode ^
      entryNumber.hashCode ^
      dateMs.hashCode ^
      description.hashCode ^
      sourceType.hashCode ^
      isReversal.hashCode ^
      debitAmount.hashCode ^
      creditAmount.hashCode ^
      runningBalance.hashCode;
}
