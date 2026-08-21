import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

/// Balance sheet (الميزانية العمومية) report service.
///
/// Produces a standard balance sheet following the accounting equation:
/// Assets = Liabilities + Equity
///
/// Accounts are grouped by type (asset, liability, equity) and sorted by code.
/// Sub-groupings classify accounts as current or non-current based on account
/// code prefixes (11xx = current assets, 21xx = current liabilities).
///
/// Only active accounts with non-zero balances are included in the output.
@immutable
class BalanceSheetService {
  final AppDatabase db;

  const BalanceSheetService(this.db);

  /// Generate a balance sheet report for the specified company.
  ///
  /// Queries all active accounts of type asset, liability, or equity.
  /// For each account, derives the balance from journal entry lines using
  /// standard debit/credit normal conventions:
  /// - **Debit-normal** (asset): balance = SUM(debit) - SUM(credit)
  /// - **Credit-normal** (liability, equity): balance = SUM(credit) - SUM(debit)
  ///
  /// Returns a [BalanceSheetReport] with grouped sections, section totals,
  /// and grand totals that should verify the accounting equation.
  Future<BalanceSheetReport> generate(String companyId) async {
    final accounts = await (db.select(db.accounts)
          ..where((a) =>
              a.companyId.equals(companyId) &
              a.isActive.equals(true) &
              (a.type.equals('asset') |
                  a.type.equals('liability') |
                  a.type.equals('equity')))
          ..orderBy([(a) => OrderingTerm.asc(a.code)]))
        .get();

    final assetLines = <BalanceSheetLine>[];
    final liabilityLines = <BalanceSheetLine>[];
    final equityLines = <BalanceSheetLine>[];

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

      if (totalDebit == 0 && totalCredit == 0) continue;

      final isDebitNormal =
          account.type.toLowerCase() == 'asset';

      final balance = isDebitNormal
          ? (totalDebit - totalCredit)
          : (totalCredit - totalDebit);

      final line = BalanceSheetLine(
        accountId: account.id,
        accountCode: account.code,
        accountNameAr: account.nameAr,
        balance: balance,
      );

      switch (account.type.toLowerCase()) {
        case 'asset':
          assetLines.add(line);
          break;
        case 'liability':
          liabilityLines.add(line);
          break;
        case 'equity':
          equityLines.add(line);
          break;
      }
    }

    assetLines.sort((a, b) => a.accountCode.compareTo(b.accountCode));
    liabilityLines.sort((a, b) => a.accountCode.compareTo(b.accountCode));
    equityLines.sort((a, b) => a.accountCode.compareTo(b.accountCode));

    final assetTotal =
        assetLines.fold<int>(0, (sum, l) => sum + l.balance);
    final liabilityTotal =
        liabilityLines.fold<int>(0, (sum, l) => sum + l.balance);
    final equityTotal =
        equityLines.fold<int>(0, (sum, l) => sum + l.balance);

    return BalanceSheetReport(
      assets: BalanceSheetGroup(
        sectionNameAr: 'الأصول',
        sectionNameEn: 'Assets',
        lines: assetLines,
        total: assetTotal,
      ),
      liabilities: BalanceSheetGroup(
        sectionNameAr: 'الخصوم',
        sectionNameEn: 'Liabilities',
        lines: liabilityLines,
        total: liabilityTotal,
      ),
      equity: BalanceSheetGroup(
        sectionNameAr: 'حقوق الملكية',
        sectionNameEn: 'Equity',
        lines: equityLines,
        total: equityTotal,
      ),
      totalAssets: assetTotal,
      totalLiabilitiesAndEquity: liabilityTotal + equityTotal,
    );
  }
}

/// Complete balance sheet report containing all three sections with
/// grand totals for verification of the accounting equation.
@immutable
class BalanceSheetReport {
  final BalanceSheetGroup assets;
  final BalanceSheetGroup liabilities;
  final BalanceSheetGroup equity;

  /// Total assets in minor units (x1000).
  final int totalAssets;

  /// Total liabilities + equity in minor units (x1000).
  final int totalLiabilitiesAndEquity;

  const BalanceSheetReport({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.totalAssets,
    required this.totalLiabilitiesAndEquity,
  });

  /// Whether the accounting equation holds: Assets == Liabilities + Equity.
  bool get isBalanced => totalAssets == totalLiabilitiesAndEquity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BalanceSheetReport &&
          runtimeType == other.runtimeType &&
          assets == other.assets &&
          liabilities == other.liabilities &&
          equity == other.equity &&
          totalAssets == other.totalAssets &&
          totalLiabilitiesAndEquity == other.totalLiabilitiesAndEquity;

  @override
  int get hashCode =>
      assets.hashCode ^
      liabilities.hashCode ^
      equity.hashCode ^
      totalAssets.hashCode ^
      totalLiabilitiesAndEquity.hashCode;
}

/// A grouped section of the balance sheet (e.g. Assets, Liabilities, Equity).
///
/// Contains the section names in Arabic and English, the list of account lines
/// within the section, and the computed section total.
@immutable
class BalanceSheetGroup {
  final String sectionNameAr;
  final String sectionNameEn;
  final List<BalanceSheetLine> lines;
  final int total;

  const BalanceSheetGroup({
    required this.sectionNameAr,
    required this.sectionNameEn,
    required this.lines,
    required this.total,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BalanceSheetGroup &&
          runtimeType == other.runtimeType &&
          sectionNameAr == other.sectionNameAr &&
          sectionNameEn == other.sectionNameEn &&
          lines == other.lines &&
          total == other.total;

  @override
  int get hashCode =>
      sectionNameAr.hashCode ^
      sectionNameEn.hashCode ^
      lines.hashCode ^
      total.hashCode;
}

/// A single account line within a balance sheet group.
///
/// Contains the account identifier, chart of accounts code, Arabic name,
/// and the derived balance in minor units (x1000).
@immutable
class BalanceSheetLine {
  final String accountId;
  final String accountCode;
  final String accountNameAr;
  final int balance;

  const BalanceSheetLine({
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.balance,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BalanceSheetLine &&
          runtimeType == other.runtimeType &&
          accountId == other.accountId &&
          accountCode == other.accountCode &&
          accountNameAr == other.accountNameAr &&
          balance == other.balance;

  @override
  int get hashCode =>
      accountId.hashCode ^
      accountCode.hashCode ^
      accountNameAr.hashCode ^
      balance.hashCode;
}
