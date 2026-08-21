import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

/// Trial balance report service generating a list of all active accounts
/// with their debit/credit totals and net balances.
///
/// The trial balance is a fundamental financial report verifying that:
/// - Total debits equal total credits across all accounts (accounting equation).
/// - All account balances are correctly derived from journal entry lines.
///
/// Only active accounts with non-zero activity are included in the output.
/// Accounts are sorted by their chart of accounts code in ascending order.
@immutable
class TrialBalanceService {
  final AppDatabase db;

  const TrialBalanceService(this.db);

  /// Generate a trial balance for the specified company.
  ///
  /// Queries all active accounts and their associated journal entry lines,
  /// computing the total debit, total credit, and net balance for each account.
  ///
  /// Balance direction follows standard accounting conventions:
  /// - **Debit-normal** (asset, cogs, expense): balance = totalDebit - totalCredit
  /// - **Credit-normal** (liability, equity, revenue): balance = totalCredit - totalDebit
  ///
  /// Returns a list of [TrialBalanceLine] sorted by account code ascending.
  /// Only accounts with non-zero debit or credit totals are included.
  Future<List<TrialBalanceLine>> generate(String companyId) async {
    final accounts = await (db.select(db.accounts)
          ..where((a) =>
              a.companyId.equals(companyId) & a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm.asc(a.code)]))
        .get();

    final lines = <TrialBalanceLine>[];

    for (final account in accounts) {
      final journalLines = await (db.select(db.journalEntryLines)
            ..where((l) => l.accountId.equals(account.id)))
          .get();

      int totalDebit = 0;
      int totalCredit = 0;

      for (final line in journalLines) {
        totalDebit += line.debitAmount;
        totalCredit += line.creditAmount;
      }

      // Skip accounts with no activity
      if (totalDebit == 0 && totalCredit == 0) continue;

      final isDebitNormal = ['asset', 'cogs', 'expense']
          .contains(account.type.toLowerCase());

      final balance = isDebitNormal
          ? (totalDebit - totalCredit)
          : (totalCredit - totalDebit);

      lines.add(TrialBalanceLine(
        accountId: account.id,
        accountCode: account.code,
        accountNameAr: account.nameAr,
        accountType: account.type,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        balance: balance,
      ));
    }

    return lines;
  }
}

/// A single line in the trial balance report representing one account's
/// aggregated debit, credit, and net balance figures.
@immutable
class TrialBalanceLine {
  /// The unique account identifier.
  final String accountId;

  /// The chart of accounts code (e.g. '1110', '4100').
  final String accountCode;

  /// The Arabic account name.
  final String accountNameAr;

  /// The account type (asset, liability, equity, revenue, cogs, expense).
  final String accountType;

  /// Sum of all debit amounts across journal entry lines for this account.
  final int totalDebit;

  /// Sum of all credit amounts across journal entry lines for this account.
  final int totalCredit;

  /// Net balance in minor units (x1000).
  /// Debit-normal: totalDebit - totalCredit
  /// Credit-normal: totalCredit - totalDebit
  final int balance;

  const TrialBalanceLine({
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.accountType,
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
  });

  /// Whether this account's total debits equal total credits.
  bool get isBalanced => totalDebit == totalCredit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrialBalanceLine &&
          runtimeType == other.runtimeType &&
          accountId == other.accountId &&
          accountCode == other.accountCode &&
          accountNameAr == other.accountNameAr &&
          accountType == other.accountType &&
          totalDebit == other.totalDebit &&
          totalCredit == other.totalCredit &&
          balance == other.balance;

  @override
  int get hashCode =>
      accountId.hashCode ^
      accountCode.hashCode ^
      accountNameAr.hashCode ^
      accountType.hashCode ^
      totalDebit.hashCode ^
      totalCredit.hashCode ^
      balance.hashCode;
}
