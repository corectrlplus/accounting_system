import 'package:drift/drift.dart';

/// Table 04: accounts
@DataClassName('Account')
class Accounts extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get code => text()();
  TextColumn get nameAr => text()();
  TextColumn get nameEn => text().nullable()();
  TextColumn get type => text()(); // asset, liability, equity, revenue, cogs, expense
  TextColumn get normalBalance => text()(); // debit, credit
  TextColumn get parentId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get linkedEntityType => text().nullable()(); // customer, supplier, worker
  TextColumn get linkedEntityId => text().nullable()();

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

/// Table 05: journal_entries
@DataClassName('JournalEntryData')
class JournalEntries extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  IntColumn get entryNumber => integer()();
  IntColumn get date => integer()(); // Unix ms timestamp
  TextColumn get description => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get sourceType => text()(); // sale, purchase, customer_payment, etc.
  TextColumn get sourceId => text()();
  BoolColumn get isReversal => boolean().withDefault(const Constant(false))();
  TextColumn get reversedEntryId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('posted'))(); // posted, reversed
  TextColumn get currencyCode => text().withDefault(const Constant('IQD'))();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get createdBy => text()();

  // Immutable ledger sync fields (NO updated_at, NO version, NO is_deleted)
  IntColumn get createdAt => integer()();
  TextColumn get deviceId => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table 06: journal_entry_lines
@DataClassName('JournalEntryLineData')
class JournalEntryLines extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get journalEntryId => text()();
  TextColumn get accountId => text()();
  IntColumn get debitAmount => integer().withDefault(const Constant(0))(); // Int64 minor units (x1000)
  IntColumn get creditAmount => integer().withDefault(const Constant(0))(); // Int64 minor units (x1000)
  TextColumn get description => text().nullable()();

  // Immutable ledger line sync fields (NO updated_at, NO version, NO is_deleted)
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
