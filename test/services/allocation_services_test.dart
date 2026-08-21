import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';
import 'package:accounting_system/data/database/app_database.dart';
import '../test_database_helper.dart';
import 'package:accounting_system/domain/accounting/services/payment_allocation_service.dart';
import 'package:accounting_system/domain/accounting/services/general_ledger_service.dart';
import 'package:accounting_system/domain/accounting/services/journal_report_service.dart';

void main() {
  late AppDatabase db;
  const testCompanyId = 'test_company';
  const testDeviceId = 'device_1';
  late int nowMs;

  setUp(() async {
    db = createTestDatabase();
    nowMs = DateTime.now().millisecondsSinceEpoch;
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
    await db.insertJournalEntryAtomic(
      header: JournalEntriesCompanion.insert(
        id: jeId,
        companyId: testCompanyId,
        entryNumber: entryNumber,
        date: nowMs,
        description: description,
        sourceType: sourceType,
        sourceId: sourceId,
        idempotencyKey: 'idem_$jeId',
        createdBy: 'test_user',
        createdAt: nowMs,
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
              createdAt: nowMs,
            ),
          )
          .toList(),
    );
  }

  Future<void> setupCustomerAndSale() async {
    final custAccId = 'acc_ar_cust_$testCompanyId';
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: custAccId,
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
        accountId: custAccId,
        createdAt: nowMs,
        updatedAt: nowMs,
        deviceId: testDeviceId,
      ),
    );

    await insertJournalEntry(
      jeId: 'je_sale',
      entryNumber: 1,
      description: 'Credit sale',
      sourceType: 'sale',
      sourceId: 'sale_1',
      lines: [
        (accountId: custAccId, debit: 100000, credit: 0),
        (accountId: accountId('4100'), debit: 0, credit: 100000),
      ],
    );

    await db.into(db.sales).insert(
      SalesCompanion.insert(
        id: 'sale_1',
        companyId: testCompanyId,
        customerId: const Value<String?>('cust_1'),
        saleNumber: 1,
        date: nowMs,
        totalAmount: 100000,
        cashReceived: const Value(0),
        creditAmount: const Value(100000),
        paymentType: 'credit',
        journalEntryId: 'je_sale',
        createdBy: 'test_user',
        idempotencyKey: 'idem_sale_1',
        createdAt: nowMs,
        updatedAt: nowMs,
        deviceId: testDeviceId,
      ),
    );
  }

  Future<void> setupSupplierAndPurchase() async {
    final suppAccId = 'acc_ap_supp_$testCompanyId';
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: suppAccId,
        companyId: testCompanyId,
        code: '2110',
        nameAr: 'ذمم دائنة',
        type: 'liability',
        normalBalance: 'credit',
        createdAt: nowMs,
        updatedAt: nowMs,
        deviceId: testDeviceId,
      ),
    );
    await db.into(db.suppliers).insert(
      SuppliersCompanion.insert(
        id: 'supp_1',
        companyId: testCompanyId,
        name: 'SuppCo',
        accountId: suppAccId,
        createdAt: nowMs,
        updatedAt: nowMs,
        deviceId: testDeviceId,
      ),
    );

    await insertJournalEntry(
      jeId: 'je_pur',
      entryNumber: 1,
      description: 'Credit purchase',
      sourceType: 'purchase',
      sourceId: 'pur_1',
      lines: [
        (accountId: accountId('1150'), debit: 200000, credit: 0),
        (accountId: suppAccId, debit: 0, credit: 200000),
      ],
    );

    await db.into(db.purchases).insert(
      PurchasesCompanion.insert(
        id: 'pur_1',
        companyId: testCompanyId,
        supplierId: const Value<String?>('supp_1'),
        purchaseNumber: 1,
        date: nowMs,
        totalAmount: 200000,
        cashPaid: const Value(0),
        creditAmount: const Value(200000),
        paymentType: 'credit',
        accountingNature: 'materials',
        targetAccountId: suppAccId,
        journalEntryId: 'je_pur',
        createdBy: 'test_user',
        idempotencyKey: 'idem_pur_1',
        createdAt: nowMs,
        updatedAt: nowMs,
        deviceId: testDeviceId,
      ),
    );
  }

  Future<String> insertPostedIncomingPayment({
    required String payId,
    required int amount,
    int? entryNumber,
    int? paymentNumber,
  }) async {
    final jeId = 'je_pay_$payId';
    await insertJournalEntry(
      jeId: jeId,
      entryNumber: entryNumber ?? 10,
      description: 'Incoming payment',
      sourceType: 'customer_payment',
      sourceId: payId,
      lines: [
        (accountId: accountId('1110'), debit: amount, credit: 0),
        (accountId: 'acc_ar_cust_$testCompanyId', debit: 0, credit: amount),
      ],
    );

    await db.into(db.payments).insert(
      PaymentsCompanion.insert(
        id: payId,
        companyId: testCompanyId,
        paymentNumber: paymentNumber ?? 1,
        date: nowMs,
        amount: amount,
        paymentMethod: 'cash',
        direction: 'incoming',
        customerId: const Value<String?>('cust_1'),
        journalEntryId: jeId,
        createdBy: 'test_user',
        idempotencyKey: 'idem_$payId',
        createdAt: nowMs,
        updatedAt: nowMs,
        deviceId: testDeviceId,
      ),
    );
    return jeId;
  }

  Future<String> insertPostedOutgoingPayment({
    required String payId,
    required int amount,
    int? entryNumber,
    int? paymentNumber,
  }) async {
    final jeId = 'je_pay_out_$payId';
    await insertJournalEntry(
      jeId: jeId,
      entryNumber: entryNumber ?? 10,
      description: 'Outgoing payment',
      sourceType: 'supplier_payment',
      sourceId: payId,
      lines: [
        (accountId: 'acc_ap_supp_$testCompanyId', debit: amount, credit: 0),
        (accountId: accountId('1110'), debit: 0, credit: amount),
      ],
    );

    await db.into(db.payments).insert(
      PaymentsCompanion.insert(
        id: payId,
        companyId: testCompanyId,
        paymentNumber: paymentNumber ?? 1,
        date: nowMs,
        amount: amount,
        paymentMethod: 'cash',
        direction: 'outgoing',
        supplierId: const Value<String?>('supp_1'),
        journalEntryId: jeId,
        createdBy: 'test_user',
        idempotencyKey: 'idem_$payId',
        createdAt: nowMs,
        updatedAt: nowMs,
        deviceId: testDeviceId,
      ),
    );
    return jeId;
  }

  // ===========================================================================
  // PaymentAllocationService
  // ===========================================================================
  group('PaymentAllocationService', () {
    test('allocatePayment throws for nonexistent payment', () async {
      final service = PaymentAllocationService(db);
      expect(
        () => service.allocatePayment(
          paymentId: 'nonexistent',
          saleId: 'sale_1',
          amount: 10000,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allocatePayment throws when amount is zero or negative', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 50000);

      final service = PaymentAllocationService(db);
      expect(
        () => service.allocatePayment(
          paymentId: 'pay_1',
          saleId: 'sale_1',
          amount: 0,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => service.allocatePayment(
          paymentId: 'pay_1',
          saleId: 'sale_1',
          amount: -100,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('allocatePayment throws when neither saleId nor purchaseId provided', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 50000);

      final service = PaymentAllocationService(db);
      expect(
        () => service.allocatePayment(
          paymentId: 'pay_1',
          amount: 10000,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('allocatePayment throws when both saleId and purchaseId provided', () async {
      await setupCustomerAndSale();
      await setupSupplierAndPurchase();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 50000);

      final service = PaymentAllocationService(db);
      expect(
        () => service.allocatePayment(
          paymentId: 'pay_1',
          saleId: 'sale_1',
          purchaseId: 'pur_1',
          amount: 10000,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('allocatePayment throws when amount exceeds payment', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 10000);

      final service = PaymentAllocationService(db);
      expect(
        () => service.allocatePayment(
          paymentId: 'pay_1',
          saleId: 'sale_1',
          amount: 50000,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('allocatePayment throws when amount exceeds document outstanding', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 500000);

      final service = PaymentAllocationService(db);
      expect(
        () => service.allocatePayment(
          paymentId: 'pay_1',
          saleId: 'sale_1',
          amount: 200000,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Valid partial allocation returns correct result', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 80000);

      final service = PaymentAllocationService(db);
      final result = await service.allocatePayment(
        paymentId: 'pay_1',
        saleId: 'sale_1',
        amount: 50000,
        companyId: testCompanyId,
        deviceId: testDeviceId,
      );

      expect(result.allocationId, isNotEmpty);
      expect(result.paymentId, equals('pay_1'));
      expect(result.saleId, equals('sale_1'));
      expect(result.purchaseId, isNull);
      expect(result.allocatedAmount, equals(50000));
      expect(result.remainingPaymentAmount, equals(30000));
      expect(result.remainingDocumentAmount, equals(50000));
    });

    test('getUnallocatedAmount returns full amount for unallocated payment', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 80000);

      final service = PaymentAllocationService(db);
      final unallocated = await service.getUnallocatedAmount('pay_1');
      expect(unallocated, equals(80000));
    });

    test('getUnallocatedAmount returns 0 for nonexistent payment', () async {
      final service = PaymentAllocationService(db);
      final unallocated = await service.getUnallocatedAmount('nonexistent');
      expect(unallocated, equals(0));
    });

    test('getUnallocatedAmount reduces after allocation', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 80000);

      final service = PaymentAllocationService(db);
      await service.allocatePayment(
        paymentId: 'pay_1',
        saleId: 'sale_1',
        amount: 30000,
        companyId: testCompanyId,
        deviceId: testDeviceId,
      );

      final unallocated = await service.getUnallocatedAmount('pay_1');
      expect(unallocated, equals(50000));
    });

    test('getDocumentOutstanding returns sale total amount initially', () async {
      await setupCustomerAndSale();

      final service = PaymentAllocationService(db);
      final outstanding =
          await service.getDocumentOutstanding('sale_1', null);
      expect(outstanding, equals(100000));
    });

    test('getDocumentOutstanding returns 0 for nonexistent sale', () async {
      final service = PaymentAllocationService(db);
      final outstanding =
          await service.getDocumentOutstanding('nonexistent', null);
      expect(outstanding, equals(0));
    });

    test('getDocumentOutstanding reduces after allocation', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 80000);

      final service = PaymentAllocationService(db);
      await service.allocatePayment(
        paymentId: 'pay_1',
        saleId: 'sale_1',
        amount: 40000,
        companyId: testCompanyId,
        deviceId: testDeviceId,
      );

      final outstanding =
          await service.getDocumentOutstanding('sale_1', null);
      expect(outstanding, equals(60000));
    });

    test('Outgoing payment allocated to purchase succeeds', () async {
      await setupSupplierAndPurchase();
      await insertPostedOutgoingPayment(payId: 'pay_out_1', amount: 150000);

      final service = PaymentAllocationService(db);
      final result = await service.allocatePayment(
        paymentId: 'pay_out_1',
        purchaseId: 'pur_1',
        amount: 100000,
        companyId: testCompanyId,
        deviceId: testDeviceId,
      );

      expect(result.purchaseId, equals('pur_1'));
      expect(result.saleId, isNull);
      expect(result.allocatedAmount, equals(100000));
      expect(result.remainingPaymentAmount, equals(50000));
      expect(result.remainingDocumentAmount, equals(100000));
    });

    test('Incoming payment cannot be allocated to purchase', () async {
      await setupCustomerAndSale();
      await setupSupplierAndPurchase();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 50000);

      final service = PaymentAllocationService(db);
      expect(
        () => service.allocatePayment(
          paymentId: 'pay_1',
          purchaseId: 'pur_1',
          amount: 10000,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Outgoing payment cannot be allocated to sale', () async {
      await setupCustomerAndSale();
      await setupSupplierAndPurchase();
      await insertPostedOutgoingPayment(payId: 'pay_out_1', amount: 50000);

      final service = PaymentAllocationService(db);
      expect(
        () => service.allocatePayment(
          paymentId: 'pay_out_1',
          saleId: 'sale_1',
          amount: 10000,
          companyId: testCompanyId,
          deviceId: testDeviceId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Multiple allocations on same payment sum correctly', () async {
      await setupCustomerAndSale();
      await insertPostedIncomingPayment(payId: 'pay_1', amount: 80000);

      final service = PaymentAllocationService(db);
      await service.allocatePayment(
        paymentId: 'pay_1',
        saleId: 'sale_1',
        amount: 30000,
        companyId: testCompanyId,
        deviceId: testDeviceId,
      );
      await service.allocatePayment(
        paymentId: 'pay_1',
        saleId: 'sale_1',
        amount: 20000,
        companyId: testCompanyId,
        deviceId: testDeviceId,
      );

      final unallocated = await service.getUnallocatedAmount('pay_1');
      expect(unallocated, equals(30000));

      final outstanding =
          await service.getDocumentOutstanding('sale_1', null);
      expect(outstanding, equals(50000));
    });
  });

  // ===========================================================================
  // GeneralLedgerService
  // ===========================================================================
  group('GeneralLedgerService', () {
    test('Empty database returns empty ledger', () async {
      final service = GeneralLedgerService(db);
      final report = await service.generate(testCompanyId);
      expect(report.entries, isEmpty);
      expect(report.totalDebit, equals(0));
      expect(report.totalCredit, equals(0));
    });

    test('Posted journal entries appear in ledger', () async {
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

      final service = GeneralLedgerService(db);
      final report = await service.generate(testCompanyId);
      expect(report.entries.length, equals(2));
      expect(report.totalDebit, equals(500000));
      expect(report.totalCredit, equals(500000));
    });

    test('Entries are sorted by date then entry number', () async {
      final earlierMs = nowMs - 100000;
      await db.insertJournalEntryAtomic(
        header: JournalEntriesCompanion.insert(
          id: 'je_2',
          companyId: testCompanyId,
          entryNumber: 2,
          date: earlierMs,
          description: 'Earlier entry',
          sourceType: 'sale',
          sourceId: 'sale_2',
          idempotencyKey: 'idem_je_2',
          createdBy: 'test_user',
          createdAt: earlierMs,
          deviceId: testDeviceId,
        ),
        lines: [
          JournalEntryLinesCompanion.insert(
            id: 'jel_2_0',
            companyId: testCompanyId,
            journalEntryId: 'je_2',
            accountId: accountId('1110'),
            debitAmount: const Value(100000),
            creditAmount: const Value(0),
            createdAt: earlierMs,
          ),
          JournalEntryLinesCompanion.insert(
            id: 'jel_2_1',
            companyId: testCompanyId,
            journalEntryId: 'je_2',
            accountId: accountId('4100'),
            debitAmount: const Value(0),
            creditAmount: const Value(100000),
            createdAt: earlierMs,
          ),
        ],
      );

      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Later entry',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 200000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 200000),
        ],
      );

      final service = GeneralLedgerService(db);
      final report = await service.generate(testCompanyId);

      expect(report.entries.length, equals(4));
      expect(report.entries[0].dateMs, equals(earlierMs));
      expect(report.entries[2].dateMs, equals(nowMs));
    });

    test('Date range filtering works correctly', () async {
      final oldMs = nowMs - 200 * 86400000;

      await db.insertJournalEntryAtomic(
        header: JournalEntriesCompanion.insert(
          id: 'je_old',
          companyId: testCompanyId,
          entryNumber: 1,
          date: oldMs,
          description: 'Old entry',
          sourceType: 'sale',
          sourceId: 'sale_old',
          idempotencyKey: 'idem_je_old',
          createdBy: 'test_user',
          createdAt: oldMs,
          deviceId: testDeviceId,
        ),
        lines: [
          JournalEntryLinesCompanion.insert(
            id: 'jel_old_0',
            companyId: testCompanyId,
            journalEntryId: 'je_old',
            accountId: accountId('1110'),
            debitAmount: const Value(100000),
            creditAmount: const Value(0),
            createdAt: oldMs,
          ),
          JournalEntryLinesCompanion.insert(
            id: 'jel_old_1',
            companyId: testCompanyId,
            journalEntryId: 'je_old',
            accountId: accountId('4100'),
            debitAmount: const Value(0),
            creditAmount: const Value(100000),
            createdAt: oldMs,
          ),
        ],
      );

      await insertJournalEntry(
        jeId: 'je_new',
        entryNumber: 2,
        description: 'New entry',
        sourceType: 'sale',
        sourceId: 'sale_new',
        lines: [
          (accountId: accountId('1110'), debit: 200000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 200000),
        ],
      );

      final service = GeneralLedgerService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.entries.length, equals(2));
      for (final entry in report.entries) {
        expect(entry.dateMs >= nowMs - 86400000, isTrue);
      }
    });

    test('Only posted entries are included', () async {
      await db.insertJournalEntryAtomic(
        header: JournalEntriesCompanion.insert(
          id: 'je_draft',
          companyId: testCompanyId,
          entryNumber: 1,
          date: nowMs,
          description: 'Draft entry',
          sourceType: 'sale',
          sourceId: 'sale_draft',
          idempotencyKey: 'idem_je_draft',
          createdBy: 'test_user',
          createdAt: nowMs,
          deviceId: testDeviceId,
          status: const Value('draft'),
        ),
        lines: [
          JournalEntryLinesCompanion.insert(
            id: 'jel_draft_0',
            companyId: testCompanyId,
            journalEntryId: 'je_draft',
            accountId: accountId('1110'),
            debitAmount: const Value(100000),
            creditAmount: const Value(0),
            createdAt: nowMs,
          ),
          JournalEntryLinesCompanion.insert(
            id: 'jel_draft_1',
            companyId: testCompanyId,
            journalEntryId: 'je_draft',
            accountId: accountId('4100'),
            debitAmount: const Value(0),
            creditAmount: const Value(100000),
            createdAt: nowMs,
          ),
        ],
      );

      final service = GeneralLedgerService(db);
      final report = await service.generate(testCompanyId);
      expect(report.entries, isEmpty);
    });

    test('Entries from other companies excluded', () async {
      await insertJournalEntry(
        jeId: 'je_own',
        entryNumber: 1,
        description: 'Own entry',
        sourceType: 'sale',
        sourceId: 'sale_own',
        lines: [
          (accountId: accountId('1110'), debit: 100000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 100000),
        ],
      );

      const otherCompanyId = 'other_company';
      await db.seedCompanyDefaults(otherCompanyId, testDeviceId);

      final service = GeneralLedgerService(db);
      final ownReport = await service.generate(testCompanyId);
      final otherReport = await service.generate(otherCompanyId);

      expect(ownReport.entries.length, equals(2));
      expect(otherReport.entries, isEmpty);
    });

    test('Account codes resolved correctly in ledger entries', () async {
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

      final service = GeneralLedgerService(db);
      final report = await service.generate(testCompanyId);

      final cashEntry = report.entries.firstWhere((e) => e.accountCode == '1110');
      expect(cashEntry.debitAmount, equals(500000));
      expect(cashEntry.creditAmount, equals(0));

      final revenueEntry =
          report.entries.firstWhere((e) => e.accountCode == '4100');
      expect(revenueEntry.debitAmount, equals(0));
      expect(revenueEntry.creditAmount, equals(500000));
    });

    test('General ledger total debit equals total credit', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Sale 1',
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
        description: 'Sale 2',
        sourceType: 'sale',
        sourceId: 'sale_2',
        lines: [
          (accountId: accountId('1110'), debit: 200000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 200000),
        ],
      );

      final service = GeneralLedgerService(db);
      final report = await service.generate(testCompanyId);
      expect(report.totalDebit, equals(report.totalCredit));
    });
  });

  // ===========================================================================
  // JournalReportService
  // ===========================================================================
  group('JournalReportService', () {
    test('Empty database returns empty journal report', () async {
      final service = JournalReportService(db);
      final report = await service.generate(testCompanyId);
      expect(report.entries, isEmpty);
      expect(report.grandTotalDebit, equals(0));
      expect(report.grandTotalCredit, equals(0));
    });

    test('Journal entries appear with correct line details', () async {
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

      final service = JournalReportService(db);
      final report = await service.generate(testCompanyId);
      expect(report.entries.length, equals(1));
      expect(report.entries.first.lines.length, equals(2));
      expect(report.entries.first.totalDebit, equals(500000));
      expect(report.entries.first.totalCredit, equals(500000));
      expect(report.entries.first.description, equals('Cash sale'));
    });

    test('All journal entries are included regardless of status', () async {
      await insertJournalEntry(
        jeId: 'je_posted',
        entryNumber: 1,
        description: 'Posted entry',
        sourceType: 'sale',
        sourceId: 'sale_1',
        lines: [
          (accountId: accountId('1110'), debit: 100000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 100000),
        ],
      );

      await db.insertJournalEntryAtomic(
        header: JournalEntriesCompanion.insert(
          id: 'je_reversed',
          companyId: testCompanyId,
          entryNumber: 2,
          date: nowMs,
          description: 'Reversed entry',
          sourceType: 'sale',
          sourceId: 'sale_2',
          idempotencyKey: 'idem_je_rev',
          createdBy: 'test_user',
          createdAt: nowMs,
          deviceId: testDeviceId,
          status: const Value('reversed'),
        ),
        lines: [
          JournalEntryLinesCompanion.insert(
            id: 'jel_rev_0',
            companyId: testCompanyId,
            journalEntryId: 'je_reversed',
            accountId: accountId('1110'),
            debitAmount: const Value(50000),
            creditAmount: const Value(0),
            createdAt: nowMs,
          ),
          JournalEntryLinesCompanion.insert(
            id: 'jel_rev_1',
            companyId: testCompanyId,
            journalEntryId: 'je_reversed',
            accountId: accountId('4100'),
            debitAmount: const Value(0),
            creditAmount: const Value(50000),
            createdAt: nowMs,
          ),
        ],
      );

      final service = JournalReportService(db);
      final report = await service.generate(testCompanyId);
      expect(report.entries.length, equals(2));

      final reversedEntry =
          report.entries.firstWhere((e) => e.entryId == 'je_reversed');
      expect(reversedEntry.status, equals('reversed'));
    });

    test('Date range filtering with both from and to dates', () async {
      final oldMs = nowMs - 300 * 86400000;

      await db.insertJournalEntryAtomic(
        header: JournalEntriesCompanion.insert(
          id: 'je_old',
          companyId: testCompanyId,
          entryNumber: 1,
          date: oldMs,
          description: 'Old entry',
          sourceType: 'sale',
          sourceId: 'sale_old',
          idempotencyKey: 'idem_je_old',
          createdBy: 'test_user',
          createdAt: oldMs,
          deviceId: testDeviceId,
        ),
        lines: [
          JournalEntryLinesCompanion.insert(
            id: 'jel_old_0',
            companyId: testCompanyId,
            journalEntryId: 'je_old',
            accountId: accountId('1110'),
            debitAmount: const Value(100000),
            creditAmount: const Value(0),
            createdAt: oldMs,
          ),
          JournalEntryLinesCompanion.insert(
            id: 'jel_old_1',
            companyId: testCompanyId,
            journalEntryId: 'je_old',
            accountId: accountId('4100'),
            debitAmount: const Value(0),
            creditAmount: const Value(100000),
            createdAt: oldMs,
          ),
        ],
      );

      await insertJournalEntry(
        jeId: 'je_new',
        entryNumber: 2,
        description: 'New entry',
        sourceType: 'sale',
        sourceId: 'sale_new',
        lines: [
          (accountId: accountId('1110'), debit: 200000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 200000),
        ],
      );

      final service = JournalReportService(db);
      final report = await service.generate(
        testCompanyId,
        fromDateMs: nowMs - 86400000,
        toDateMs: nowMs + 86400000,
      );

      expect(report.entries.length, equals(1));
      expect(report.entries.first.entryId, equals('je_new'));
    });

    test('Entries from other companies excluded', () async {
      await insertJournalEntry(
        jeId: 'je_own',
        entryNumber: 1,
        description: 'Own',
        sourceType: 'sale',
        sourceId: 'sale_own',
        lines: [
          (accountId: accountId('1110'), debit: 100000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 100000),
        ],
      );

      const otherCompanyId = 'other_company';
      await db.seedCompanyDefaults(otherCompanyId, testDeviceId);

      final service = JournalReportService(db);
      final otherReport = await service.generate(otherCompanyId);
      expect(otherReport.entries, isEmpty);
    });

    test('Grand totals equal sum of all entry totals', () async {
      await insertJournalEntry(
        jeId: 'je_1',
        entryNumber: 1,
        description: 'Sale 1',
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
        description: 'Sale 2',
        sourceType: 'sale',
        sourceId: 'sale_2',
        lines: [
          (accountId: accountId('1110'), debit: 200000, credit: 0),
          (accountId: accountId('4100'), debit: 0, credit: 200000),
          (accountId: accountId('7100'), debit: 50000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 50000),
        ],
      );

      final service = JournalReportService(db);
      final report = await service.generate(testCompanyId);

      int expectedDebit = 0;
      int expectedCredit = 0;
      for (final entry in report.entries) {
        expectedDebit += entry.totalDebit;
        expectedCredit += entry.totalCredit;
      }

      expect(report.grandTotalDebit, equals(expectedDebit));
      expect(report.grandTotalCredit, equals(expectedCredit));
    });

    test('Grand total debit equals grand total credit (balanced ledger)', () async {
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
          (accountId: accountId('7100'), debit: 100000, credit: 0),
          (accountId: accountId('1110'), debit: 0, credit: 100000),
        ],
      );

      final service = JournalReportService(db);
      final report = await service.generate(testCompanyId);
      expect(report.grandTotalDebit, equals(report.grandTotalCredit));
    });

    test('Account codes are resolved in journal report lines', () async {
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

      final service = JournalReportService(db);
      final report = await service.generate(testCompanyId);

      final entry = report.entries.first;
      final cashLine = entry.lines.firstWhere((l) => l.accountCode == '1110');
      expect(cashLine.debitAmount, equals(500000));

      final revenueLine = entry.lines.firstWhere((l) => l.accountCode == '4100');
      expect(revenueLine.creditAmount, equals(500000));
    });
  });
}
