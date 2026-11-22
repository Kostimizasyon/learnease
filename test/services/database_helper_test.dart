import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('DatabaseHelper', () {
    late DatabaseHelper dbHelper;

    setUp(() {
      dbHelper = DatabaseHelper(
        databaseFactory: databaseFactoryFfi,
        dbPath: inMemoryDatabasePath,
      );
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('creates schema tables and enables foreign keys', () async {
      final db = await dbHelper.database;

      final fkRows = await db.rawQuery('PRAGMA foreign_keys');
      expect(fkRows.single['foreign_keys'], 1);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
      );
      final tableNames = tables.map((r) => r['name']).toSet();
      expect(
        tableNames,
        containsAll(<String>[
          DatabaseHelper.foldersTable,
          DatabaseHelper.sessionsTable,
          DatabaseHelper.clipsTable,
        ]),
      );
    });

    test('reuses open database instance and reopens after close', () async {
      final first = await dbHelper.database;
      final second = await dbHelper.database;
      expect(identical(first, second), isTrue);

      await dbHelper.close();
      final reopened = await dbHelper.database;
      expect(reopened.isOpen, isTrue);
      expect(identical(first, reopened), isFalse);
    });
  });
}
