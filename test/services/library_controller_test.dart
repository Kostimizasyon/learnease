import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/audio_clip.dart';
import 'package:learnese/data_models/recording_session.dart';
import 'package:learnese/services/database_helper.dart';
import 'package:learnese/services/folder_repository.dart';
import 'package:learnese/services/library_controller.dart';
import 'package:learnese/services/session_repository.dart';
import 'package:learnese/services/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('LibraryController (repository integration)', () {
    late Directory tempRoot;
    late DatabaseHelper dbHelper;
    late StorageService storageService;
    late SessionRepository sessionRepo;
    late FolderRepository folderRepo;
    late LibraryController controller;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('learnese_lib_test_');
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
      controller = LibraryController(
        sessionRepository: sessionRepo,
        folderRepository: folderRepo,
      );
    });

    tearDown(() async {
      controller.dispose();
      await dbHelper.close();
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('navigates nested folders, builds breadcrumbs, and organizes sessions & clips', () async {
      // Create root folder -> sub-folder -> grandchild.
      await controller.createFolder('Languages');
      final languages = controller.folders.single;
      await controller.openFolder(languages.id);
      await controller.createFolder('Japanese');
      final japanese = controller.folders.single;
      await controller.openFolder(japanese.id);
      await controller.createFolder('NHK');
      final nhk = controller.folders.single;

      expect(controller.breadcrumbs.map((f) => f.name), <String>[
        'Languages',
        'Japanese',
      ]);
      expect(controller.excludedMoveTargetsForFolder(languages.id!), <int>{
        languages.id!,
        japanese.id!,
        nhk.id!,
      });

      // Return to root and seed two sessions (newest-first ordering).
      await controller.openFolder(null);
      final older = await sessionRepo.createSession(
        RecordingSession.create(
          bufferSeconds: 30,
          name: 'Older Session',
          startedAt: DateTime(2026, 6, 1, 9, 0),
        ),
      );
      final newer = await sessionRepo.createSession(
        RecordingSession.create(
          bufferSeconds: 60,
          name: 'Newer Session',
          startedAt: DateTime(2026, 6, 1, 10, 0),
        ),
      );
      final clipPath = await storageService.nextClipFilePath(
        sessionId: newer.id!,
      );
      await File(clipPath).writeAsBytes(<int>[1, 2, 3, 4]);
      final clip = await sessionRepo.addClip(
        AudioClip.create(
          sessionId: newer.id!,
          filePath: clipPath,
          durationMs: 7500,
          sizeBytes: 4,
        ),
      );

      await controller.load();
      expect(controller.sessions.map((s) => s.id), <int?>[newer.id, older.id]);
      expect(controller.clipsForSession(newer.id!).single.id, clip.id);

      // Rename clip & session, move session into Japanese sub-folder.
      await controller.renameClip(clip.id!, 'Greeting Phrase');
      await controller.renameSession(newer.id!, 'Episode 1');
      await controller.moveSession(newer.id!, folderId: japanese.id);

      expect(controller.sessions.map((s) => s.id), <int?>[older.id]);

      await controller.openFolder(japanese.id);
      expect(controller.sessions.single.name, 'Episode 1');
      expect(
        controller.clipsForSession(newer.id!).single.name,
        'Greeting Phrase',
      );

      // Deleting currently open folder navigates up to parent and unfiles session to root.
      await controller.deleteFolder(japanese.id!);
      expect(controller.currentFolderId, languages.id);
      await controller.openFolder(null);
      expect(
        controller.sessions.map((s) => s.id),
        containsAll(<int?>[newer.id, older.id]),
      );

      // Delete clip cleans up file on disk.
      await controller.deleteClip(clip.id!);
      expect(controller.clipsForSession(newer.id!), isEmpty);
      expect(await File(clipPath).exists(), isFalse);
    });

    test('currentFolderPlayableClips includes only clips inside the currently open folder', () async {
      await controller.createFolder('FolderA');
      final folderA = controller.folders.single;
      await controller.openFolder(folderA.id);
      await controller.createFolder('SubInA');
      final subInA = controller.folders.single;
      await controller.openFolder(null);
      await controller.createFolder('FolderB');
      final folderB = controller.folders.firstWhere((f) => f.name == 'FolderB');

      final rootSession = await sessionRepo.createSession(
        RecordingSession.create(bufferSeconds: 30, name: 'Root Session'),
      );
      final aSession = await sessionRepo.createSession(
        RecordingSession.create(
          bufferSeconds: 30,
          name: 'A Session',
          folderId: folderA.id,
        ),
      );
      final subSession = await sessionRepo.createSession(
        RecordingSession.create(
          bufferSeconds: 30,
          name: 'Sub Session',
          folderId: subInA.id,
        ),
      );
      final bSession = await sessionRepo.createSession(
        RecordingSession.create(
          bufferSeconds: 30,
          name: 'B Session',
          folderId: folderB.id,
        ),
      );

      await sessionRepo.addClip(
        AudioClip.create(
          sessionId: rootSession.id!,
          filePath: '/root_1.wav',
          durationMs: 1000,
          sizeBytes: 100,
          name: 'Root Clip',
        ),
      );
      await sessionRepo.addClip(
        AudioClip.create(
          sessionId: aSession.id!,
          filePath: '/a_1.wav',
          durationMs: 1000,
          sizeBytes: 100,
          name: 'A Clip 1',
        ),
      );
      await sessionRepo.addClip(
        AudioClip.create(
          sessionId: aSession.id!,
          filePath: '/a_2.wav',
          durationMs: 1000,
          sizeBytes: 100,
          name: 'A Clip 2',
        ),
      );
      await sessionRepo.addClip(
        AudioClip.create(
          sessionId: subSession.id!,
          filePath: '/sub_1.wav',
          durationMs: 1000,
          sizeBytes: 100,
          name: 'Sub Clip',
        ),
      );
      await sessionRepo.addClip(
        AudioClip.create(
          sessionId: bSession.id!,
          filePath: '/b_1.wav',
          durationMs: 1000,
          sizeBytes: 100,
          name: 'B Clip',
        ),
      );

      await controller.openFolder(folderA.id);
      expect(
        controller.currentFolderPlayableClips.map((p) => p.clip.name),
        <String>['A Clip 1', 'A Clip 2'],
      );

      await controller.openFolder(subInA.id);
      expect(
        controller.currentFolderPlayableClips.map((p) => p.clip.name),
        <String>['Sub Clip'],
      );

      await controller.openFolder(null);
      expect(
        controller.currentFolderPlayableClips.map((p) => p.clip.name),
        <String>['Root Clip'],
      );
    });
  });
}
