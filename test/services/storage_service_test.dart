import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/services/storage_service.dart';

void main() {
  group('StorageService', () {
    late Directory tempRoot;
    late StorageService storage;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp(
        'learnese_storage_test_',
      );
      storage = StorageService(rootDirectoryProvider: () async => tempRoot);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('generates unique .wav clip paths and reports file sizes', () async {
      final ts = DateTime(2026, 5, 1, 9, 0);
      final firstPath = await storage.nextClipFilePath(
        sessionId: 3,
        timestamp: ts,
      );
      expect(firstPath.endsWith('.wav'), isTrue);
      await File(firstPath).writeAsBytes(List<int>.filled(128, 7));

      final secondPath = await storage.nextClipFilePath(
        sessionId: 3,
        timestamp: ts,
      );
      expect(secondPath, isNot(firstPath));
      await File(secondPath).writeAsBytes(List<int>.filled(64, 9));

      expect(await storage.fileExists(firstPath), isTrue);
      expect(await storage.fileSizeBytes(firstPath), 128);
      expect(await storage.totalClipsStorageBytes(), 192);
    });

    test(
      'deletes single files, missing files, and session directories safely',
      () async {
        final path = await storage.nextClipFilePath(sessionId: 8);
        await File(path).writeAsBytes(<int>[1, 2, 3]);

        expect(await storage.deleteFile(path), isTrue);
        expect(await storage.deleteFile(path), isFalse);
        expect(await storage.fileExists(path), isFalse);
        expect(await storage.fileSizeBytes(path), 0);

        final path2 = await storage.nextClipFilePath(sessionId: 8);
        await File(path2).writeAsBytes(<int>[4, 5]);
        expect(await storage.deleteSessionDirectory(8), isTrue);
        expect(await storage.deleteSessionDirectory(8), isFalse);
        expect(await storage.totalClipsStorageBytes(), 0);
      },
    );
  });
}
