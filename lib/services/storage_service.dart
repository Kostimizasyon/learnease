import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService({Future<Directory> Function()? rootDirectoryProvider})
    : _rootDirectoryProvider =
          rootDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const String clipsFolderName = 'clips';

  final Future<Directory> Function() _rootDirectoryProvider;

  Future<Directory> getClipsRootDirectory() async {
    final root = await _rootDirectoryProvider();
    final clipsDir = Directory(p.join(root.path, clipsFolderName));
    if (!await clipsDir.exists()) {
      await clipsDir.create(recursive: true);
    }
    return clipsDir;
  }

  Future<Directory> getSessionDirectory(int sessionId) async {
    final clipsRoot = await getClipsRootDirectory();
    final sessionDir = Directory(p.join(clipsRoot.path, 'session_$sessionId'));
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }
    return sessionDir;
  }

  Future<String> nextClipFilePath({
    required int sessionId,
    DateTime? timestamp,
  }) async {
    final dir = await getSessionDirectory(sessionId);
    final ts = (timestamp ?? DateTime.now()).millisecondsSinceEpoch;
    var candidate = p.join(dir.path, 'clip_$ts.wav');
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(dir.path, 'clip_${ts}_$suffix.wav');
      suffix++;
    }
    return candidate;
  }

  Future<bool> fileExists(String filePath) async {
    if (filePath.trim().isEmpty) {
      return false;
    }
    return File(filePath).exists();
  }

  Future<int> fileSizeBytes(String filePath) async {
    if (filePath.trim().isEmpty) {
      return 0;
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return 0;
    }
    return file.length();
  }

  Future<bool> deleteFile(String filePath) async {
    if (filePath.trim().isEmpty) {
      return false;
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }
    try {
      await file.delete();
      return true;
    } on PathNotFoundException {
      return false;
    }
  }

  Future<int> deleteFiles(Iterable<String> filePaths) async {
    var deletedCount = 0;
    for (final path in filePaths) {
      if (await deleteFile(path)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<bool> deleteSessionDirectory(int sessionId) async {
    final clipsRoot = await getClipsRootDirectory();
    final sessionDir = Directory(p.join(clipsRoot.path, 'session_$sessionId'));
    if (!await sessionDir.exists()) {
      return false;
    }
    try {
      await sessionDir.delete(recursive: true);
      return true;
    } on PathNotFoundException {
      return false;
    }
  }

  Future<int> totalClipsStorageBytes() async {
    final clipsRoot = await getClipsRootDirectory();
    var total = 0;
    await for (final entity in clipsRoot.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
