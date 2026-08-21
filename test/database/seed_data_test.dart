import 'package:test/test.dart';
import 'package:accounting_system/data/database/app_database.dart';
import '../test_database_helper.dart';
import 'package:accounting_system/data/database/seed/initial_seed_data.dart';

void main() {
  group('Seed Data Tests', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Seed Company Defaults inserts 38 accounts, 7 expense categories, and 5 roles', () async {
      const companyId = 'comp_test_seed_101';
      const deviceId = 'dev_win_001';

      await db.seedCompanyDefaults(companyId, deviceId);

      final accountsCount = await db.select(db.accounts).get();
      final categoriesCount = await db.select(db.expenseCategories).get();
      final rolesCount = await db.select(db.roles).get();

      expect(accountsCount.length, equals(InitialSeedData.chartOfAccounts.length));
      expect(categoriesCount.length, equals(InitialSeedData.expenseCategories.length));
      expect(rolesCount.length, equals(InitialSeedData.roles.length));
      expect(accountsCount.length, equals(38));
      expect(categoriesCount.length, equals(7));
      expect(rolesCount.length, equals(5));
    });

    test('2. COA Hierarchy Parent-Child Links are correctly wired', () async {
      const companyId = 'comp_test_seed_102';
      const deviceId = 'dev_win_001';

      await db.seedCompanyDefaults(companyId, deviceId);

      // Verify CASH (1110) parent is CURRENT_ASSET (1100)
      final cashAccount = await (db.select(db.accounts)..where((a) => a.code.equals('1110'))).getSingle();
      final parentAccount = await (db.select(db.accounts)..where((a) => a.code.equals('1100'))).getSingle();

      expect(cashAccount.parentId, equals(parentAccount.id));
    });
  });
}
