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

    test(
      'deduplicates concurrent open calls into one database instance',
      () async {
        final results = await Future.wait<Database>(<Future<Database>>[
          dbHelper.database,
          dbHelper.database,
          dbHelper.database,
        ]);

        expect(identical(results[0], results[1]), isTrue);
        expect(identical(results[1], results[2]), isTrue);
      },
    );

    test('enforces SQLite CHECK constraints on sessions and clips', () async {
      final db = await dbHelper.database;
      final nowMs = DateTime(2026, 4, 1).millisecondsSinceEpoch;

      await expectLater(
        db.insert(DatabaseHelper.sessionsTable, <String, Object?>{
          'name': 'Bad Buffer',
          'started_at': nowMs,
          'buffer_seconds': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );

      final sessionId = await db.insert(
        DatabaseHelper.sessionsTable,
        <String, Object?>{
          'name': 'Valid',
          'started_at': nowMs,
          'buffer_seconds': 30,
        },
      );

      await expectLater(
        db.insert(DatabaseHelper.clipsTable, <String, Object?>{
          'session_id': sessionId,
          'name': 'Negative Duration',
          'file_path': '/tmp/x.wav',
          'duration_ms': -1,
          'size_bytes': 100,
          'created_at': nowMs,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
