import 'package:test/test.dart';
import 'package:accounting_system/domain/accounting/services/export_service.dart';
import 'package:accounting_system/domain/accounting/services/trial_balance_service.dart';

void main() {
  final service = ExportService();

  // ===========================================================================
  // ExportService - toJson
  // ===========================================================================
  group('ExportService.toJson', () {
    test('toJson returns valid JSON string for simple map', () {
      final data = {'key': 'value', 'number': 42};
      final result = service.toJson(data);
      expect(result, isA<String>());
      expect(result, contains('"key":"value"'));
      expect(result, contains('"number":42'));
    });

    test('toJson returns valid JSON string for nested map', () {
      final data = {
        'outer': {'inner': 'deep'},
        'list': [1, 2, 3],
      };
      final result = service.toJson(data);
      expect(result, contains('"outer"'));
      expect(result, contains('"inner":"deep"'));
      expect(result, contains('"list":[1,2,3]'));
    });

    test('toJson handles empty map', () {
      final result = service.toJson({});
      expect(result, equals('{}'));
    });

    test('toJson handles string value', () {
      final result = service.toJson('hello');
      expect(result, equals('"hello"'));
    });

    test('toJson handles null values', () {
      final data = {'key': null};
      final result = service.toJson(data);
      expect(result, contains('null'));
    });
  });

  // ===========================================================================
  // ExportService - objectToMap
  // ===========================================================================
  group('ExportService.objectToMap', () {
    test('objectToMap returns same map for Map<String, dynamic>', () {
      final data = <String, dynamic>{'a': 1, 'b': 'two'};
      final result = service.objectToMap(data);
      expect(result, equals(data));
    });

    test('objectToMap throws for non-map type', () {
      expect(
        () => service.objectToMap('not a map'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('objectToMap throws for int type', () {
      expect(
        () => service.objectToMap(42),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ===========================================================================
  // ExportService - trialBalanceToCsv
  // ===========================================================================
  group('ExportService.trialBalanceToCsv', () {
    test('trialBalanceToCsv generates semicolon-separated CSV', () {
      final lines = [
        const _FakeTrialBalanceLine(
          accountId: 'acc_1110',
          accountCode: '1110',
          accountNameAr: 'نقد في الصندوق',
          accountType: 'asset',
          totalDebit: 500000,
          totalCredit: 0,
          balance: 500000,
        ),
        const _FakeTrialBalanceLine(
          accountId: 'acc_4100',
          accountCode: '4100',
          accountNameAr: 'إيرادات المبيعات',
          accountType: 'revenue',
          totalDebit: 0,
          totalCredit: 500000,
          balance: 500000,
        ),
      ];

      final csv = service.trialBalanceToCsv(lines);
      final csvLines = csv.trim().split('\n');

      expect(csvLines.length, equals(3));
      expect(csvLines[0], equals('Account Code;Account Name;Account Type;Debit;Credit;Balance'));
      expect(csvLines[1], contains(';'));
      expect(csvLines[1], contains('1110'));
      expect(csvLines[1], contains('500000'));
      expect(csvLines[2], contains('4100'));
    });

    test('trialBalanceToCsv with empty list returns only header', () {
      final csv = service.trialBalanceToCsv([]);
      final csvLines = csv.trim().split('\n');
      expect(csvLines.length, equals(1));
      expect(csvLines[0], equals('Account Code;Account Name;Account Type;Debit;Credit;Balance'));
    });

    test('trialBalanceToCsv uses semicolons as delimiters', () {
      final lines = [
        const _FakeTrialBalanceLine(
          accountId: 'acc_1110',
          accountCode: '1110',
          accountNameAr: 'Cash',
          accountType: 'asset',
          totalDebit: 100,
          totalCredit: 50,
          balance: 50,
        ),
      ];

      final csv = service.trialBalanceToCsv(lines);
      final dataLine = csv.trim().split('\n')[1];
      final fields = dataLine.split(';');

      expect(fields.length, equals(6));
      expect(fields[0], equals('1110'));
      expect(fields[1], equals('Cash'));
      expect(fields[2], equals('asset'));
      expect(fields[3], equals('100'));
      expect(fields[4], equals('50'));
      expect(fields[5], equals('50'));
    });
  });

  // ===========================================================================
  // ExportService - trialBalanceToMap
  // ===========================================================================
  group('ExportService.trialBalanceToMap', () {
    test('trialBalanceToMap returns correct structure', () {
      final lines = [
        const _FakeTrialBalanceLine(
          accountId: 'acc_1110',
          accountCode: '1110',
          accountNameAr: 'نقد',
          accountType: 'asset',
          totalDebit: 500000,
          totalCredit: 0,
          balance: 500000,
        ),
      ];

      final result = service.trialBalanceToMap(
        'Test Company',
        lines,
        500000,
        500000,
      );

      expect(result['reportType'], equals('trial_balance'));
      expect(result['companyName'], equals('Test Company'));
      expect(result['summary']['totalDebit'], equals(500000));
      expect(result['summary']['totalCredit'], equals(500000));
      expect(result['summary']['isBalanced'], isTrue);
      expect((result['lines'] as List).length, equals(1));
    });

    test('trialBalanceToMap isBalanced false when debits != credits', () {
      final result = service.trialBalanceToMap(
        'Test Company',
        [],
        100000,
        80000,
      );
      expect(result['summary']['isBalanced'], isFalse);
    });

    test('trialBalanceToMap includes line details', () {
      final lines = [
        const _FakeTrialBalanceLine(
          accountId: 'acc_4100',
          accountCode: '4100',
          accountNameAr: 'مبيعات',
          accountType: 'revenue',
          totalDebit: 0,
          totalCredit: 300000,
          balance: 300000,
        ),
      ];

      final result = service.trialBalanceToMap('Co', lines, 0, 300000);
      final lineData = (result['lines'] as List).first;
      expect(lineData['accountCode'], equals('4100'));
      expect(lineData['accountType'], equals('revenue'));
      expect(lineData['balance'], equals(300000));
    });
  });

  // ===========================================================================
  // ExportService - incomeStatementToMap
  // ===========================================================================
  group('ExportService.incomeStatementToMap', () {
    test('incomeStatementToMap returns correct structure', () {
      final revenueLines = [
        const _FakeAccountLine(
          accountId: 'acc_1',
          accountCode: '4100',
          accountNameAr: 'مبيعات',
          balance: 1000000,
        ),
      ];
      final cogsLines = [
        const _FakeAccountLine(
          accountId: 'acc_2',
          accountCode: '5100',
          accountNameAr: 'تكلفة المبيعات',
          balance: 400000,
        ),
      ];
      final expenseLines = [
        const _FakeAccountLine(
          accountId: 'acc_3',
          accountCode: '7100',
          accountNameAr: 'إيجار',
          balance: 100000,
        ),
      ];

      final result = service.incomeStatementToMap(
        'Test Co',
        revenueTotal: 1000000,
        cogsTotal: 400000,
        grossProfit: 600000,
        expenseTotal: 100000,
        netIncome: 500000,
        revenueLines: revenueLines,
        cogsLines: cogsLines,
        expenseLines: expenseLines,
      );

      expect(result['reportType'], equals('income_statement'));
      expect(result['companyName'], equals('Test Co'));
      expect(result['summary']['revenueTotal'], equals(1000000));
      expect(result['summary']['cogsTotal'], equals(400000));
      expect(result['summary']['grossProfit'], equals(600000));
      expect(result['summary']['expenseTotal'], equals(100000));
      expect(result['summary']['netIncome'], equals(500000));
      expect((result['revenue'] as List).length, equals(1));
      expect((result['cogs'] as List).length, equals(1));
      expect((result['expenses'] as List).length, equals(1));
    });
  });

  // ===========================================================================
  // ExportService - balanceSheetToMap
  // ===========================================================================
  group('ExportService.balanceSheetToMap', () {
    test('balanceSheetToMap returns correct structure', () {
      final assetLines = [
        const _FakeAccountLine(
          accountId: 'acc_1',
          accountCode: '1110',
          accountNameAr: 'نقد',
          balance: 500000,
        ),
      ];
      final liabilityLines = <dynamic>[];
      final equityLines = [
        const _FakeAccountLine(
          accountId: 'acc_2',
          accountCode: '3100',
          accountNameAr: 'رأس المال',
          balance: 500000,
        ),
      ];

      final result = service.balanceSheetToMap(
        'Test Co',
        totalAssets: 500000,
        totalLiabilitiesAndEquity: 500000,
        assetLines: assetLines,
        liabilityLines: liabilityLines,
        equityLines: equityLines,
      );

      expect(result['reportType'], equals('balance_sheet'));
      expect(result['companyName'], equals('Test Co'));
      expect(result['summary']['totalAssets'], equals(500000));
      expect(result['summary']['totalLiabilitiesAndEquity'], equals(500000));
      expect(result['summary']['isBalanced'], isTrue);
      expect((result['assets'] as List).length, equals(1));
      expect((result['liabilities'] as List).length, equals(0));
      expect((result['equity'] as List).length, equals(1));
    });

    test('balanceSheetToMap reports unbalanced', () {
      final result = service.balanceSheetToMap(
        'Test Co',
        totalAssets: 500000,
        totalLiabilitiesAndEquity: 400000,
        assetLines: [],
        liabilityLines: [],
        equityLines: [],
      );
      expect(result['summary']['isBalanced'], isFalse);
    });
  });

  // ===========================================================================
  // ExportService - accountStatementToMap
  // ===========================================================================
  group('ExportService.accountStatementToMap', () {
    test('accountStatementToMap returns correct structure', () {
      final lines = [
        const _FakeAccountStatementLine(
          entryId: 'je_1',
          entryNumber: 1,
          dateMs: 1000,
          description: 'Test entry',
          sourceType: 'sale',
          isReversal: false,
          debitAmount: 100000,
          creditAmount: 0,
          runningBalance: 100000,
        ),
      ];

      final result = service.accountStatementToMap(
        'Test Co',
        'acc_1',
        '1110',
        'Cash',
        lines,
      );

      expect(result['reportType'], equals('account_statement'));
      expect(result['companyName'], equals('Test Co'));
      expect(result['account']['accountId'], equals('acc_1'));
      expect(result['account']['accountCode'], equals('1110'));
      expect(result['account']['totalDebit'], equals(100000));
      expect(result['account']['totalCredit'], equals(0));
      expect((result['lines'] as List).length, equals(1));
    });
  });

  // ===========================================================================
  // ExportService - agingReportToCsv
  // ===========================================================================
  group('ExportService.agingReportToCsv', () {
    test('agingReportToCsv generates semicolon-separated CSV', () {
      final lines = [
        {
          'accountCode': '1130',
          'accountName': 'Ahmed',
          'current': 100000,
          '1_30': 50000,
          '31_60': 30000,
          '61_90': 0,
          'over_90': 0,
          'total': 180000,
        },
      ];

      final csv = service.agingReportToCsv(lines);
      final csvLines = csv.trim().split('\n');

      expect(csvLines.length, equals(2));
      expect(csvLines[0], contains('Account Code'));
      expect(csvLines[1], contains('1130'));
      expect(csvLines[1], contains('Ahmed'));
      expect(csvLines[1], contains('100000'));
    });

    test('agingReportToCsv with empty list returns only header', () {
      final csv = service.agingReportToCsv([]);
      final csvLines = csv.trim().split('\n');
      expect(csvLines.length, equals(1));
    });
  });

  // ===========================================================================
  // ExportService - agingReportToMap
  // ===========================================================================
  group('ExportService.agingReportToMap', () {
    test('agingReportToMap returns correct structure', () {
      final lines = [
        {
          'accountCode': '1130',
          'accountName': 'Ahmed',
          'total': 180000,
        },
      ];

      final result = service.agingReportToMap(
        'Test Co',
        'receivable_aging',
        lines,
      );

      expect(result['reportType'], equals('receivable_aging'));
      expect(result['companyName'], equals('Test Co'));
      expect(result['summary']['grandTotal'], equals(180000));
      expect(result['summary']['accountCount'], equals(1));
    });

    test('agingReportToMap sums grand total across lines', () {
      final lines = [
        {'accountCode': '1130', 'accountName': 'A', 'total': 100000},
        {'accountCode': '1130', 'accountName': 'B', 'total': 200000},
      ];

      final result = service.agingReportToMap('Co', 'ar_aging', lines);
      expect(result['summary']['grandTotal'], equals(300000));
      expect(result['summary']['accountCount'], equals(2));
    });
  });
}

/// Minimal fake class matching the shape ExportService.trialBalanceToCsv expects via dynamic dispatch.
class _FakeTrialBalanceLine {
  final String accountId;
  final String accountCode;
  final String accountNameAr;
  final String accountType;
  final int totalDebit;
  final int totalCredit;
  final int balance;

  const _FakeTrialBalanceLine({
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.accountType,
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
  });
}

class _FakeAccountLine {
  final String accountId;
  final String accountCode;
  final String accountNameAr;
  final int balance;

  const _FakeAccountLine({
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.balance,
  });
}

class _FakeAccountStatementLine {
  final String entryId;
  final int entryNumber;
  final int dateMs;
  final String description;
  final String sourceType;
  final bool isReversal;
  final int debitAmount;
  final int creditAmount;
  final int runningBalance;

  const _FakeAccountStatementLine({
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
}
