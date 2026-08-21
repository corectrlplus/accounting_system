import 'package:drift/drift.dart';

/// Table 24: audit_logs
@DataClassName('AuditLogData')
class AuditLogs extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()(); // create, reverse, allocate, deallocate, update, soft_delete
  TextColumn get fieldName => text().nullable()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  IntColumn get timestamp => integer()(); // Unix ms timestamp
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 25: devices
@DataClassName('DeviceData')
class Devices extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get userId => text()();
  TextColumn get deviceName => text()();
  TextColumn get platform => text()(); // windows, android, ios
  IntColumn get lastSeenAt => integer()();
  TextColumn get pushToken => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 26: sync_outbox (Local SQLite Queue)
@DataClassName('SyncOutboxData')
class SyncOutbox extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get targetTableName => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // insert, update, delete
  TextColumn get payloadJson => text().nullable()();
  TextColumn get idempotencyKey => text().unique()();
  IntColumn get createdAt => integer()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, sent, acknowledged, failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get deviceId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 27: sync_metadata (Local SQLite Watermark Tracking)
@DataClassName('SyncMetadataData')
class SyncMetadata extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get deviceId => text()();
  TextColumn get targetTableName => text().named('table_name')();
  IntColumn get lastSyncedAt => integer().nullable()();
  IntColumn get lastSyncVersion => integer().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('idle'))(); // idle, syncing, error
  TextColumn get errorMessage => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 28: shared_statements
@DataClassName('SharedStatementData')
class SharedStatements extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get entityType => text()(); // customer, supplier
  TextColumn get entityId => text()();
  TextColumn get accessTokenHash => text()();
  IntColumn get expiresAt => integer()();
  BoolColumn get isRevoked => boolean().withDefault(const Constant(false))();
  TextColumn get createdBy => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
