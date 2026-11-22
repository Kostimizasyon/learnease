import '../data_models/folder.dart';
import 'database_helper.dart';

class FolderRepository {
  FolderRepository({required this._databaseHelper});

  final DatabaseHelper _databaseHelper;

  Future<Folder> createFolder(Folder folder) async {
    final db = await _databaseHelper.database;
    final values = folder.toMap()..remove('id');
    final id = await db.insert(DatabaseHelper.foldersTable, values);
    return folder.copyWith(id: id);
  }

  Future<Folder?> getFolder(int id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      DatabaseHelper.foldersTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Folder.fromMap(rows.first);
  }

  /// Lists folders ordered alphabetically (case-insensitive).
  /// When [rootOnly] is true, returns only top-level folders (`parent_id IS NULL`).
  Future<List<Folder>> listFolders({
    int? parentId,
    bool rootOnly = false,
  }) async {
    final db = await _databaseHelper.database;
    String? where;
    List<Object?>? whereArgs;

    if (rootOnly) {
      where = 'parent_id IS NULL';
    } else if (parentId != null) {
      where = 'parent_id = ?';
      whereArgs = <Object?>[parentId];
    }

    final rows = await db.query(
      DatabaseHelper.foldersTable,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(Folder.fromMap).toList(growable: false);
  }

  /// Returns the ancestor chain from root down to [folderId] inclusive.
  Future<List<Folder>> getBreadcrumbs(int folderId) async {
    final chain = <Folder>[];
    final visited = <int>{};
    int? currentId = folderId;

    while (currentId != null && visited.add(currentId)) {
      final folder = await getFolder(currentId);
      if (folder == null) {
        break;
      }
      chain.add(folder);
      currentId = folder.parentId;
    }

    return chain.reversed.toList(growable: false);
  }

  Future<void> renameFolder(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        newName,
        'newName',
        'Folder name cannot be empty.',
      );
    }
    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.foldersTable,
      <String, Object?>{'name': trimmed},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Moves [id] under [newParentId] (or root when null), preventing cycles.
  Future<void> moveFolder(int id, {int? newParentId}) async {
    if (newParentId == id) {
      throw ArgumentError('A folder cannot be moved into itself.');
    }

    if (newParentId != null) {
      final targetAncestors = await getBreadcrumbs(newParentId);
      if (targetAncestors.any((ancestor) => ancestor.id == id)) {
        throw ArgumentError(
          'Cannot move a folder into one of its own descendants.',
        );
      }
    }

    final db = await _databaseHelper.database;
    await db.update(
      DatabaseHelper.foldersTable,
      <String, Object?>{'parent_id': newParentId},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteFolder(int id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      DatabaseHelper.foldersTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
