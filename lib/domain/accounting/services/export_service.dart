import 'dart:convert';
import 'package:meta/meta.dart';

@immutable
class ExportService {
  const ExportService();

  String toJson(Object data) => jsonEncode(data);

  Map<String, dynamic> objectToMap(Object data) {
    if (data is Map<String, dynamic>) return data;
    throw ArgumentError('Cannot convert ${data.runtimeType} to Map<String, dynamic>');
  }

  String trialBalanceToCsv(List<dynamic> lines) {
    final buffer = StringBuffer();
    buffer.writeln('Account Code;Account Name;Account Type;Debit;Credit;Balance');
    for (final line in lines) {
      buffer.writeln(
        '${line.accountCode};${line.accountNameAr};${line.accountType};${line.totalDebit};${line.totalCredit};${line.balance}',
      );
    }
    return buffer.toString();
  }

  String generalLedgerToCsv(List<dynamic> entries) {
    final buffer = StringBuffer();
    buffer.writeln('Entry Number;Date;Description;Source Type;Debit;Credit;Balance');
    for (final entry in entries) {
      buffer.writeln(
        '${entry.entryNumber};${entry.dateMs};${entry.description};${entry.sourceType};${entry.debitAmount};${entry.creditAmount};${entry.runningBalance}',
      );
    }
    return buffer.toString();
  }

  String accountStatementToCsv(List<dynamic> lines) {
    final buffer = StringBuffer();
    buffer.writeln('Entry Number;Date;Description;Source Type;Reversal;Debit;Credit;Running Balance');
    for (final line in lines) {
      buffer.writeln(
        '${line.entryNumber};${line.dateMs};${line.description};${line.sourceType};${line.isReversal};${line.debitAmount};${line.creditAmount};${line.runningBalance}',
      );
    }
    return buffer.toString();
  }

  String agingReportToCsv(List<dynamic> lines) {
    final buffer = StringBuffer();
    buffer.writeln('Account Code;Account Name;Current;1-30 Days;31-60 Days;61-90 Days;Over 90 Days;Total');
    for (final line in lines) {
      buffer.writeln(
        '${line['accountCode']};${line['accountName']};${line['current']};${line['1_30']};${line['31_60']};${line['61_90']};${line['over_90']};${line['total']}',
      );
    }
    return buffer.toString();
  }

  Map<String, dynamic> trialBalanceToMap(
    String companyName,
    List<dynamic> lines,
    int totalDebit,
    int totalCredit,
  ) {
    return {
      'reportType': 'trial_balance',
      'companyName': companyName,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'summary': {
        'totalDebit': totalDebit,
        'totalCredit': totalCredit,
        'isBalanced': totalDebit == totalCredit,
      },
      'lines': lines
          .map((line) => {
                'accountId': line.accountId,
                'accountCode': line.accountCode,
                'accountNameAr': line.accountNameAr,
                'accountType': line.accountType,
                'totalDebit': line.totalDebit,
                'totalCredit': line.totalCredit,
                'balance': line.balance,
              })
          .toList(),
    };
  }

  Map<String, dynamic> incomeStatementToMap(
    String companyName, {
    required int revenueTotal,
    required int cogsTotal,
    required int grossProfit,
    required int expenseTotal,
    required int netIncome,
    required List<dynamic> revenueLines,
    required List<dynamic> cogsLines,
    required List<dynamic> expenseLines,
  }) {
    return {
      'reportType': 'income_statement',
      'companyName': companyName,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'summary': {
        'revenueTotal': revenueTotal,
        'cogsTotal': cogsTotal,
        'grossProfit': grossProfit,
        'expenseTotal': expenseTotal,
        'netIncome': netIncome,
      },
      'revenue': revenueLines
          .map((l) => {
                'accountId': l.accountId,
                'accountCode': l.accountCode,
                'accountNameAr': l.accountNameAr,
                'balance': l.balance,
              })
          .toList(),
      'cogs': cogsLines
          .map((l) => {
                'accountId': l.accountId,
                'accountCode': l.accountCode,
                'accountNameAr': l.accountNameAr,
                'balance': l.balance,
              })
          .toList(),
      'expenses': expenseLines
          .map((l) => {
                'accountId': l.accountId,
                'accountCode': l.accountCode,
                'accountNameAr': l.accountNameAr,
                'balance': l.balance,
              })
          .toList(),
    };
  }

  Map<String, dynamic> balanceSheetToMap(
    String companyName, {
    required int totalAssets,
    required int totalLiabilitiesAndEquity,
    required List<dynamic> assetLines,
    required List<dynamic> liabilityLines,
    required List<dynamic> equityLines,
  }) {
    return {
      'reportType': 'balance_sheet',
      'companyName': companyName,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'summary': {
        'totalAssets': totalAssets,
        'totalLiabilitiesAndEquity': totalLiabilitiesAndEquity,
        'isBalanced': totalAssets == totalLiabilitiesAndEquity,
      },
      'assets': assetLines
          .map((l) => {
                'accountId': l.accountId,
                'accountCode': l.accountCode,
                'accountNameAr': l.accountNameAr,
                'balance': l.balance,
              })
          .toList(),
      'liabilities': liabilityLines
          .map((l) => {
                'accountId': l.accountId,
                'accountCode': l.accountCode,
                'accountNameAr': l.accountNameAr,
                'balance': l.balance,
              })
          .toList(),
      'equity': equityLines
          .map((l) => {
                'accountId': l.accountId,
                'accountCode': l.accountCode,
                'accountNameAr': l.accountNameAr,
                'balance': l.balance,
              })
          .toList(),
    };
  }

  Map<String, dynamic> accountStatementToMap(
    String companyName,
    String accountId,
    String accountCode,
    String accountName,
    List<dynamic> lines,
  ) {
    int totalDebit = 0;
    int totalCredit = 0;
    for (final line in lines) {
      totalDebit += (line.debitAmount as num).toInt();
      totalCredit += (line.creditAmount as num).toInt();
    }

    return {
      'reportType': 'account_statement',
      'companyName': companyName,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'account': {
        'accountId': accountId,
        'accountCode': accountCode,
        'accountName': accountName,
        'totalDebit': totalDebit,
        'totalCredit': totalCredit,
      },
      'lines': lines
          .map((l) => {
                'entryId': l.entryId,
                'entryNumber': l.entryNumber,
                'dateMs': l.dateMs,
                'description': l.description,
                'sourceType': l.sourceType,
                'isReversal': l.isReversal,
                'debitAmount': l.debitAmount,
                'creditAmount': l.creditAmount,
                'runningBalance': l.runningBalance,
              })
          .toList(),
    };
  }

  Map<String, dynamic> agingReportToMap(
    String companyName,
    String reportType,
    List<dynamic> lines,
  ) {
    int grandTotal = 0;
    for (final line in lines) {
      grandTotal += line['total'] as int;
    }

    return {
      'reportType': reportType,
      'companyName': companyName,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'summary': {
        'grandTotal': grandTotal,
        'accountCount': lines.length,
      },
      'lines': lines,
    };
  }
}
