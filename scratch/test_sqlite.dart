import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.openInMemory();
  db.execute('CREATE TABLE IF NOT EXISTS "companies" ("id" TEXT NOT NULL PRIMARY KEY);');

  try {
    db.execute('CREATE TABLE IF NOT EXISTS "roles" ("id" TEXT NOT NULL PRIMARY KEY, "company_id" TEXT REFERENCES companies(id) NOT NULL);');
    print('REFERENCES companies(id) NOT NULL SUCCESS!');
  } catch (e) {
    print('FAILED: $e');
  }
}
