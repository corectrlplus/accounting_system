import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';
import '../../lib/data/database/app_database.dart';
import '../test_database_helper.dart';
import '../../lib/data/repositories/journal_entry_repository_impl.dart';
import '../../lib/domain/accounting/models/transaction_context.dart';
import '../../lib/domain/accounting/models/accounting_error.dart';
import '../../lib/domain/accounting/builder/journal_entry_builder.dart';
import '../../lib/core/money/money.dart';

void main() {
  late AppDatabase db;
  late JournalEntryRepositoryImpl repo;
  late TransactionContext ctxComp1;
  late TransactionContext ctxComp2;
  final now = DateTime.now().millisecondsSinceEpoch;

  setUp(() async {
    db = createTestDatabase();
    repo = JournalEntryRepositoryImpl(db);

    ctxComp1 = TransactionContext(
      companyId: 'comp_1',
      userId: 'user_1',
      deviceId: 'dev_1',
      timestampMs: now,
    );

    ctxComp2 = TransactionContext(
      companyId: 'comp_2',
      userId: 'user_2',
      deviceId: 'dev_2',
      timestampMs: now,
    );

    // Seed Companies
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

    // Seed Accounts for Company 1
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc_cash_1',
        companyId: 'comp_1',
        code: '1110',
        nameAr: 'نقد الصندوق',
        type: 'asset',
        normalBalance: 'debit',
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc_sales_1',
        companyId: 'comp_1',
        code: '4100',
        nameAr: 'مبيعات',
        type: 'revenue',
        normalBalance: 'credit',
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    // Seed Inactive Account for Company 1
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc_inactive_1',
        companyId: 'comp_1',
        code: '9999',
        nameAr: 'حساب معطل',
        type: 'asset',
        normalBalance: 'debit',
        isActive: const Value(false),
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    // Seed Account for Company 2
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc_cash_2',
        companyId: 'comp_2',
        code: '1110',
        nameAr: 'نقد شركة 2',
        type: 'asset',
        normalBalance: 'debit',
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_2',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Journal Entry Persistence & Integration Tests (Step 2)', () {
    test('13. Nonexistent account rejected', () async {
      final draftRes = JournalEntryBuilder()
          .setContext(ctxComp1)
          .setSource(sourceType: 'sale', sourceId: 'sale_nonexistent')
          .setDescription('Test sale')
          .addDebit(accountId: 'acc_ghost', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_1', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      final result = await repo.persistJournalEntry(draft: draftRes.value, context: ctxComp1);
      expect(result.isFailure, isTrue);
      expect(result.error, isA<ValidationError>());
      final err = result.error as ValidationError;
      expect(err.fieldName, equals('accountId'));
    });

    test('14. Inactive account rejected', () async {
      final draftRes = JournalEntryBuilder()
          .setContext(ctxComp1)
          .setSource(sourceType: 'sale', sourceId: 'sale_inactive')
          .setDescription('Test sale with inactive account')
          .addDebit(accountId: 'acc_inactive_1', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_1', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      final result = await repo.persistJournalEntry(draft: draftRes.value, context: ctxComp1);
      expect(result.isFailure, isTrue);
      expect(result.error, isA<ValidationError>());
      final err = result.error as ValidationError;
      expect(err.message, contains('inactive'));
    });

    test('15. Cross-company account rejected', () async {
      // 1. Trying to reference acc_cash_2 (Company 2) inside Company 1 context
      final draftRes1 = JournalEntryBuilder()
          .setContext(ctxComp1)
          .setSource(sourceType: 'sale', sourceId: 'sale_cross_comp_1')
          .setDescription('Cross company test 1')
          .addDebit(accountId: 'acc_cash_2', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_1', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      final result1 = await repo.persistJournalEntry(draft: draftRes1.value, context: ctxComp1);
      expect(result1.isFailure, isTrue);
      expect(result1.error, isA<CompanyMismatchError>());

      // 2. Trying to submit Company 1 draft inside Company 2 context
      final draftRes2 = JournalEntryBuilder()
          .setContext(ctxComp1)
          .setSource(sourceType: 'sale', sourceId: 'sale_cross_comp_2')
          .setDescription('Cross company test 2')
          .addDebit(accountId: 'acc_cash_1', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_1', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      final result2 = await repo.persistJournalEntry(draft: draftRes2.value, context: ctxComp2);
      expect(result2.isFailure, isTrue);
      expect(result2.error, isA<CompanyMismatchError>());
    });

    test('16. Successful journal persists atomically', () async {
      final draftRes = JournalEntryBuilder()
          .setContext(ctxComp1)
          .setSource(sourceType: 'sale', sourceId: 'sale_valid')
          .setDescription('Valid cash sale')
          .addDebit(accountId: 'acc_cash_1', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_1', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      final result = await repo.persistJournalEntry(draft: draftRes.value, context: ctxComp1);
      expect(result.isSuccess, isTrue);

      final entryHeader = await (db.select(db.journalEntries)..where((j) => j.id.equals(draftRes.value.id))).getSingleOrNull();
      final entryLines = await (db.select(db.journalEntryLines)..where((l) => l.journalEntryId.equals(draftRes.value.id))).get();

      expect(entryHeader, isNotNull);
      expect(entryHeader!.sourceId, equals('sale_valid'));
      expect(entryLines.length, equals(2));
    });

    test('17 & 18. Failed journal persistence leaves no header and no lines (Atomic Rollback)', () async {
      final draftRes = JournalEntryBuilder()
          .setContext(ctxComp1)
          .setSource(sourceType: 'sale', sourceId: 'sale_failed_acc')
          .setDescription('Will fail account validation')
          .addDebit(accountId: 'acc_ghost', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_1', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      final initialHeaderCount = (await db.select(db.journalEntries).get()).length;
      final initialLineCount = (await db.select(db.journalEntryLines).get()).length;

      final result = await repo.persistJournalEntry(draft: draftRes.value, context: ctxComp1);
      expect(result.isFailure, isTrue);

      final finalHeaderCount = (await db.select(db.journalEntries).get()).length;
      final finalLineCount = (await db.select(db.journalEntryLines).get()).length;

      expect(finalHeaderCount, equals(initialHeaderCount));
      expect(finalLineCount, equals(initialLineCount));
    });

    test('19. Duplicate idempotency key rejects second persistence without duplicate rows', () async {
      final draftRes = JournalEntryBuilder()
          .setContext(ctxComp1)
          .setSource(sourceType: 'sale', sourceId: 'sale_idemp_repeat')
          .setDescription('First idempotency submit')
          .addDebit(accountId: 'acc_cash_1', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_1', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      // Submit 1st time
      final result1 = await repo.persistJournalEntry(draft: draftRes.value, context: ctxComp1);
      expect(result1.isSuccess, isTrue);

      final countAfterFirst = (await db.select(db.journalEntries).get()).length;

      // Submit 2nd time with exact same draft (same idempotency key)
      final result2 = await repo.persistJournalEntry(draft: draftRes.value, context: ctxComp1);
      expect(result2.isFailure, isTrue);
      expect(result2.error, isA<IdempotencyError>());

      final countAfterSecond = (await db.select(db.journalEntries).get()).length;
      expect(countAfterSecond, equals(countAfterFirst));
    });

    test('20. Posted journal entry lines are created with immutable status', () async {
      final draftRes = JournalEntryBuilder()
          .setContext(ctxComp1)
          .setSource(sourceType: 'sale', sourceId: 'sale_posted_immut')
          .setDescription('Immutability check')
          .addDebit(accountId: 'acc_cash_1', amount: Money.fromMinor(100000, 'IQD'))
          .addCredit(accountId: 'acc_sales_1', amount: Money.fromMinor(100000, 'IQD'))
          .build();

      final result = await repo.persistJournalEntry(draft: draftRes.value, context: ctxComp1);
      expect(result.isSuccess, isTrue);

      final entry = await (db.select(db.journalEntries)..where((j) => j.id.equals(draftRes.value.id))).getSingle();
      expect(entry.status, equals('posted'));
    });
  });
}
