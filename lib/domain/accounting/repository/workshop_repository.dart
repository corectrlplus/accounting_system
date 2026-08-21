abstract class WorkshopRepository {
  Future<String> create({
    required String companyId,
    required String name,
    bool isOwnWorkshop = true,
    String? address,
    String? notes,
    required String deviceId,
  });
  Future<void> update(String id, {String? name, bool? isOwnWorkshop, String? address, String? notes});
  Future<void> softDelete(String id);
  Future<dynamic> findById(String id);
  Future<List<dynamic>> findByCompany(String companyId);
}
