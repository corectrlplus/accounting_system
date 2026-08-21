abstract class CustomerRepository {
  Future<String> create({
    required String companyId,
    required String name,
    required String accountId,
    String? phone,
    String? address,
    String? notes,
    required String deviceId,
  });
  Future<void> update(String id, {String? name, String? phone, String? address, String? notes});
  Future<void> softDelete(String id);
  Future<dynamic> findById(String id);
  Future<List<dynamic>> findByCompany(String companyId);
}
