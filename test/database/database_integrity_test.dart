import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:test/test.dart';
import '../../lib/data/database/app_database.dart';
import '../test_database_helper.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.now().millisecondsSinceEpoch;

  setUp(() async {
    db = createTestDatabase();

    await db.into(db.companies).insert(
      CompaniesCompanion.insert(
        id: 'comp_1',
        name: 'Company 1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    await db.into(db.companies).insert(
      CompaniesCompanion.insert(
        id: 'comp_2',
        name: 'Company 2',
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
        email: 'user1@test.com',
        displayName: 'User 1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Integrity & Derived Balance Tests', () {
    test('1. All 28 tables present in schema metadata', () {
      expect(db.allTables.length, equals(28));
    });

    test('2. Derived account balance calculates exact running total from immutable ledger lines', () async {
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc_cash',
          companyId: 'comp_1',
          code: '1110',
          nameAr: 'نقد في الصندوق',
          type: 'asset',
          normalBalance: 'debit',
          createdAt: now,
          updatedAt: now,
          deviceId: 'dev_1',
        ),
      );

      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc_revenue',
          companyId: 'comp_1',
          code: '4100',
          nameAr: 'مبيعات',
          type: 'revenue',
          normalBalance: 'credit',
          createdAt: now,
          updatedAt: now,
          deviceId: 'dev_1',
        ),
      );

      // Entry 1: Sale of 150,000 IQD (DR Cash 150,000 / CR Revenue 150,000)
      final header1 = JournalEntriesCompanion.insert(
        id: 'je_1',
        companyId: 'comp_1',
        entryNumber: 1,
        date: now,
        description: 'Sale 1',
        sourceType: 'sale',
        sourceId: 's1',
        idempotencyKey: 'k1',
        createdBy: 'user_1',
        createdAt: now,
        deviceId: 'dev_1',
      );

      final lines1 = [
        JournalEntryLinesCompanion.insert(
          id: 'jel_1',
          companyId: 'comp_1',
          journalEntryId: 'je_1',
          accountId: 'acc_cash',
          debitAmount: const Value(150000),
          creditAmount: const Value(0),
          createdAt: now,
        ),
        JournalEntryLinesCompanion.insert(
          id: 'jel_2',
          companyId: 'comp_1',
          journalEntryId: 'je_1',
          accountId: 'acc_revenue',
          debitAmount: const Value(0),
          creditAmount: const Value(150000),
          createdAt: now,
        ),
      ];

      await db.insertJournalEntryAtomic(header: header1, lines: lines1);

      // Entry 2: Cash expense of 30,000 IQD (DR Expense 30,000 / CR Cash 30,000)
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc_rent',
          companyId: 'comp_1',
          code: '7100',
          nameAr: 'إيجار',
          type: 'expense',
          normalBalance: 'debit',
          createdAt: now,
          updatedAt: now,
          deviceId: 'dev_1',
        ),
      );

      final header2 = JournalEntriesCompanion.insert(
        id: 'je_2',
        companyId: 'comp_1',
        entryNumber: 2,
        date: now,
        description: 'Rent Expense',
        sourceType: 'expense',
        sourceId: 'exp1',
        idempotencyKey: 'k2',
        createdBy: 'user_1',
        createdAt: now,
        deviceId: 'dev_1',
      );

      final lines2 = [
        JournalEntryLinesCompanion.insert(
          id: 'jel_3',
          companyId: 'comp_1',
          journalEntryId: 'je_2',
          accountId: 'acc_rent',
          debitAmount: const Value(30000),
          creditAmount: const Value(0),
          createdAt: now,
        ),
        JournalEntryLinesCompanion.insert(
          id: 'jel_4',
          companyId: 'comp_1',
          journalEntryId: 'je_2',
          accountId: 'acc_cash',
          debitAmount: const Value(0),
          creditAmount: const Value(30000),
          createdAt: now,
        ),
      ];

      await db.insertJournalEntryAtomic(header: header2, lines: lines2);

      // Verify cash running balance: 150,000 - 30,000 = 120,000 minor units
      final cashBalance = await db.getDerivedAccountBalance('acc_cash');
      expect(cashBalance, equals(120000));

      // Verify revenue running balance: 150,000 minor units
      final revBalance = await db.getDerivedAccountBalance('acc_revenue');
      expect(revBalance, equals(150000));
    });

    test('3. Company Isolation: Data from Comp 1 is completely isolated from Comp 2', () async {
      // Create Account for Comp 1
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc_comp1',
          companyId: 'comp_1',
          code: '1001',
          nameAr: 'حساب شركة 1',
          type: 'asset',
          normalBalance: 'debit',
          createdAt: now,
          updatedAt: now,
          deviceId: 'dev_1',
        ),
      );

      // Create Account for Comp 2
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc_comp2',
          companyId: 'comp_2',
          code: '1001',
          nameAr: 'حساب شركة 2',
          type: 'asset',
          normalBalance: 'debit',
          createdAt: now,
          updatedAt: now,
          deviceId: 'dev_2',
        ),
      );

      final comp1Accounts = await (db.select(db.accounts)..where((a) => a.companyId.equals('comp_1'))).get();
      final comp2Accounts = await (db.select(db.accounts)..where((a) => a.companyId.equals('comp_2'))).get();

      expect(comp1Accounts.length, equals(1));
      expect(comp1Accounts.first.id, equals('acc_comp1'));
      expect(comp2Accounts.length, equals(1));
      expect(comp2Accounts.first.id, equals('acc_comp2'));
    });

    test('4. Idempotency Key Unique Constraint rejects duplicates', () async {
      await db.into(db.journalEntries).insert(
        JournalEntriesCompanion.insert(
          id: 'je_idemp_1',
          companyId: 'comp_1',
          entryNumber: 99,
          date: now,
          description: 'Idempotency test 1',
          sourceType: 'sale',
          sourceId: 's99',
          idempotencyKey: 'unique_key_123',
          createdBy: 'user_1',
          createdAt: now,
          deviceId: 'dev_1',
        ),
      );

      expect(
        () => db.into(db.journalEntries).insert(
          JournalEntriesCompanion.insert(
            id: 'je_idemp_2',
            companyId: 'comp_1',
            entryNumber: 100,
            date: now,
            description: 'Duplicate idempotency key',
            sourceType: 'sale',
            sourceId: 's100',
            idempotencyKey: 'unique_key_123',
            createdBy: 'user_1',
            createdAt: now,
            deviceId: 'dev_1',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
