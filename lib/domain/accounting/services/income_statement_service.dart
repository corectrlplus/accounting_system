import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/database/app_database.dart';

/// Income statement (قائمة الدخل) / profit & loss report service.
///
/// Produces a standard income statement following the formula:
/// Revenue - COGS = Gross Profit
/// Gross Profit - Operating Expenses = Net Income
///
/// Accounts are grouped by type (revenue, cogs, expense) and sorted by code.
/// All monetary values are in minor units (x1000).
///
/// Only active accounts with non-zero balances are included in the output.
@immutable
class IncomeStatementService {
  final AppDatabase db;

  const IncomeStatementService(this.db);

  /// Generate an income statement report for the specified company.
  ///
  /// Queries all active accounts of type revenue, cogs, or expense.
  /// For each account, derives the balance from journal entry lines using
  /// standard debit/credit normal conventions:
  /// - **Credit-normal** (revenue): balance = SUM(credit) - SUM(debit)
  /// - **Debit-normal** (cogs, expense): balance = SUM(debit) - SUM(credit)
  ///
  /// Returns an [IncomeStatementReport] with revenue, COGS, gross profit,
  /// expenses, and net income figures.
  Future<IncomeStatementReport> generate(String companyId) async {
    final accounts = await (db.select(db.accounts)
          ..where((a) =>
              a.companyId.equals(companyId) &
              a.isActive.equals(true) &
              (a.type.equals('revenue') |
                  a.type.equals('cogs') |
                  a.type.equals('expense')))
          ..orderBy([(a) => OrderingTerm.asc(a.code)]))
        .get();

    final revenueLines = <IncomeStatementLine>[];
    final cogsLines = <IncomeStatementLine>[];
    final expenseLines = <IncomeStatementLine>[];

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

      final isDebitNormal = ['cogs', 'expense']
          .contains(account.type.toLowerCase());

      final balance = isDebitNormal
          ? (totalDebit - totalCredit)
          : (totalCredit - totalDebit);

      final line = IncomeStatementLine(
        accountId: account.id,
        accountCode: account.code,
        accountNameAr: account.nameAr,
        balance: balance,
      );

      switch (account.type.toLowerCase()) {
        case 'revenue':
          revenueLines.add(line);
          break;
        case 'cogs':
          cogsLines.add(line);
          break;
        case 'expense':
          expenseLines.add(line);
          break;
      }
    }

    revenueLines.sort((a, b) => a.accountCode.compareTo(b.accountCode));
    cogsLines.sort((a, b) => a.accountCode.compareTo(b.accountCode));
    expenseLines.sort((a, b) => a.accountCode.compareTo(b.accountCode));

    final revenueTotal =
        revenueLines.fold<int>(0, (sum, l) => sum + l.balance);
    final cogsTotal =
        cogsLines.fold<int>(0, (sum, l) => sum + l.balance);
    final expenseTotal =
        expenseLines.fold<int>(0, (sum, l) => sum + l.balance);

    final grossProfit = revenueTotal - cogsTotal;
    final netIncome = grossProfit - expenseTotal;

    return IncomeStatementReport(
      revenue: IncomeStatementSection(
        sectionNameAr: 'الإيرادات',
        sectionNameEn: 'Revenue',
        lines: revenueLines,
        total: revenueTotal,
      ),
      cogs: IncomeStatementSection(
        sectionNameAr: 'تكلفة المبيعات',
        sectionNameEn: 'Cost of Goods Sold',
        lines: cogsLines,
        total: cogsTotal,
      ),
      grossProfit: grossProfit,
      expenses: IncomeStatementSection(
        sectionNameAr: 'المصروفات التشغيلية',
        sectionNameEn: 'Operating Expenses',
        lines: expenseLines,
        total: expenseTotal,
      ),
      netIncome: netIncome,
    );
  }
}

/// Complete income statement report containing revenue, COGS, expenses,
/// and the computed gross profit and net income figures.
@immutable
class IncomeStatementReport {
  final IncomeStatementSection revenue;
  final IncomeStatementSection cogs;

  /// Gross Profit = Revenue - COGS in minor units (x1000).
  final int grossProfit;

  final IncomeStatementSection expenses;

  /// Net Income = Revenue - COGS - Expenses in minor units (x1000).
  final int netIncome;

  const IncomeStatementReport({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.netIncome,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeStatementReport &&
          runtimeType == other.runtimeType &&
          revenue == other.revenue &&
          cogs == other.cogs &&
          grossProfit == other.grossProfit &&
          expenses == other.expenses &&
          netIncome == other.netIncome;

  @override
  int get hashCode =>
      revenue.hashCode ^
      cogs.hashCode ^
      grossProfit.hashCode ^
      expenses.hashCode ^
      netIncome.hashCode;
}

/// A grouped section of the income statement (e.g. Revenue, COGS, Expenses).
///
/// Contains the section names in Arabic and English, the list of account lines
/// within the section, and the computed section total.
@immutable
class IncomeStatementSection {
  final String sectionNameAr;
  final String sectionNameEn;
  final List<IncomeStatementLine> lines;
  final int total;

  const IncomeStatementSection({
    required this.sectionNameAr,
    required this.sectionNameEn,
    required this.lines,
    required this.total,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeStatementSection &&
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

/// A single account line within an income statement section.
///
/// Contains the account identifier, chart of accounts code, Arabic name,
/// and the derived balance in minor units (x1000).
@immutable
class IncomeStatementLine {
  final String accountId;
  final String accountCode;
  final String accountNameAr;
  final int balance;

  const IncomeStatementLine({
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.balance,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeStatementLine &&
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
