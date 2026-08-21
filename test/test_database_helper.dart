import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:accounting_system/data/database/app_database.dart';

/// Creates an in-memory database for testing.
/// Only imported in test code, never in app code.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
