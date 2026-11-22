import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/folder.dart';
import 'package:learnese/data_models/recording_session.dart';
import 'package:learnese/services/database_helper.dart';
import 'package:learnese/services/folder_repository.dart';
import 'package:learnese/services/session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('FolderRepository', () {
    late DatabaseHelper dbHelper;
    late FolderRepository folderRepo;
    late SessionRepository sessionRepo;

    setUp(() {
      dbHelper = DatabaseHelper(
        databaseFactory: databaseFactoryFfi,
        dbPath: inMemoryDatabasePath,
      );
      folderRepo = FolderRepository(databaseHelper: dbHelper);
      sessionRepo = SessionRepository(databaseHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test(
      'creates nested folders, lists alphabetically, and builds breadcrumbs',
      () async {
        final rootB = await folderRepo.createFolder(
          Folder.root(name: 'podcasts'),
        );
        final rootA = await folderRepo.createFolder(Folder.root(name: 'Audio'));
        final child = await folderRepo.createFolder(
          Folder.nested(name: 'Japanese', parentId: rootA.id!),
        );
        final grandchild = await folderRepo.createFolder(
          Folder.nested(name: 'NHKEasy', parentId: child.id!),
        );

        final roots = await folderRepo.listFolders(rootOnly: true);
        expect(roots.map((f) => f.id), <int?>[rootA.id, rootB.id]);

        final childrenOfA = await folderRepo.listFolders(parentId: rootA.id);
        expect(childrenOfA.map((f) => f.id), <int?>[child.id]);

        final breadcrumbs = await folderRepo.getBreadcrumbs(grandchild.id!);
        expect(breadcrumbs.map((f) => f.id), <int?>[
          rootA.id,
          child.id,
          grandchild.id,
        ]);
      },
    );

    test(
      'renames and moves folders while preventing self/descendant cycles',
      () async {
        final parent = await folderRepo.createFolder(
          Folder.root(name: 'Parent'),
        );
        final child = await folderRepo.createFolder(
          Folder.nested(name: 'Child', parentId: parent.id!),
        );
        final grandchild = await folderRepo.createFolder(
          Folder.nested(name: 'Grandchild', parentId: child.id!),
        );
        final other = await folderRepo.createFolder(Folder.root(name: 'Other'));

        await folderRepo.renameFolder(child.id!, 'Renamed Child');
        expect((await folderRepo.getFolder(child.id!))?.name, 'Renamed Child');

        await expectLater(
          folderRepo.renameFolder(child.id!, '   '),
          throwsArgumentError,
        );

        // Cycle guards
        await expectLater(
          folderRepo.moveFolder(parent.id!, newParentId: parent.id),
          throwsArgumentError,
        );
        await expectLater(
          folderRepo.moveFolder(parent.id!, newParentId: grandchild.id),
          throwsArgumentError,
        );

        // Valid move to another folder, then back to root
        await folderRepo.moveFolder(child.id!, newParentId: other.id);
        expect((await folderRepo.getFolder(child.id!))?.parentId, other.id);

        await folderRepo.moveFolder(child.id!, newParentId: null);
        expect((await folderRepo.getFolder(child.id!))?.isRoot, isTrue);
      },
    );

    test(
      'deleting parent folder cascades sub-folders and unfiles sessions',
      () async {
        final root = await folderRepo.createFolder(Folder.root(name: 'Root'));
        final sub = await folderRepo.createFolder(
          Folder.nested(name: 'Sub', parentId: root.id!),
        );

        final sessionInSub = await sessionRepo.createSession(
          RecordingSession.create(bufferSeconds: 30, folderId: sub.id),
        );

        await folderRepo.deleteFolder(root.id!);

        expect(await folderRepo.getFolder(root.id!), isNull);
        expect(await folderRepo.getFolder(sub.id!), isNull);

        final unfiledSession = await sessionRepo.getSession(sessionInSub.id!);
        expect(unfiledSession, isNotNull);
        expect(unfiledSession!.folderId, isNull);
      },
    );
  });
}
