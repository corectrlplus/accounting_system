import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';
import '../../lib/data/database/app_database.dart';
import '../test_database_helper.dart';
import '../../lib/core/errors/database_exception.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.now().millisecondsSinceEpoch;

  setUp(() async {
    db = createTestDatabase();

    // Setup base fixtures for Company 1
    await db.into(db.companies).insert(
      CompaniesCompanion.insert(
        id: 'comp_1',
        name: 'Test Co 1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    // Setup base fixtures for Company 2
    await db.into(db.companies).insert(
      CompaniesCompanion.insert(
        id: 'comp_2',
        name: 'Test Co 2',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_2',
      ),
    );

    await db.into(db.roles).insert(
      RolesCompanion.insert(
        id: 'role_1',
        companyId: 'comp_1',
        name: 'Owner',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    await db.into(db.users).insert(
      UsersCompanion.insert(
        id: 'user_1',
        companyId: 'comp_1',
        roleId: 'role_1',
        email: 'user@test.com',
        displayName: 'User 1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc_ar',
        companyId: 'comp_1',
        code: '1130',
        nameAr: 'ذمم مدينة',
        type: 'asset',
        normalBalance: 'debit',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    await db.into(db.customers).insert(
      CustomersCompanion.insert(
        id: 'cust_1',
        companyId: 'comp_1',
        name: 'Ahmed',
        accountId: 'acc_ar',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    await db.into(db.suppliers).insert(
      SuppliersCompanion.insert(
        id: 'supp_1',
        companyId: 'comp_1',
        name: 'SuppCo',
        accountId: 'acc_ar',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    await db.into(db.journalEntries).insert(
      JournalEntriesCompanion.insert(
        id: 'je_dummy',
        companyId: 'comp_1',
        entryNumber: 1,
        date: now,
        description: 'Dummy',
        sourceType: 'sale',
        sourceId: 'sale_1',
        idempotencyKey: 'key_dummy',
        createdBy: 'user_1',
        createdAt: now,
        deviceId: 'dev_1',
      ),
    );

    // Sale #1 (Company 1): Total = 100,000
    await db.into(db.sales).insert(
      SalesCompanion.insert(
        id: 'sale_1',
        companyId: 'comp_1',
        customerId: const Value<String?>('cust_1'),
        saleNumber: 1,
        date: now,
        totalAmount: 100000,
        cashReceived: const Value(0),
        creditAmount: const Value(100000),
        paymentType: 'credit',
        journalEntryId: 'je_dummy',
        createdBy: 'user_1',
        idempotencyKey: 'key_sale_1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    // Incoming Payment #1 (Company 1): Amount = 80,000
    await db.into(db.payments).insert(
      PaymentsCompanion.insert(
        id: 'pay_1',
        companyId: 'comp_1',
        paymentNumber: 1,
        date: now,
        amount: 80000,
        paymentMethod: 'cash',
        direction: 'incoming',
        customerId: const Value<String?>('cust_1'),
        journalEntryId: 'je_dummy',
        createdBy: 'user_1',
        idempotencyKey: 'key_pay_1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    // Purchase #1 (Company 1): Total = 100,000
    await db.into(db.purchases).insert(
      PurchasesCompanion.insert(
        id: 'pur_1',
        companyId: 'comp_1',
        supplierId: const Value<String?>('supp_1'),
        purchaseNumber: 1,
        date: now,
        totalAmount: 100000,
        cashPaid: const Value(0),
        creditAmount: const Value(100000),
        paymentType: 'credit',
        accountingNature: 'materials',
        targetAccountId: 'acc_ar',
        journalEntryId: 'je_dummy',
        createdBy: 'user_1',
        idempotencyKey: 'key_pur_1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    // Outgoing Payment #1 (Company 1): Amount = 100,000
    await db.into(db.payments).insert(
      PaymentsCompanion.insert(
        id: 'pay_out_1',
        companyId: 'comp_1',
        paymentNumber: 2,
        date: now,
        amount: 100000,
        paymentMethod: 'cash',
        direction: 'outgoing',
        supplierId: const Value<String?>('supp_1'),
        journalEntryId: 'je_dummy',
        createdBy: 'user_1',
        idempotencyKey: 'key_pay_out_1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Payment Allocation Concurrency & Integrity Tests', () {
    test('1. Valid partial allocation succeeds', () async {
      await db.executeAllocationConcurrentlySafe(
        allocationId: 'alloc_1',
        companyId: 'comp_1',
        paymentId: 'pay_1',
        saleId: 'sale_1',
        allocatedAmount: 50000,
        deviceId: 'dev_1',
      );

      final alloc = await (db.select(db.paymentAllocations)..where((a) => a.id.equals('alloc_1'))).getSingle();
      expect(alloc.allocatedAmount, equals(50000));
    });

    test('2. Full allocation (exact 100,000) succeeds', () async {
      // Create Payment #2 of 100,000
      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: 'pay_full',
          companyId: 'comp_1',
          paymentNumber: 99,
          date: now,
          amount: 100000,
          paymentMethod: 'cash',
          direction: 'incoming',
          customerId: const Value<String?>('cust_1'),
          journalEntryId: 'je_dummy',
          createdBy: 'user_1',
          idempotencyKey: 'key_pay_full',
          createdAt: now,
          updatedAt: now,
          deviceId: 'dev_1',
        ),
      );

      await db.executeAllocationConcurrentlySafe(
        allocationId: 'alloc_full',
        companyId: 'comp_1',
        paymentId: 'pay_full',
        saleId: 'sale_1',
        allocatedAmount: 100000,
        deviceId: 'dev_1',
      );

      final alloc = await (db.select(db.paymentAllocations)..where((a) => a.id.equals('alloc_full'))).getSingle();
      expect(alloc.allocatedAmount, equals(100000));
    });

    test('3. REAL CONCURRENT ALLOCATION TEST (Future.wait): Tx A (60k) & Tx B (60k) against Invoice (100k)', () async {
      // Invoice Total = 100,000 (Sale #1)
      // Payment Amount = 150,000 (Large enough so payment limit is not exceeded)
      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          id: 'pay_large',
          companyId: 'comp_1',
          paymentNumber: 3,
          date: now,
          amount: 150000,
          paymentMethod: 'cash',
          direction: 'incoming',
          customerId: const Value<String?>('cust_1'),
          journalEntryId: 'je_dummy',
          createdBy: 'user_1',
          idempotencyKey: 'key_pay_large',
          createdAt: now,
          updatedAt: now,
          deviceId: 'dev_1',
        ),
      );

      // Launch Transaction A (60,000) and Transaction B (60,000) simultaneously via Future.wait
      final taskA = db.executeAllocationConcurrentlySafe(
        allocationId: 'alloc_conc_A',
        companyId: 'comp_1',
        paymentId: 'pay_large',
        saleId: 'sale_1',
        allocatedAmount: 60000,
        deviceId: 'dev_A',
      );

      final taskB = db.executeAllocationConcurrentlySafe(
        allocationId: 'alloc_conc_B',
        companyId: 'comp_1',
        paymentId: 'pay_large',
        saleId: 'sale_1',
        allocatedAmount: 60000,
        deviceId: 'dev_B',
      );

      // Execute both futures concurrently
      final results = await Future.wait([
        taskA.then((_) => 'success').catchError((Object e) => 'error:${e.runtimeType}'),
        taskB.then((_) => 'success').catchError((Object e) => 'error:${e.runtimeType}'),
      ]);

      // Exactly ONE transaction must succeed, and ONE transaction must fail with AllocationConcurrencyException
      expect(results, contains('success'));
      expect(results, contains('error:AllocationConcurrencyException'));

      // Check committed allocations against sale_1: Total MUST be exactly 60,000 (NEVER 120,000)
      final committedAllocations = await (db.select(db.paymentAllocations)..where((a) => a.saleId.equals('sale_1'))).get();
      final totalCommitted = committedAllocations.fold<int>(0, (sum, a) => sum + a.allocatedAmount);

      expect(totalCommitted, equals(60000));
      expect(totalCommitted <= 100000, isTrue);
    });

    test('4. Outgoing payment allocated to Purchase succeeds', () async {
      await db.executeAllocationConcurrentlySafe(
        allocationId: 'alloc_out_1',
        companyId: 'comp_1',
        paymentId: 'pay_out_1',
        purchaseId: 'pur_1',
        allocatedAmount: 100000,
        deviceId: 'dev_1',
      );

      final alloc = await (db.select(db.paymentAllocations)..where((a) => a.id.equals('alloc_out_1'))).getSingle();
      expect(alloc.allocatedAmount, equals(100000));
    });

    test('5. Outgoing payment allocated to Sale throws PaymentDirectionMismatchException', () async {
      expect(
        () => db.executeAllocationConcurrentlySafe(
          allocationId: 'alloc_invalid_out_sale',
          companyId: 'comp_1',
          paymentId: 'pay_out_1',
          saleId: 'sale_1',
          allocatedAmount: 10000,
          deviceId: 'dev_1',
        ),
        throwsA(isA<PaymentDirectionMismatchException>()),
      );
    });

    test('6. Incoming payment allocated to Purchase throws PaymentDirectionMismatchException', () async {
      expect(
        () => db.executeAllocationConcurrentlySafe(
          allocationId: 'alloc_invalid_dir',
          companyId: 'comp_1',
          paymentId: 'pay_1',
          purchaseId: 'pur_1',
          allocatedAmount: 10000,
          deviceId: 'dev_1',
        ),
        throwsA(isA<PaymentDirectionMismatchException>()),
      );
    });
  });
}
