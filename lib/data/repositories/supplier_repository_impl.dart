import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../domain/accounting/repository/supplier_repository.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final AppDatabase db;

  SupplierRepositoryImpl(this.db);

  @override
  Future<String> create({
    required String companyId,
    required String name,
    required String accountId,
    String? phone,
    String? address,
    String? notes,
    required String deviceId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.into(db.suppliers).insert(
      SuppliersCompanion.insert(
        id: id,
        companyId: companyId,
        name: name,
        accountId: accountId,
        phone: Value<String?>(phone),
        address: Value<String?>(address),
        notes: Value<String?>(notes),
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
      ),
    );

    return id;
  }

  @override
  Future<void> update(
    String id, {
    String? name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (db.update(db.suppliers)..where((s) => s.id.equals(id))).write(
      SuppliersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        phone: phone != null ? Value<String?>(phone) : const Value.absent(),
        address: address != null ? Value<String?>(address) : const Value.absent(),
        notes: notes != null ? Value<String?>(notes) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (db.update(db.suppliers)..where((s) => s.id.equals(id))).write(
      SuppliersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<Supplier?> findById(String id) async {
    return await (db.select(db.suppliers)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<Supplier>> findByCompany(String companyId) async {
    return await (db.select(db.suppliers)..where((s) => s.companyId.equals(companyId))).get();
  }
}
