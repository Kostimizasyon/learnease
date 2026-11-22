import '../data_models/audio_clip.dart';
import '../data_models/recording_session.dart';
import 'database_helper.dart';
import 'storage_service.dart';

class SessionRepository {
  SessionRepository({required this._databaseHelper, this._storageService});

  final DatabaseHelper _databaseHelper;
  final StorageService? _storageService;

  Future<RecordingSession> createSession(RecordingSession session) async {
    final db = await _databaseHelper.database;
    final values = session.toMap()..remove('id');
    final id = await db.insert(DatabaseHelper.sessionsTable, values);
    return session.copyWith(id: id);
  }

  Future<RecordingSession?> getSession(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.sessionsTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return RecordingSession.fromMap(rows.first);
  }

  Future<RecordingSession?> getActiveSession() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.sessionsTable,
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return RecordingSession.fromMap(rows.first);
  }

  /// Lists sessions ordered newest-first.
  /// When [rootOnly] is true, returns only sessions with `folder_id IS NULL`.
  Future<List<RecordingSession>> listSessions({
    int? folderId,
    bool rootOnly = false,
  }) async {
    if (rootOnly && folderId != null) {
      throw ArgumentError(
        'Cannot specify both rootOnly: true and a non-null folderId.',
      );
    }
    final db = await _databaseHelper.database;
    String? where;
    List<Object?>? whereArgs;

    if (rootOnly) {
      where = 'folder_id IS NULL';
    } else if (folderId != null) {
      where = 'folder_id = ?';
      whereArgs = <Object?>[folderId];
    }

    final rows = await db.query(
      DatabaseHelper.sessionsTable,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'started_at DESC, id DESC',
    );
    return rows.map(RecordingSession.fromMap).toList(growable: false);
  }

  Future<void> renameSession(int id, String newName) async {
    final trimmed = _requireNonEmptyName(newName, 'newName');
    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.sessionsTable,
      <String, Object?>{'name': trimmed},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> moveSession(int id, {int? folderId}) async {
    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.sessionsTable,
      <String, Object?>{'folder_id': folderId},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> endSession(int id, {DateTime? endedAt}) async {
    final resolvedEnd = (endedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.sessionsTable,
      <String, Object?>{'ended_at': resolvedEnd},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteSession(int id) async {
    final clips = await listClipsForSession(id);
    final db = await _databaseHelper.database;
    await db.delete(
      DatabaseHelper.sessionsTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (_storageService != null) {
      await _storageService.deleteFiles(clips.map((c) => c.filePath));
      await _storageService.deleteSessionDirectory(id);
    }
  }

  Future<AudioClip> addClip(AudioClip clip) async {
    final db = await _databaseHelper.database;
    final values = clip.toMap()..remove('id');
    final id = await db.insert(DatabaseHelper.clipsTable, values);
    return clip.copyWith(id: id);
  }

  Future<AudioClip?> getClip(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.clipsTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AudioClip.fromMap(rows.first);
  }

  Future<List<AudioClip>> listClipsForSession(
    int sessionId, {
    bool newestFirst = false,
  }) async {
    final db = await _databaseHelper.database;
    final order = newestFirst
        ? 'created_at DESC, id DESC'
        : 'created_at ASC, id ASC';
    final rows = await db.query(
      DatabaseHelper.clipsTable,
      where: 'session_id = ?',
      whereArgs: <Object?>[sessionId],
      orderBy: order,
    );
    return rows.map(AudioClip.fromMap).toList(growable: false);
  }

  Future<int> countClipsForSession(int sessionId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DatabaseHelper.clipsTable} '
      'WHERE session_id = ?',
      <Object?>[sessionId],
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> renameClip(int id, String newName) async {
    final trimmed = _requireNonEmptyName(newName, 'newName');
    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.clipsTable,
      <String, Object?>{'name': trimmed},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteClip(int id) async {
    final clip = await getClip(id);
    if (clip == null) {
      return;
    }
    final db = await _databaseHelper.database;
    await db.delete(
      DatabaseHelper.clipsTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (_storageService != null) {
      await _storageService.deleteFile(clip.filePath);
    }
  }

  String _requireNonEmptyName(String raw, String paramName) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(raw, paramName, 'Name cannot be empty.');
    }
    return trimmed;
  }
}
