import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper({this._databaseFactory, this._dbPath});

  static const String databaseName = 'learnese.db';
  static const int databaseVersion = 1;

  static const String foldersTable = 'folders';
  static const String sessionsTable = 'sessions';
  static const String clipsTable = 'clips';

  final DatabaseFactory? _databaseFactory;
  final String? _dbPath;

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final inFlight = _opening;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _open();
    _opening = future;
    try {
      final opened = await future;
      if (identical(_opening, future)) {
        _database = opened;
      }
      return opened;
    } finally {
      if (identical(_opening, future)) {
        _opening = null;
      }
    }
  }

  Future<Database> _open() async {
    final factory = _databaseFactory ?? databaseFactory;
    final resolvedPath =
        _dbPath ?? p.join(await factory.getDatabasesPath(), databaseName);

    return factory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $foldersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        parent_id INTEGER NULL REFERENCES $foldersTable(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $sessionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NULL,
        buffer_seconds INTEGER NOT NULL CHECK (buffer_seconds BETWEEN 1 AND 180),
        folder_id INTEGER NULL REFERENCES $foldersTable(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $clipsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES $sessionsTable(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        duration_ms INTEGER NOT NULL CHECK (duration_ms >= 0),
        size_bytes INTEGER NOT NULL CHECK (size_bytes >= 0),
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_folders_parent_id ON $foldersTable(parent_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sessions_folder_id ON $sessionsTable(folder_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sessions_started_at ON $sessionsTable(started_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_clips_session_id ON $clipsTable(session_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations go here keyed by oldVersion < targetVersion.
  }

  Future<void> close() async {
    final inFlight = _opening;
    _opening = null;
    if (inFlight != null) {
      try {
        final opened = await inFlight;
        if (opened.isOpen) {
          await opened.close();
        }
      } catch (_) {
        // Ignore open failure when closing.
      }
    }
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
