import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';
import '../../lib/data/database/app_database.dart';
import '../test_database_helper.dart';
import '../../lib/core/errors/database_exception.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();

    final now = DateTime.now().millisecondsSinceEpoch;

    // Seed company & user & accounts
    await db.into(db.companies).insert(
      CompaniesCompanion.insert(
        id: 'comp_1',
        name: 'Company 1',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
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
        id: 'acc_cash',
        companyId: 'comp_1',
        code: '1110',
        nameAr: 'نقد',
        type: 'asset',
        normalBalance: 'debit',
        createdAt: now,
        updatedAt: now,
        deviceId: 'dev_1',
      ),
    );

    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'acc_sales',
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
  });

  tearDown(() async {
    await db.close();
  });

  group('Journal Balance Atomicity & Ledger Immutability Tests', () {
    test('1. Insert balanced journal entry succeeds', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final header = JournalEntriesCompanion.insert(
        id: 'je_1',
        companyId: 'comp_1',
        entryNumber: 1,
        date: now,
        description: 'Test balanced sale',
        sourceType: 'sale',
        sourceId: 'sale_1',
        idempotencyKey: 'key_1',
        createdBy: 'user_1',
        createdAt: now,
        deviceId: 'dev_1',
      );

      final lines = [
        JournalEntryLinesCompanion.insert(
          id: 'jel_1',
          companyId: 'comp_1',
          journalEntryId: 'je_1',
          accountId: 'acc_cash',
          debitAmount: const Value(100000),
          creditAmount: const Value(0),
          createdAt: now,
        ),
        JournalEntryLinesCompanion.insert(
          id: 'jel_2',
          companyId: 'comp_1',
          journalEntryId: 'je_1',
          accountId: 'acc_sales',
          debitAmount: const Value(0),
          creditAmount: const Value(100000),
          createdAt: now,
        ),
      ];

      await db.insertJournalEntryAtomic(header: header, lines: lines);

      final inserted = await (db.select(db.journalEntries)..where((e) => e.id.equals('je_1'))).getSingleOrNull();
      expect(inserted, isNotNull);
      expect(inserted!.entryNumber, equals(1));
    });

    test('2. Insert unbalanced journal entry throws LedgerImbalanceException and rolls back', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final header = JournalEntriesCompanion.insert(
        id: 'je_unbalanced',
        companyId: 'comp_1',
        entryNumber: 2,
        date: now,
        description: 'Test unbalanced sale',
        sourceType: 'sale',
        sourceId: 'sale_2',
        idempotencyKey: 'key_unbalanced',
        createdBy: 'user_1',
        createdAt: now,
        deviceId: 'dev_1',
      );

      final lines = [
        JournalEntryLinesCompanion.insert(
          id: 'jel_3',
          companyId: 'comp_1',
          journalEntryId: 'je_unbalanced',
          accountId: 'acc_cash',
          debitAmount: const Value(100000),
          creditAmount: const Value(0),
          createdAt: now,
        ),
        JournalEntryLinesCompanion.insert(
          id: 'jel_4',
          companyId: 'comp_1',
          journalEntryId: 'je_unbalanced',
          accountId: 'acc_sales',
          debitAmount: const Value(0),
          creditAmount: const Value(80000),
          createdAt: now,
        ),
      ];

      expect(
        () => db.insertJournalEntryAtomic(header: header, lines: lines),
        throwsA(isA<LedgerImbalanceException>()),
      );

      final insertedHeader = await (db.select(db.journalEntries)..where((e) => e.id.equals('je_unbalanced'))).getSingleOrNull();
      expect(insertedHeader, isNull);
    });

    test('3. Reversal model: Posted entry can be marked reversed and linked to reversal entry', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Original entry
      await db.insertJournalEntryAtomic(
        header: JournalEntriesCompanion.insert(
          id: 'je_orig',
          companyId: 'comp_1',
          entryNumber: 10,
          date: now,
          description: 'Original sale',
          sourceType: 'sale',
          sourceId: 'sale_10',
          idempotencyKey: 'key_orig',
          createdBy: 'user_1',
          createdAt: now,
          deviceId: 'dev_1',
        ),
        lines: [
          JournalEntryLinesCompanion.insert(
            id: 'jel_orig_1',
            companyId: 'comp_1',
            journalEntryId: 'je_orig',
            accountId: 'acc_cash',
            debitAmount: const Value(50000),
            creditAmount: const Value(0),
            createdAt: now,
          ),
          JournalEntryLinesCompanion.insert(
            id: 'jel_orig_2',
            companyId: 'comp_1',
            journalEntryId: 'je_orig',
            accountId: 'acc_sales',
            debitAmount: const Value(0),
            creditAmount: const Value(50000),
            createdAt: now,
          ),
        ],
      );

      // Reversal entry (inverted debits & credits)
      await db.insertJournalEntryAtomic(
        header: JournalEntriesCompanion.insert(
          id: 'je_rev',
          companyId: 'comp_1',
          entryNumber: 11,
          date: now,
          description: 'Reversal of sale_10',
          sourceType: 'reversal',
          sourceId: 'je_orig',
          isReversal: const Value(true),
          reversedEntryId: const Value<String?>('je_orig'),
          idempotencyKey: 'key_rev',
          createdBy: 'user_1',
          createdAt: now,
          deviceId: 'dev_1',
        ),
        lines: [
          JournalEntryLinesCompanion.insert(
            id: 'jel_rev_1',
            companyId: 'comp_1',
            journalEntryId: 'je_rev',
            accountId: 'acc_cash',
            debitAmount: const Value(0),
            creditAmount: const Value(50000),
            createdAt: now,
          ),
          JournalEntryLinesCompanion.insert(
            id: 'jel_rev_2',
            companyId: 'comp_1',
            journalEntryId: 'je_rev',
            accountId: 'acc_sales',
            debitAmount: const Value(50000),
            creditAmount: const Value(0),
            createdAt: now,
          ),
        ],
      );

      // Mark original entry status as reversed
      await (db.update(db.journalEntries)..where((e) => e.id.equals('je_orig'))).write(
        const JournalEntriesCompanion(status: Value('reversed')),
      );

      final orig = await (db.select(db.journalEntries)..where((e) => e.id.equals('je_orig'))).getSingle();
      final rev = await (db.select(db.journalEntries)..where((e) => e.id.equals('je_rev'))).getSingle();

      expect(orig.status, equals('reversed'));
      expect(rev.isReversal, isTrue);
      expect(rev.reversedEntryId, equals('je_orig'));

      // Verify net account balance after reversal is exactly 0
      final cashBalance = await db.getDerivedAccountBalance('acc_cash');
      expect(cashBalance, equals(0));
    });
  });
}
