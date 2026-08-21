abstract class WorkerRepository {
  Future<String> create({
    required String companyId,
    required String name,
    required String accountId,
    String? phone,
    String? specialty,
    int? dailyRate,
    String? notes,
    required String deviceId,
  });
  Future<void> update(String id, {String? name, String? phone, String? specialty, int? dailyRate, String? notes});
  Future<void> softDelete(String id);
  Future<dynamic> findById(String id);
  Future<List<dynamic>> findByCompany(String companyId);
}
