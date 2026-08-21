import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../domain/accounting/repository/expense_category_repository.dart';

class ExpenseCategoryRepositoryImpl implements ExpenseCategoryRepository {
  final AppDatabase db;

  ExpenseCategoryRepositoryImpl(this.db);

  @override
  Future<String> create({
    required String companyId,
    required String nameAr,
    String? nameEn,
    required String group,
    required String accountId,
    required String deviceId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.into(db.expenseCategories).insert(
      ExpenseCategoriesCompanion.insert(
        id: id,
        companyId: companyId,
        nameAr: nameAr,
        nameEn: Value<String?>(nameEn),
        group: group,
        accountId: accountId,
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
      ),
    );

    return id;
  }

  @override
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (db.update(db.expenseCategories)..where((c) => c.id.equals(id))).write(
      ExpenseCategoriesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<ExpenseCategory?> findById(String id) async {
    return await (db.select(db.expenseCategories)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<ExpenseCategory>> findByCompany(String companyId) async {
    return await (db.select(db.expenseCategories)..where((c) => c.companyId.equals(companyId))).get();
  }
}
