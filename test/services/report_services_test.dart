import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';
import 'package:accounting_system/data/database/app_database.dart';
import '../test_database_helper.dart';
import 'package:accounting_system/domain/accounting/services/balance_sheet_service.dart';
import 'package:accounting_system/domain/accounting/services/income_statement_service.dart';
import 'package:accounting_system/domain/accounting/services/trial_balance_service.dart';
import 'package:accounting_system/domain/accounting/services/balance_service.dart';
import 'package:accounting_system/domain/accounting/services/cash_flow_report_service.dart';
import 'package:accounting_system/domain/accounting/services/aging_report_service.dart';

void main() {
  late AppDatabase db;
  const testCompanyId = 'test_company';
  const testDeviceId = 'device_1';

  setUp(() async {
    db = createTestDatabase();
    await db.seedCompanyDefaults(testCompanyId, testDeviceId);
  });

  tearDown(() async {
    await db.close();
  });

  String accountId(String code) => 'acc_${code}_$testCompanyId';

  Future<void> insertJournalEntry({
    required String jeId,
    required int entryNumber,
    required String description,
    required String sourceType,
    required String sourceId,
    required List<({String accountId, int debit, int credit})> lines,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertJournalEntryAtomic(
      header: JournalEntriesCompanion.insert(
        id: jeId,
        companyId: testCompanyId,
        entryNumber: entryNumber,
        date: now,
        description: description,
        sourceType: sourceType,
        sourceId: sourceId,
        idempotencyKey: 'idem_$jeId',
        createdBy: 'test_user',
        createdAt: now,
        deviceId: testDeviceId,
      ),
      lines: lines
          .asMap()
          .entries
          .map(
            (e) => JournalEntryLinesCompanion.insert(
              id: 'jel_${jeId}_${e.key}',
              companyId: testCompanyId,
              journalEntryId: jeId,
              accountId: e.value.accountId,
              debitAmount: Value(e.value.debit),
              creditAmount: Value(e.value.credit),
              createdAt: now,
            ),
          )
          .toList(),
    );
  }

  // ===========================================================================
  // TrialBalanceService
  // ===========================================================================
  group('TrialBalanceService', () {
    test('Empty database returns empty trial balance', () async {
      final service = TrialBalanceService(db);
      final report = await service.generate(testCompanyId);
      expect(report, isEmpty);
    });

    test('Single balanced entry shows both accounts', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Cash sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 500000),
        ],
      );

      final service = TrialBalanceService(db);
      final lines = await service.generate(testCompanyId);
      expect(lines.length, equals(2));

      final cashLine = lines.firstWhere((l) => l.accountCode == '1110');
      expect(cashLine.totalDebit, equals(500000));
      expect(cashLine.totalCredit, equals(0));
      expect(cashLine.balance, equals(500000));
      expect(cashLine.accountType, equals('asset'));

      final revenueLine = lines.firstWhere((l) => l.accountCode == '4100');
      expect(revenueLine.totalDebit, equals(0));
      expect(revenueLine.totalCredit, equals(500000));
      expect(revenueLine.balance, equals(500000));
      expect(revenueLine.accountType, equals('revenue'));
    });

    test('Multiple entries aggregate correctly per account', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Sale 1',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 200000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 200000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'Sale 2',
        sourceType: 'sale',
        sourceId: 'sale_2',
        lines: [
          (accountId: accountId('1110'), debit: 300000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 300000),
        ],
      );

      final service = TrialBalanceService(db);
      final lines = await service.generate(testCompanyId);

      final cashLine = lines.firstWhere((l) => l.accountCode == '1110');
      expect(cashLine.totalDebit, equals(500000));
      expect(cashLine.balance, equals(500000));

      final revenueLine = lines.firstWhere((l) => l.accountCode == '4100');
      expect(revenueLine.totalCredit, equals(500000));
      expect(revenueLine.balance, equals(500000));
    });

    test('Debit-normal account with mixed entries computes correct balance', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Purchase inventory',
        sourceType: 'purchase',
        sourceId: 'pur_1',
        lines: [
          (accountId: accountId('1150'), debit: 400000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 400000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'Sale reduces inventory',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1150'), debit: 0, credit: 150000),
          (accountId: accountId('5100'), debit: 150000, credit: 0),
        ],
      );

      final service = TrialBalanceService(db);
      final lines = await service.generate(testCompanyId);

      final inventoryLine = lines.firstWhere((l) => l.accountCode == '1150');
      expect(inventoryLine.totalDebit, equals(400000));
      expect(inventoryLine.totalCredit, equals(150000));
      expect(inventoryLine.balance, equals(250000));
    });

    test('Entries only in own company are returned', () async {
      const otherCompanyId = 'other_company';
      await db.seedCompanyDefaults(otherCompanyId, testDeviceId);

      await insertJournalEntry(
        jeId: 'je_own',
        entryNumber: 1,
        description: 'Own sale',
        sourceType: 'sale',
        sourceId: 'sale_own',
        lines: [
          (accountId: accountId('1110'), debit: 100000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 100000),
        ],
      );

      final service = TrialBalanceService(db);
      final ownLines = await service.generate(testCompanyId);
      final otherLines = await service.generate(otherCompanyId);

      expect(ownLines.length, equals(2));
      expect(otherLines, isEmpty);
    });

    test('Inactive accounts are excluded', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Test',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 100000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 100000),
        ],
      );

      final cashAccountId = accountId('1110');
      await (db.update(db.accounts)
            ..where((a) => a.id.equals(cashAccountId)))
          .write(const AccountsCompanion(isActive: Value(false)));

      final service = TrialBalanceService(db);
      final lines = await service.generate(testCompanyId);
      expect(lines.length, equals(1));
      expect(lines.first.accountCode, equals('4100'));
    });

    test('Lines are sorted by account code ascending', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Mixed transaction',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('4100'), debit: 0, credit: 100000),
          (accountId: accountId('1110'), debit: 100000, credit: 0),
          (accountId: accountId('7100'), debit: 0, credit: 0),
        ],
      );

      final service = TrialBalanceService(db);
      final lines = await service.generate(testCompanyId);
      for (var i = 1; i < lines.length; i++) {
        expect(
          lines[i - 1].accountCode.compareTo(lines[i].accountCode),
          lessThan(0),
        );
      }
    });
  });

  // ===========================================================================
  // BalanceService
  // ===========================================================================
  group('BalanceService', () {
    test('getAccountBalance returns 0 for nonexistent account', () async {
      final service = BalanceService(db);
      final balance = await service.getAccountBalance('nonexistent');
      expect(balance, 0);
    });

    test('getAccountBalance returns correct debit-normal balance', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Cash sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 500000),
        ],
      );

      final service = BalanceService(db);
      final balance = await service.getAccountBalance(accountId('1110'));
      expect(balance, equals(500000));
    });

    test('getAccountBalance returns correct credit-normal balance', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Cash sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 500000),
        ],
      );

      final service = BalanceService(db);
      final balance = await service.getAccountBalance(accountId('4100'));
      expect(balance, equals(500000));
    });

    test('getCustomerBalance returns 0 for nonexistent customer', () async {
      final service = BalanceService(db);
      final balance =
          await service.getCustomerBalance('nonexistent', testCompanyId);
      expect(balance, 0);
    });

    test('getSupplierBalance returns 0 for nonexistent supplier', () async {
      final service = BalanceService(db);
      final balance =
          await service.getSupplierBalance('nonexistent', testCompanyId);
      expect(balance, 0);
    });

    test('getWorkerAdvanceBalance returns 0 for nonexistent worker', () async {
      final service = BalanceService(db);
      final balance =
          await service.getWorkerAdvanceBalance('nonexistent', testCompanyId);
      expect(balance, 0);
    });

    test('getCashBalance sums cash and bank accounts', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Cash received',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 300000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 300000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'Bank deposit',
        sourceType: 'sale',
        sourceId: 'sale_2',
        lines: [
          (accountId: accountId('1120'), debit: 200000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 200000),
        ],
      );

      final service = BalanceService(db);
      final cashBalance = await service.getCashBalance(testCompanyId);
      expect(cashBalance, equals(500000));
    });

    test('getCashBalance returns 0 when no cash/bank transactions', () async {
      final service = BalanceService(db);
      final cashBalance = await service.getCashBalance(testCompanyId);
      expect(cashBalance, equals(0));
    });
  });

  // ===========================================================================
  // BalanceSheetService
  // ===========================================================================
  group('BalanceSheetService', () {
    test('Empty database returns balanced zero balance sheet', () async {
      final service = BalanceSheetService(db);
      final report = await service.generate(testCompanyId);
      expect(report.totalAssets, equals(0));
      expect(report.totalLiabilitiesAndEquity, equals(0));
      expect(report.isBalanced, isTrue);
      expect(report.assets.lines, isEmpty);
      expect(report.liabilities.lines, isEmpty);
      expect(report.equity.lines, isEmpty);
    });

    test('Capital injection produces balanced balance sheet', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Owner capital injection',
        sourceType: 'owner_capital',
        sourceId: 'oc_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('3100'), debit: 0, credit: 500000),
        ],
      );

      final service = BalanceSheetService(db);
      final report = await service.generate(testCompanyId);

      expect(report.totalAssets, equals(500000));
      expect(report.isBalanced, isTrue);
      expect(report.assets.lines.length, equals(1));
      expect(report.assets.lines.first.accountCode, equals('1110'));
      expect(report.assets.lines.first.balance, equals(500000));
    });

    test('Purchase on credit shows asset and liability', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Credit purchase',
        sourceType: 'purchase',
        sourceId: 'pur_1',
        lines: [
          (accountId: accountId('1150'), debit: 300000, credit: 0),
          (accountId: accountId('2110'), debit: 0, credit: 300000),
        ],
      );

      final service = BalanceSheetService(db);
      final report = await service.generate(testCompanyId);

      expect(report.totalAssets, equals(300000));
      expect(report.totalLiabilitiesAndEquity, equals(300000));
      expect(report.isBalanced, isTrue);
      expect(report.liabilities.lines.length, equals(1));
      expect(report.liabilities.lines.first.accountCode, equals('2110'));
    });

    test('Capital injection shows asset and equity', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Owner capital',
        sourceType: 'owner_capital',
        sourceId: 'oc_1',
        lines: [
          (accountId: accountId('1110'), debit: 1000000, credit: 0),
          (accountId: accountId('3100'), debit: 0, credit: 1000000),
        ],
      );

      final service = BalanceSheetService(db);
      final report = await service.generate(testCompanyId);

      expect(report.totalAssets, equals(1000000));
      expect(report.isBalanced, isTrue);
      expect(report.equity.lines.length, equals(1));
      expect(report.equity.lines.first.accountCode, equals('3100'));
    });

    test('Complex transaction stays balanced', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Capital',
        sourceType: 'owner_capital',
        sourceId: 'oc_1',
        lines: [
          (accountId: accountId('1110'), debit: 1000000, credit: 0),
          (accountId: accountId('3100'), debit: 0, credit: 1000000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'Purchase inventory',
        sourceType: 'purchase',
        sourceId: 'pur_1',
        lines: [
          (accountId: accountId('1150'), debit: 400000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 400000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_3',
        entryNumber: 3,
        description: 'Credit purchase',
        sourceType: 'purchase',
        sourceId: 'pur_2',
        lines: [
          (accountId: accountId('1150'), debit: 200000, credit: 0),
          (accountId: accountId('2110'), debit: 0, credit: 200000),
        ],
      );

      final service = BalanceSheetService(db);
      final report = await service.generate(testCompanyId);

      expect(report.isBalanced, isTrue);
      // Cash: 1M - 400K = 600K, Inventory: 400K + 200K = 600K => Total Assets = 1.2M
      expect(report.totalAssets, equals(1200000));
      expect(report.totalLiabilitiesAndEquity, equals(1200000));
    });

    test('Revenue and expense accounts excluded from balance sheet', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 500000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'Expense',
        sourceType: 'expense',
        sourceId: 'exp_1',
        lines: [
          (accountId: accountId('7100'), debit: 50000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 50000),
        ],
      );

      final service = BalanceSheetService(db);
      final report = await service.generate(testCompanyId);

      final allAccountCodes = [
        ...report.assets.lines.map((l) => l.accountCode),
        ...report.liabilities.lines.map((l) => l.accountCode),
        ...report.equity.lines.map((l) => l.accountCode),
      ];
      expect(allAccountCodes, isNot(contains('4100')));
      expect(allAccountCodes, isNot(contains('7100')));
    });

    test('Section totals match sum of individual lines', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Capital',
        sourceType: 'owner_capital',
        sourceId: 'oc_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('3100'), debit: 0, credit: 500000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'Bank deposit',
        sourceType: 'deposit',
        sourceId: 'dep_1',
        lines: [
          (accountId: accountId('1120'), debit: 300000, credit: 0),
          (accountId: accountId('3100'), debit: 0, credit: 300000),
        ],
      );

      final service = BalanceSheetService(db);
      final report = await service.generate(testCompanyId);

      final assetSum =
          report.assets.lines.fold<int>(0, (s, l) => s + l.balance);
      expect(report.assets.total, equals(assetSum));

      final equitySum =
          report.equity.lines.fold<int>(0, (s, l) => s + l.balance);
      expect(report.equity.total, equals(equitySum));
    });
  });

  // ===========================================================================
  // IncomeStatementService
  // ===========================================================================
  group('IncomeStatementService', () {
    test('Empty database returns zero income statement', () async {
      final service = IncomeStatementService(db);
      final report = await service.generate(testCompanyId);
      expect(report.netIncome, equals(0));
      expect(report.grossProfit, equals(0));
      expect(report.revenue.total, equals(0));
      expect(report.cogs.total, equals(0));
      expect(report.expenses.total, equals(0));
      expect(report.revenue.lines, isEmpty);
      expect(report.cogs.lines, isEmpty);
      expect(report.expenses.lines, isEmpty);
    });

    test('Revenue only produces positive net income', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Cash sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 500000),
        ],
      );

      final service = IncomeStatementService(db);
      final report = await service.generate(testCompanyId);
      expect(report.revenue.total, equals(500000));
      expect(report.netIncome, equals(500000));
    });

    test('Revenue minus COGS equals gross profit', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 500000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'COGS',
        sourceType: 'sale_cogs',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('5100'), debit: 200000, credit: 0),
          (accountId: accountId('1150'), debit: 0, credit: 200000),
        ],
      );

      final service = IncomeStatementService(db);
      final report = await service.generate(testCompanyId);
      expect(report.revenue.total, equals(500000));
      expect(report.cogs.total, equals(200000));
      expect(report.grossProfit, equals(300000));
      expect(report.netIncome, equals(300000));
    });

    test('Full P&L: revenue - COGS - expenses = net income', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 1000000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 1000000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'COGS',
        sourceType: 'sale_cogs',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('5100'), debit: 400000, credit: 0),
          (accountId: accountId('1150'), debit: 0, credit: 400000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_3',
        entryNumber: 3,
        description: 'Rent expense',
        sourceType: 'expense',
        sourceId: 'exp_1',
        lines: [
          (accountId: accountId('7100'), debit: 100000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 100000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_4',
        entryNumber: 4,
        description: 'Wages',
        sourceType: 'expense',
        sourceId: 'exp_2',
        lines: [
          (accountId: accountId('6100'), debit: 150000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 150000),
        ],
      );

      final service = IncomeStatementService(db);
      final report = await service.generate(testCompanyId);
      expect(report.revenue.total, equals(1000000));
      expect(report.cogs.total, equals(400000));
      expect(report.grossProfit, equals(600000));
      expect(report.expenses.total, equals(250000));
      expect(report.netIncome, equals(350000));
    });

    test('Multiple revenue accounts are aggregated', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Product sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 500000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'Other income',
        sourceType: 'other_income',
        sourceId: 'oi_1',
        lines: [
          (accountId: accountId('1110'), debit: 100000, credit: 0),
          (accountId: accountId('4300'), debit: 0, credit: 100000),
        ],
      );

      final service = IncomeStatementService(db);
      final report = await service.generate(testCompanyId);
      expect(report.revenue.lines.length, equals(2));
      expect(report.revenue.total, equals(600000));
    });

    test('Asset and liability accounts excluded from income statement', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 500000),
        ],
      );

      final service = IncomeStatementService(db);
      final report = await service.generate(testCompanyId);

      final allCodes = [
        ...report.revenue.lines.map((l) => l.accountCode),
        ...report.cogs.lines.map((l) => l.accountCode),
        ...report.expenses.lines.map((l) => l.accountCode),
      ];
      expect(allCodes, isNot(contains('1110')));
      expect(allCodes, isNot(contains('2110')));
    });

    test('Zero-balance accounts excluded from report', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Capital injection',
        sourceType: 'owner_capital',
        sourceId: 'oc_1',
        lines: [
          (accountId: accountId('1110'), debit: 1000000, credit: 0),
          (accountId: accountId('3100'), debit: 0, credit: 1000000),
        ],
      );

      final service = IncomeStatementService(db);
      final report = await service.generate(testCompanyId);
      expect(report.revenue.lines, isEmpty);
      expect(report.cogs.lines, isEmpty);
      expect(report.expenses.lines, isEmpty);
    });

    test('Negative net income when expenses exceed revenue', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Small sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 100000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 100000),
        ],
      );
      await insertJournalEntry(
        jeId: 'je_2',
        entryNumber: 2,
        description: 'Big expense',
        sourceType: 'expense',
        sourceId: 'exp_1',
        lines: [
          (accountId: accountId('7100'), debit: 200000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 200000),
        ],
      );

      final service = IncomeStatementService(db);
      final report = await service.generate(testCompanyId);
      expect(report.netIncome, equals(-100000));
    });
  });

  // ===========================================================================
  // CashFlowReportService
  // ===========================================================================
  group('CashFlowReportService', () {
    late int nowMs;

    setUp(() async {
      nowMs = DateTime.now().millisecondsSinceEpoch;
    });

    test('Empty database returns zero cash flow', () async {
      final service = CashFlowReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );
      expect(report.netCashFlow, equals(0));
      expect(report.operating.lines, isEmpty);
      expect(report.investing.lines, isEmpty);
      expect(report.financing.lines, isEmpty);
    });

    test('Incoming customer payment is positive in operating section', () async {
      final jeId = 'je_pay_1';
      await insertJournalEntry(
        jeId: jeId,
        entryNumber: 1,
        description: 'Customer payment JE',
        sourceType: 'customer_payment',
        sourceId: 'pay_1',
        lines: [
          (accountId: accountId('1110'), debit: 200000, credit: 0),
          (accountId: accountId('1130'), debit: 0, credit: 200000),
        ],
      );

      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: 'pay_1',
          companyId: testCompanyId,
          paymentNumber: 1,
          date: nowMs,
          amount: 200000,
          paymentMethod: 'cash',
          direction: 'incoming',
          journalEntryId: jeId,
          createdBy: 'test_user',
          idempotencyKey: 'idem_pay_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = CashFlowReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.operating.lines.length, equals(1));
      expect(report.operating.lines.first.amount, equals(200000));
      expect(report.operating.total, equals(200000));
    });

    test('Outgoing supplier payment is negative in operating section', () async {
      final jeId = 'je_pay_out';
      await insertJournalEntry(
        jeId: jeId,
        entryNumber: 1,
        description: 'Supplier payment JE',
        sourceType: 'supplier_payment',
        sourceId: 'pay_out_1',
        lines: [
          (accountId: accountId('2110'), debit: 150000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 150000),
        ],
      );

      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: 'pay_out_1',
          companyId: testCompanyId,
          paymentNumber: 1,
          date: nowMs,
          amount: 150000,
          paymentMethod: 'cash',
          direction: 'outgoing',
          supplierId: const Value<String?>('supp_1'),
          journalEntryId: jeId,
          createdBy: 'test_user',
          idempotencyKey: 'idem_pay_out',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = CashFlowReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.operating.lines.length, equals(1));
      expect(report.operating.lines.first.amount, equals(-150000));
    });

    test('Expense is negative in operating section', () async {
      final jeId = 'je_exp';
      await insertJournalEntry(
        jeId: jeId,
        entryNumber: 1,
        description: 'Expense JE',
        sourceType: 'expense',
        sourceId: 'exp_1',
        lines: [
          (accountId: accountId('7100'), debit: 50000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 50000),
        ],
      );

      await db.into(db.expenses).insert(
        ExpensesCompanion.insert(
          id: 'exp_1',
          companyId: testCompanyId,
          expenseNumber: 1,
          date: nowMs,
          amount: 50000,
          expenseCategoryId: 'cat_7100_$testCompanyId',
          paymentMethod: 'cash',
          journalEntryId: jeId,
          createdBy: 'test_user',
          idempotencyKey: 'idem_exp_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = CashFlowReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.operating.lines.length, equals(1));
      expect(report.operating.lines.first.amount, equals(-50000));
    });

    test('Only posted payments are included', () async {
      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: 'pay_draft',
          companyId: testCompanyId,
          paymentNumber: 1,
          date: nowMs,
          amount: 100000,
          paymentMethod: 'cash',
          direction: 'incoming',
          journalEntryId: 'je_dummy',
          createdBy: 'test_user',
          idempotencyKey: 'idem_pay_draft',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
          status: const Value('draft'),
        ),
      );

      final service = CashFlowReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.operating.lines, isEmpty);
    });

    test('Out of range transactions are excluded', () async {
      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: 'pay_old',
          companyId: testCompanyId,
          paymentNumber: 1,
          date: nowMs - 200 * 86400000,
          amount: 100000,
          paymentMethod: 'cash',
          direction: 'incoming',
          journalEntryId: 'je_dummy',
          createdBy: 'test_user',
          idempotencyKey: 'idem_pay_old',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = CashFlowReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.operating.lines, isEmpty);
    });

    test('Owner withdrawal is negative in financing section', () async {
      final jeId = 'je_wd';
      await insertJournalEntry(
        jeId: jeId,
        entryNumber: 1,
        description: 'Owner withdrawal JE',
        sourceType: 'owner_withdrawal',
        sourceId: 'wd_1',
        lines: [
          (accountId: accountId('3200'), debit: 200000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 200000),
        ],
      );

      await db.into(db.ownerWithdrawals).insert(
        OwnerWithdrawalsCompanion.insert(
          id: 'wd_1',
          companyId: testCompanyId,
          date: nowMs,
          amount: 200000,
          journalEntryId: jeId,
          createdBy: 'test_user',
          idempotencyKey: 'idem_wd_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = CashFlowReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.financing.lines.length, equals(1));
      expect(report.financing.lines.first.amount, equals(-200000));
      expect(report.financing.total, equals(-200000));
    });

    test('Net cash flow is sum of all sections', () async {
      final jeId1 = 'je_cf_1';
      final jeId2 = 'je_cf_2';
      await insertJournalEntry(
        jeId: jeId1,
        entryNumber: 1,
        description: 'Customer payment',
        sourceType: 'customer_payment',
        sourceId: 'pay_cf_1',
        lines: [
          (accountId: accountId('1110'), debit: 500000, credit: 0),
          (accountId: accountId('1130'), debit: 0, credit: 500000),
        ],
      );
      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: 'pay_cf_1',
          companyId: testCompanyId,
          paymentNumber: 1,
          date: nowMs,
          amount: 500000,
          paymentMethod: 'cash',
          direction: 'incoming',
          journalEntryId: jeId1,
          createdBy: 'test_user',
          idempotencyKey: 'idem_cf_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      await insertJournalEntry(
        jeId: jeId2,
        entryNumber: 2,
        description: 'Supplier payment',
        sourceType: 'supplier_payment',
        sourceId: 'pay_cf_2',
        lines: [
          (accountId: accountId('2110'), debit: 200000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 200000),
        ],
      );
      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: 'pay_cf_2',
          companyId: testCompanyId,
          paymentNumber: 2,
          date: nowMs,
          amount: 200000,
          paymentMethod: 'cash',
          direction: 'outgoing',
          journalEntryId: jeId2,
          createdBy: 'test_user',
          idempotencyKey: 'idem_cf_2',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = CashFlowReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.operating.total, equals(300000));
      expect(report.netCashFlow, equals(report.operating.total + report.investing.total + report.financing.total));
    });
  });

  // ===========================================================================
  // AgingReportService
  // ===========================================================================
  group('AgingReportService', () {
    late int nowMs;
    late int oneDayMs;
    late String customerAccountId;

    setUp(() async {
      nowMs = DateTime.now().millisecondsSinceEpoch;
      oneDayMs = 24 * 60 * 60 * 1000;
      customerAccountId = 'acc_ar_customer_$testCompanyId';

      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: customerAccountId,
          companyId: testCompanyId,
          code: '1130',
          nameAr: 'ذمم مدينة',
          type: 'asset',
          normalBalance: 'debit',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: 'cust_1',
          companyId: testCompanyId,
          name: 'Ahmed',
          accountId: customerAccountId,
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );
    });

    test('Empty database returns empty aging report', () async {
      final service = AgingReportService(db);
      final report = await service.generate(
        testCompanyId,
        reportDateMs: nowMs,
      );
      expect(report.lines, isEmpty);
      expect(report.totalOutstanding, equals(0));
    });

    test('Recent credit sale appears in current bucket (0-30 days)', () async {
      final saleDateMs = nowMs - 5 * oneDayMs;

      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: 'sale_1',
          companyId: testCompanyId,
          customerId: const Value<String?>('cust_1'),
          saleNumber: 1,
          date: saleDateMs,
          totalAmount: 500000,
          cashReceived: const Value(0),
          creditAmount: const Value(500000),
          paymentType: 'credit',
          journalEntryId: 'je_dummy',
          createdBy: 'test_user',
          idempotencyKey: 'idem_sale_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = AgingReportService(db);
      final report = await service.generate(
        testCompanyId,
        reportDateMs: nowMs,
      );

      expect(report.lines.length, equals(1));
      expect(report.lines.first.current0to30, equals(500000));
      expect(report.lines.first.totalOutstanding, equals(500000));
      expect(report.totalCurrent0to30, equals(500000));
    });

    test('Sale 45 days old falls in 31-60 day bucket', () async {
      final saleDateMs = nowMs - 45 * oneDayMs;

      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: 'sale_1',
          companyId: testCompanyId,
          customerId: const Value<String?>('cust_1'),
          saleNumber: 1,
          date: saleDateMs,
          totalAmount: 300000,
          cashReceived: const Value(0),
          creditAmount: const Value(300000),
          paymentType: 'credit',
          journalEntryId: 'je_dummy',
          createdBy: 'test_user',
          idempotencyKey: 'idem_sale_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = AgingReportService(db);
      final report = await service.generate(
        testCompanyId,
        reportDateMs: nowMs,
      );

      expect(report.lines.first.days31to60, equals(300000));
      expect(report.totalDays31to60, equals(300000));
    });

    test('Sale 75 days old falls in 61-90 day bucket', () async {
      final saleDateMs = nowMs - 75 * oneDayMs;

      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: 'sale_1',
          companyId: testCompanyId,
          customerId: const Value<String?>('cust_1'),
          saleNumber: 1,
          date: saleDateMs,
          totalAmount: 400000,
          cashReceived: const Value(0),
          creditAmount: const Value(400000),
          paymentType: 'credit',
          journalEntryId: 'je_dummy',
          createdBy: 'test_user',
          idempotencyKey: 'idem_sale_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = AgingReportService(db);
      final report = await service.generate(
        testCompanyId,
        reportDateMs: nowMs,
      );

      expect(report.lines.first.days61to90, equals(400000));
    });

    test('Sale 120 days old falls in over 90 day bucket', () async {
      final saleDateMs = nowMs - 120 * oneDayMs;

      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: 'sale_1',
          companyId: testCompanyId,
          customerId: const Value<String?>('cust_1'),
          saleNumber: 1,
          date: saleDateMs,
          totalAmount: 600000,
          cashReceived: const Value(0),
          creditAmount: const Value(600000),
          paymentType: 'credit',
          journalEntryId: 'je_dummy',
          createdBy: 'test_user',
          idempotencyKey: 'idem_sale_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = AgingReportService(db);
      final report = await service.generate(
        testCompanyId,
        reportDateMs: nowMs,
      );

      expect(report.lines.first.daysOver90, equals(600000));
    });

    test('Fully paid sales are excluded', () async {
      final saleDateMs = nowMs - 10 * oneDayMs;

      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: 'sale_1',
          companyId: testCompanyId,
          customerId: const Value<String?>('cust_1'),
          saleNumber: 1,
          date: saleDateMs,
          totalAmount: 100000,
          cashReceived: const Value(0),
          creditAmount: const Value(100000),
          paymentType: 'credit',
          journalEntryId: 'je_dummy',
          createdBy: 'test_user',
          idempotencyKey: 'idem_sale_1',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      await db.into(db.paymentAllocations).insert(
        PaymentAllocationsCompanion.insert(
          id: 'alloc_1',
          companyId: testCompanyId,
          paymentId: 'pay_1',
          saleId: const Value<String?>('sale_1'),
          allocatedAmount: 100000,
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = AgingReportService(db);
      final report = await service.generate(
        testCompanyId,
        reportDateMs: nowMs,
      );

      expect(report.lines, isEmpty);
    });

    test('Lines sorted by total outstanding descending', () async {
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: 'cust_2',
          companyId: testCompanyId,
          name: 'Sara',
          accountId: 'acc_ar_cust2_$testCompanyId',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final saleDateMs = nowMs - 5 * oneDayMs;

      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: 'sale_small',
          companyId: testCompanyId,
          customerId: const Value<String?>('cust_1'),
          saleNumber: 1,
          date: saleDateMs,
          totalAmount: 100000,
          cashReceived: const Value(0),
          creditAmount: const Value(100000),
          paymentType: 'credit',
          journalEntryId: 'je_dummy',
          createdBy: 'test_user',
          idempotencyKey: 'idem_sale_small',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      await db.into(db.sales).insert(
        SalesCompanion.insert(
          id: 'sale_large',
          companyId: testCompanyId,
          customerId: const Value<String?>('cust_2'),
          saleNumber: 2,
          date: saleDateMs,
          totalAmount: 500000,
          cashReceived: const Value(0),
          creditAmount: const Value(500000),
          paymentType: 'credit',
          journalEntryId: 'je_dummy2',
          createdBy: 'test_user',
          idempotencyKey: 'idem_sale_large',
          createdAt: nowMs,
          updatedAt: nowMs,
          deviceId: testDeviceId,
        ),
      );

      final service = AgingReportService(db);
      final report = await service.generate(
        testCompanyId,
        reportDateMs: nowMs,
      );

      expect(report.lines.length, equals(2));
      expect(report.lines[0].totalOutstanding >= report.lines[1].totalOutstanding, isTrue);
    });
  });
}
