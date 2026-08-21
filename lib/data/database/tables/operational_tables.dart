import 'package:drift/drift.dart';

/// Table 23: production_records
@DataClassName('ProductionRecordData')
class ProductionRecords extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get workerId => text()();
  TextColumn get manufacturingJobId => text().nullable()();
  TextColumn get workType => text()();
  IntColumn get quantity => integer()();
  IntColumn get productionDate => integer()(); // Unix ms timestamp
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();

  // Sync foundation fields
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
