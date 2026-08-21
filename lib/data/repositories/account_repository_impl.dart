import '../database/app_database.dart';
import '../../domain/accounting/repository/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AppDatabase db;

  AccountRepositoryImpl(this.db);

  @override
  Future<Account?> findById(String id) async {
    return await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<Account>> findByCompany(String companyId) async {
    return await (db.select(db.accounts)..where((a) => a.companyId.equals(companyId))).get();
  }

  @override
  Future<List<Account>> findChildren(String parentId) async {
    return await (db.select(db.accounts)..where((a) => a.parentId.equals(parentId))).get();
  }

  @override
  Future<int> getDerivedBalance(String accountId) async {
    return await db.getDerivedAccountBalance(accountId);
  }
}
