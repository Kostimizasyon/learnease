import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/audio_clip.dart';
import 'package:learnese/data_models/folder.dart';
import 'package:learnese/data_models/recording_session.dart';
import 'package:learnese/services/database_helper.dart';
import 'package:learnese/services/folder_repository.dart';
import 'package:learnese/services/session_repository.dart';
import 'package:learnese/services/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('SessionRepository', () {
    late Directory tempRoot;
    late DatabaseHelper dbHelper;
    late StorageService storageService;
    late SessionRepository sessionRepo;
    late FolderRepository folderRepo;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp(
        'learnese_session_test_',
      );
      dbHelper = DatabaseHelper(
        databaseFactory: databaseFactoryFfi,
        dbPath: inMemoryDatabasePath,
      );
      storageService = StorageService(
        rootDirectoryProvider: () async => tempRoot,
      );
      sessionRepo = SessionRepository(
        databaseHelper: dbHelper,
        storageService: storageService,
      );
      folderRepo = FolderRepository(databaseHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test(
      'creates, reads, lists newest-first, renames, moves, and ends sessions',
      () async {
        final t1 = DateTime(2026, 4, 1, 10, 0);
        final t2 = DateTime(2026, 4, 1, 11, 0);
        final folder = await folderRepo.createFolder(
          Folder.root(name: 'Study'),
        );

        final s1 = await sessionRepo.createSession(
          RecordingSession.create(bufferSeconds: 30, startedAt: t1),
        );
        final s2 = await sessionRepo.createSession(
          RecordingSession.create(bufferSeconds: 60, startedAt: t2),
        );

        expect(s1.id, isNotNull);
        expect(s2.id, isNotNull);

        final active = await sessionRepo.getActiveSession();
        expect(active?.id, s2.id);

        final all = await sessionRepo.listSessions();
        expect(all.map((s) => s.id), <int?>[s2.id, s1.id]);

        await sessionRepo.renameSession(s1.id!, 'Morning News');
        await sessionRepo.moveSession(s1.id!, folderId: folder.id);
        await sessionRepo.endSession(
          s2.id!,
          endedAt: DateTime(2026, 4, 1, 11, 15),
        );

        final updatedS1 = await sessionRepo.getSession(s1.id!);
        expect(updatedS1?.name, 'Morning News');
        expect(updatedS1?.folderId, folder.id);

        final inFolder = await sessionRepo.listSessions(folderId: folder.id);
        expect(inFolder.map((s) => s.id), <int?>[s1.id]);

        final rootOnly = await sessionRepo.listSessions(rootOnly: true);
        expect(rootOnly.map((s) => s.id), <int?>[s2.id]);

        final endedS2 = await sessionRepo.getSession(s2.id!);
        expect(endedS2?.isActive, isFalse);

        await sessionRepo.moveSession(s1.id!, folderId: null);
        final movedBack = await sessionRepo.getSession(s1.id!);
        expect(movedBack?.folderId, isNull);
      },
    );

    test('rejects blank session or clip names', () async {
      final session = await sessionRepo.createSession(
        RecordingSession.create(bufferSeconds: 15),
      );
      await expectLater(
        sessionRepo.renameSession(session.id!, '   '),
        throwsArgumentError,
      );

      final clip = await sessionRepo.addClip(
        AudioClip.create(
          sessionId: session.id!,
          filePath: '/tmp/a.wav',
          durationMs: 1000,
          sizeBytes: 2048,
        ),
      );
      await expectLater(
        sessionRepo.renameClip(clip.id!, ''),
        throwsArgumentError,
      );
    });

    test(
      'adds, lists, counts, renames, and deletes clips with file cleanup',
      () async {
        final session = await sessionRepo.createSession(
          RecordingSession.create(bufferSeconds: 30),
        );
        final clipPath1 = await storageService.nextClipFilePath(
          sessionId: session.id!,
          timestamp: DateTime(2026, 4, 1, 12, 0),
        );
        final clipPath2 = await storageService.nextClipFilePath(
          sessionId: session.id!,
          timestamp: DateTime(2026, 4, 1, 12, 1),
        );
        await File(clipPath1).writeAsBytes(<int>[1, 2, 3, 4]);
        await File(clipPath2).writeAsBytes(<int>[5, 6, 7, 8]);

        final c1 = await sessionRepo.addClip(
          AudioClip.create(
            sessionId: session.id!,
            filePath: clipPath1,
            durationMs: 4000,
            sizeBytes: 4,
            clipNumber: 1,
            createdAt: DateTime(2026, 4, 1, 12, 0),
          ),
        );
        final c2 = await sessionRepo.addClip(
          AudioClip.create(
            sessionId: session.id!,
            filePath: clipPath2,
            durationMs: 8000,
            sizeBytes: 4,
            clipNumber: 2,
            createdAt: DateTime(2026, 4, 1, 12, 1),
          ),
        );

        expect(await sessionRepo.countClipsForSession(session.id!), 2);
        final ordered = await sessionRepo.listClipsForSession(session.id!);
        expect(ordered.map((c) => c.id), <int?>[c1.id, c2.id]);

        await sessionRepo.renameClip(c1.id!, 'Important Line');
        expect((await sessionRepo.getClip(c1.id!))?.name, 'Important Line');

        await sessionRepo.deleteClip(c1.id!);
        expect(await sessionRepo.getClip(c1.id!), isNull);
        expect(await File(clipPath1).exists(), isFalse);
        expect(await File(clipPath2).exists(), isTrue);
      },
    );

    test('deleteSession cascades clips in DB and removes clip files on disk', () async {
      final session = await sessionRepo.createSession(
        RecordingSession.create(bufferSeconds: 30),
      );
      final clipPath = await storageService.nextClipFilePath(
        sessionId: session.id!,
      );
      await File(clipPath).writeAsBytes(<int>[10, 20, 30]);

      final clip = await sessionRepo.addClip(
        AudioClip.create(
          sessionId: session.id!,
          filePath: clipPath,
          durationMs: 5000,
          sizeBytes: 3,
        ),
      );

      await sessionRepo.deleteSession(session.id!);

      expect(await sessionRepo.getSession(session.id!), isNull);
      expect(await sessionRepo.getClip(clip.id!), isNull);
      expect(await File(clipPath).exists(), isFalse);
      final sessionDir = await storageService.getSessionDirectory(session.id!);
      // Directory was deleted; calling getSessionDirectory recreates it empty.
      expect(await sessionDir.list().isEmpty, isTrue);
    });
  });
}
