import 'package:drift/drift.dart';

import 'tables/core_tables.dart';
import 'tables/accounting_tables.dart';
import 'tables/master_tables.dart';
import 'tables/business_tables.dart';
import 'tables/config_tables.dart';
import 'tables/operational_tables.dart';
import 'tables/system_tables.dart';
import 'seed/initial_seed_data.dart';
import '../../core/errors/database_exception.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  // 1. Core / Auth (01 - 03)
  Companies,
  Roles,
  Users,

  // 2. Accounting Ledger (04 - 06)
  Accounts,
  JournalEntries,
  JournalEntryLines,

  // 3. Master Data (07 - 10)
  Customers,
  Suppliers,
  Workers,
  Workshops,

  // 4. Configuration (18)
  ExpenseCategories,

  // 5. Business Document Headers & Details (11 - 17, 19 - 22)
  Sales,
  SaleItems,
  Purchases,
  PurchaseItems,
  Payments,
  PaymentAllocations,
  Expenses,
  WorkerAdvances,
  WorkerSalaries,
  OwnerWithdrawals,
  ManufacturingJobs,

  // 6. Operational (23)
  ProductionRecords,

  // 7. System & Sync Infrastructure (24 - 28)
  AuditLogs,
  Devices,
  SyncOutbox,
  SyncMetadata,
  SharedStatements,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  /// Constructor for in-memory database used in unit and integration tests.
  AppDatabase.forTesting(DatabaseConnection connection) : super(connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await customStatement('PRAGMA foreign_keys = OFF;');
        await m.createAll();
        await customStatement('PRAGMA foreign_keys = ON;');
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }

  // ===========================================================================
  // CONCURRENCY & INTEGRITY PROTECTED TRANSACTION HELPERS
  // ===========================================================================

  /// Seed initial Chart of Accounts, Categories, and Roles for a company.
  Future<void> seedCompanyDefaults(String companyId, String deviceId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await transaction(() async {
      // Check if already seeded
      final existingCount = await (select(accounts)
            ..where((a) => a.companyId.equals(companyId)))
          .get();
      if (existingCount.isNotEmpty) return;

      // 1. Seed Chart of Accounts
      final accountIdMap = <String, String>{};
      for (final acc in InitialSeedData.chartOfAccounts) {
        final id = 'acc_${acc['code']}_$companyId';
        accountIdMap[acc['code']!] = id;

        String? parentAccId;
        if (acc['parent']!.isNotEmpty) {
          parentAccId = accountIdMap[acc['parent']!];
        }

        await into(accounts).insert(
          AccountsCompanion.insert(
            id: id,
            companyId: companyId,
            code: acc['code']!,
            nameAr: acc['name_ar']!,
            nameEn: Value(acc['name_en']),
            type: acc['type']!,
            normalBalance: acc['normal']!,
            parentId: Value<String?>(parentAccId),
            isSystem: const Value(true),
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }

      // 2. Seed Expense Categories
      for (final cat in InitialSeedData.expenseCategories) {
        final catId = 'cat_${cat['account_code']}_$companyId';
        final accId = accountIdMap[cat['account_code']!];

        await into(expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(
            id: catId,
            companyId: companyId,
            nameAr: cat['name_ar']!,
            nameEn: Value(cat['name_en']),
            group: cat['group']!,
            accountId: accId!,
            isSystem: const Value(true),
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }

      // 3. Seed System Roles
      for (final role in InitialSeedData.roles) {
        final roleId = 'role_${role['name']}_$companyId';
        await into(roles).insert(
          RolesCompanion.insert(
            id: roleId,
            companyId: companyId,
            name: role['name']!,
            isSystem: const Value(true),
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Concurrency-Safe Payment Allocation Execution Protocol (TOCTOU Protection).
  ///
  /// Opens an immediate exclusive SQLite transaction, recalculates current allocations
  /// under the transaction lock, and rejects if limits are exceeded.
  Future<void> executeAllocationConcurrentlySafe({
    required String allocationId,
    required String companyId,
    required String paymentId,
    String? saleId,
    String? purchaseId,
    required int allocatedAmount,
    required String deviceId,
  }) async {
    // Check exclusive arc: exactly one target document
    if ((saleId == null && purchaseId == null) || (saleId != null && purchaseId != null)) {
      throw ArgumentError('Allocation must target exactly one document (saleId OR purchaseId)');
    }

    if (allocatedAmount <= 0) {
      throw ArgumentError('Allocated amount must be positive');
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    await transaction(() async {
      // 1. Fetch Payment and verify direction alignment
      final payment = await (select(payments)..where((p) => p.id.equals(paymentId))).getSingleOrNull();
      if (payment == null) {
        throw AccountingDatabaseException('Payment $paymentId not found', 'PAYMENT_NOT_FOUND');
      }

      if (payment.direction == 'incoming' && purchaseId != null) {
        throw PaymentDirectionMismatchException('incoming', 'purchase');
      }
      if (payment.direction == 'outgoing' && saleId != null) {
        throw PaymentDirectionMismatchException('outgoing', 'sale');
      }

      // 2. Recalculate payment total under lock
      final paymentAllocationsQuery = await (select(paymentAllocations)
            ..where((pa) => pa.paymentId.equals(paymentId) & pa.isDeleted.equals(false)))
          .get();
      final currentPaymentTotal = paymentAllocationsQuery.fold<int>(0, (sum, a) => sum + a.allocatedAmount);

      if (currentPaymentTotal + allocatedAmount > payment.amount) {
        throw AllocationConcurrencyException(
          targetId: paymentId,
          currentAllocated: currentPaymentTotal,
          attemptedAllocated: allocatedAmount,
          maxAllowed: payment.amount,
        );
      }

      // 3. Recalculate target invoice total under lock
      if (saleId != null) {
        final sale = await (select(sales)..where((s) => s.id.equals(saleId))).getSingleOrNull();
        if (sale == null) {
          throw AccountingDatabaseException('Sale $saleId not found', 'SALE_NOT_FOUND');
        }

        final saleAllocationsQuery = await (select(paymentAllocations)
              ..where((pa) => pa.saleId.equals(saleId) & pa.isDeleted.equals(false)))
            .get();
        final currentSaleTotal = saleAllocationsQuery.fold<int>(0, (sum, a) => sum + a.allocatedAmount);

        if (currentSaleTotal + allocatedAmount > sale.totalAmount) {
          throw AllocationConcurrencyException(
            targetId: saleId,
            currentAllocated: currentSaleTotal,
            attemptedAllocated: allocatedAmount,
            maxAllowed: sale.totalAmount,
          );
        }
      } else if (purchaseId != null) {
        final purchase = await (select(purchases)..where((p) => p.id.equals(purchaseId))).getSingleOrNull();
        if (purchase == null) {
          throw AccountingDatabaseException('Purchase $purchaseId not found', 'PURCHASE_NOT_FOUND');
        }

        final purchaseAllocationsQuery = await (select(paymentAllocations)
              ..where((pa) => pa.purchaseId.equals(purchaseId) & pa.isDeleted.equals(false)))
            .get();
        final currentPurchaseTotal = purchaseAllocationsQuery.fold<int>(0, (sum, a) => sum + a.allocatedAmount);

        if (currentPurchaseTotal + allocatedAmount > purchase.totalAmount) {
          throw AllocationConcurrencyException(
            targetId: purchaseId,
            currentAllocated: currentPurchaseTotal,
            attemptedAllocated: allocatedAmount,
            maxAllowed: purchase.totalAmount,
          );
        }
      }

      // 4. Insert allocation row atomically
      await into(paymentAllocations).insert(
        PaymentAllocationsCompanion.insert(
          id: allocationId,
          companyId: companyId,
          paymentId: paymentId,
          saleId: Value<String?>(saleId),
          purchaseId: Value<String?>(purchaseId),
          allocatedAmount: allocatedAmount,
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
        ),
      );
    });
  }

  /// Atomic Journal Entry Insertion with Net Balance Lock Check.
  /// Enforces SUM(debit) == SUM(credit) before transaction commit.
  Future<void> insertJournalEntryAtomic({
    required JournalEntriesCompanion header,
    required List<JournalEntryLinesCompanion> lines,
  }) async {
    await transaction(() async {
      // 1. Verify net debit == credit
      int totalDebit = 0;
      int totalCredit = 0;

      for (final line in lines) {
        totalDebit += line.debitAmount.value;
        totalCredit += line.creditAmount.value;
      }

      if (totalDebit != totalCredit) {
        throw LedgerImbalanceException(totalDebit, totalCredit);
      }

      // 2. Insert header
      await into(journalEntries).insert(header);

      // 3. Insert lines
      for (final line in lines) {
        await into(journalEntryLines).insert(line);
      }
    });
  }

  /// Derive running account balance from immutable journal entry lines.
  /// Formula: Assets/Expenses/COGS: SUM(debit) - SUM(credit)
  ///          Liabilities/Equity/Revenue: SUM(credit) - SUM(debit)
  Future<int> getDerivedAccountBalance(String accountId) async {
    final account = await (select(accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null) return 0;

    final lines = await (select(journalEntryLines)..where((l) => l.accountId.equals(accountId))).get();

    int totalDebit = 0;
    int totalCredit = 0;

    for (final line in lines) {
      totalDebit += line.debitAmount;
      totalCredit += line.creditAmount;
    }

    final isDebitNormal = ['asset', 'cogs', 'expense'].contains(account.type.toLowerCase());
    return isDebitNormal ? (totalDebit - totalCredit) : (totalCredit - totalDebit);
  }
}
