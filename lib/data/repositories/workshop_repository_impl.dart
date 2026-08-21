import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../domain/accounting/repository/workshop_repository.dart';

class WorkshopRepositoryImpl implements WorkshopRepository {
  final AppDatabase db;

  WorkshopRepositoryImpl(this.db);

  @override
  Future<String> create({
    required String companyId,
    required String name,
    bool isOwnWorkshop = true,
    String? address,
    String? notes,
    required String deviceId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.into(db.workshops).insert(
      WorkshopsCompanion.insert(
        id: id,
        companyId: companyId,
        name: name,
        isOwnWorkshop: Value(isOwnWorkshop),
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
    bool? isOwnWorkshop,
    String? address,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (db.update(db.workshops)..where((w) => w.id.equals(id))).write(
      WorkshopsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        isOwnWorkshop: isOwnWorkshop != null ? Value(isOwnWorkshop) : const Value.absent(),
        address: address != null ? Value<String?>(address) : const Value.absent(),
        notes: notes != null ? Value<String?>(notes) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (db.update(db.workshops)..where((w) => w.id.equals(id))).write(
      WorkshopsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<Workshop?> findById(String id) async {
    return await (db.select(db.workshops)..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<Workshop>> findByCompany(String companyId) async {
    return await (db.select(db.workshops)..where((w) => w.companyId.equals(companyId))).get();
  }
}
