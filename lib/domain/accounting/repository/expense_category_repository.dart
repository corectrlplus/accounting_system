abstract class ExpenseCategoryRepository {
  Future<String> create({
    required String companyId,
    required String nameAr,
    String? nameEn,
    required String group,
    required String accountId,
    required String deviceId,
  });
  Future<void> softDelete(String id);
  Future<dynamic> findById(String id);
  Future<List<dynamic>> findByCompany(String companyId);
}
