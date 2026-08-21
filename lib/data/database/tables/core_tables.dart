import 'package:drift/drift.dart';

/// Table 01: companies
@DataClassName('Company')
class Companies extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get name => text().unique()();
  TextColumn get fiscalYearStart => text().withDefault(const Constant('01-01'))();
  TextColumn get fiscalYearEnd => text().withDefault(const Constant('12-31'))();
  TextColumn get currency => text().withDefault(const Constant('IQD'))();
  TextColumn get numberFormat => text().withDefault(const Constant('western'))();
  TextColumn get settingsJson => text().nullable()();

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

/// Table 03: roles (Defined before Users)
@DataClassName('Role')
class Roles extends Table {
  TextColumn get id => text()(); // UUID v4 PK
  TextColumn get companyId => text()();
  TextColumn get name => text()();
  TextColumn get permissionsJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

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

/// Table 02: users
@DataClassName('UserData')
class Users extends Table {
  TextColumn get id => text()(); // Matches Supabase Auth UID
  TextColumn get companyId => text()();
  TextColumn get roleId => text()();
  TextColumn get email => text().unique()();
  TextColumn get displayName => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

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
