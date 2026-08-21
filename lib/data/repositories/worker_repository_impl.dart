import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../domain/accounting/repository/worker_repository.dart';

class WorkerRepositoryImpl implements WorkerRepository {
  final AppDatabase db;

  WorkerRepositoryImpl(this.db);

  @override
  Future<String> create({
    required String companyId,
    required String name,
    required String accountId,
    String? phone,
    String? specialty,
    int? dailyRate,
    String? notes,
    required String deviceId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.into(db.workers).insert(
      WorkersCompanion.insert(
        id: id,
        companyId: companyId,
        name: name,
        accountId: accountId,
        phone: Value<String?>(phone),
        specialty: Value<String?>(specialty),
        dailyRate: Value<int?>(dailyRate),
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
    String? specialty,
    int? dailyRate,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (db.update(db.workers)..where((w) => w.id.equals(id))).write(
      WorkersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        phone: phone != null ? Value<String?>(phone) : const Value.absent(),
        specialty: specialty != null ? Value<String?>(specialty) : const Value.absent(),
        dailyRate: dailyRate != null ? Value<int?>(dailyRate) : const Value.absent(),
        notes: notes != null ? Value<String?>(notes) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (db.update(db.workers)..where((w) => w.id.equals(id))).write(
      WorkersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<Worker?> findById(String id) async {
    return await (db.select(db.workers)..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<Worker>> findByCompany(String companyId) async {
    return await (db.select(db.workers)..where((w) => w.companyId.equals(companyId))).get();
  }
}
