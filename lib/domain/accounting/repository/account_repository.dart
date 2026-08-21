abstract class AccountRepository {
  Future<dynamic> findById(String id);
  Future<List<dynamic>> findByCompany(String companyId);
  Future<List<dynamic>> findChildren(String parentId);
  Future<int> getDerivedBalance(String accountId);
}
