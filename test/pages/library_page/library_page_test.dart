import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/audio_clip.dart';
import 'package:learnese/data_models/folder.dart';
import 'package:learnese/data_models/recording_session.dart';
import 'package:learnese/pages/library_page/library_page.dart';
import 'package:learnese/pages/library_page/player_sheet.dart';
import 'package:learnese/services/folder_repository.dart';
import 'package:learnese/services/library_controller.dart';
import 'package:learnese/services/session_repository.dart';
import 'package:learnese/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockFolderRepository extends Mock implements FolderRepository {}

class _FakeAudioPlayer implements ClipAudioPlayer {
  final _pos = StreamController<Duration>.broadcast();
  final _dur = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  @override
  Stream<Duration> get positionStream => _pos.stream;

  @override
  Stream<Duration?> get durationStream => _dur.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<Duration?> setFilePath(String filePath) async =>
      const Duration(seconds: 12);

  @override
  Future<void> play() async => _playing.add(true);

  @override
  Future<void> pause() async => _playing.add(false);

  @override
  Future<void> seek(Duration position) async => _pos.add(position);

  @override
  Future<void> dispose() async {
    await _pos.close();
    await _dur.close();
    await _playing.close();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Folder.root(name: 'Fallback'));
  });

  group('LibraryPage', () {
    late _MockSessionRepository sessionRepo;
    late _MockFolderRepository folderRepo;
    late LibraryController controller;

    late List<Folder> allFolders;
    late List<RecordingSession> sessions;
    late Map<int, List<AudioClip>> clips;
    var nextFolderId = 2;

    setUp(() {
      sessionRepo = _MockSessionRepository();
      folderRepo = _MockFolderRepository();

      final studyFolder = Folder.root(
        id: 1,
        name: 'Study',
        createdAt: DateTime(2026, 6, 1),
      );
      allFolders = <Folder>[studyFolder];
      sessions = <RecordingSession>[
        RecordingSession(
          id: 10,
          name: 'Morning Podcast',
          startedAt: DateTime(2026, 6, 1, 9, 0),
          endedAt: DateTime(2026, 6, 1, 9, 30),
          bufferSeconds: 30,
        ),
      ];
      clips = <int, List<AudioClip>>{
        10: <AudioClip>[
          AudioClip(
            id: 100,
            sessionId: 10,
            name: 'Clip 1',
            filePath: '/clips/session_10/clip_1.wav',
            durationMs: 12000,
            sizeBytes: 1058444,
            createdAt: DateTime(2026, 6, 1, 9, 5),
          ),
        ],
      };

      when(
        () => folderRepo.listFolders(
          parentId: any(named: 'parentId'),
          rootOnly: any(named: 'rootOnly'),
        ),
      ).thenAnswer((Invocation inv) async {
        final rootOnly = inv.namedArguments[#rootOnly] as bool? ?? false;
        final parentId = inv.namedArguments[#parentId] as int?;
        if (rootOnly) {
          return allFolders.where((f) => f.isRoot).toList();
        }
        if (parentId != null) {
          return allFolders.where((f) => f.parentId == parentId).toList();
        }
        return List<Folder>.of(allFolders);
      });

      when(() => folderRepo.getBreadcrumbs(any()))
          .thenAnswer((Invocation inv) async {
            final id = inv.positionalArguments.first as int;
            return allFolders.where((f) => f.id == id).toList();
          });

      when(() => folderRepo.createFolder(any()))
          .thenAnswer((Invocation inv) async {
            final f = (inv.positionalArguments.first as Folder).copyWith(
              id: nextFolderId++,
            );
            allFolders.add(f);
            return f;
          });

      when(
        () => sessionRepo.listSessions(
          folderId: any(named: 'folderId'),
          rootOnly: any(named: 'rootOnly'),
        ),
      ).thenAnswer((Invocation inv) async {
        final rootOnly = inv.namedArguments[#rootOnly] as bool? ?? false;
        final folderId = inv.namedArguments[#folderId] as int?;
        if (rootOnly) {
          return sessions.where((s) => s.folderId == null).toList();
        }
        if (folderId != null) {
          return sessions.where((s) => s.folderId == folderId).toList();
        }
        return List<RecordingSession>.of(sessions);
      });

      when(() => sessionRepo.listClipsForSession(any()))
          .thenAnswer((Invocation inv) async {
            final id = inv.positionalArguments.first as int;
            return List<AudioClip>.of(clips[id] ?? const <AudioClip>[]);
          });

      when(() => sessionRepo.renameSession(any(), any()))
          .thenAnswer((Invocation inv) async {
            final id = inv.positionalArguments[0] as int;
            final name = inv.positionalArguments[1] as String;
            sessions = sessions
                .map((s) => s.id == id ? s.copyWith(name: name) : s)
                .toList();
          });

      when(
        () => sessionRepo.moveSession(any(), folderId: any(named: 'folderId')),
      ).thenAnswer((Invocation inv) async {
        final id = inv.positionalArguments[0] as int;
        final folderId = inv.namedArguments[#folderId] as int?;
        sessions = sessions
            .map(
              (s) => s.id == id
                  ? s.copyWith(
                      folderId: folderId,
                      clearFolderId: folderId == null,
                    )
                  : s,
            )
            .toList();
      });

      when(() => sessionRepo.deleteClip(any()))
          .thenAnswer((Invocation inv) async {
            final clipId = inv.positionalArguments.first as int;
            for (final entry in clips.entries) {
              entry.value.removeWhere((c) => c.id == clipId);
            }
          });

      controller = LibraryController(
        sessionRepository: sessionRepo,
        folderRepository: folderRepo,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    Widget wrap() {
      return MaterialApp(
        theme: AppTheme.light(),
        home: LibraryPage(
          controller: controller,
          playerFactory: _FakeAudioPlayer.new,
        ),
      );
    }

    testWidgets(
      'creates folders, opens breadcrumbs, renames/moves sessions, plays & deletes clips',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(find.text('Study'), findsOneWidget);
        expect(find.text('Morning Podcast'), findsOneWidget);
        expect(find.text('Clip 1'), findsOneWidget);

        // Open player sheet by tapping clip.
        await tester.tap(find.text('Clip 1'));
        await tester.pumpAndSettle();
        expect(find.byType(Slider), findsOneWidget);
        Navigator.of(tester.element(find.byType(Slider))).pop();
        await tester.pumpAndSettle();

        // Create a new folder.
        await tester.tap(find.byTooltip('New Folder'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Lectures');
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(find.text('Lectures'), findsOneWidget);

        // Rename session via overflow menu.
        await tester.tap(find.byTooltip('Session options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Episode 42');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Episode 42'), findsOneWidget);

        // Move session into Study folder and verify it appears after navigating in.
        await tester.tap(find.byTooltip('Session options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Move to folder'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Study'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Episode 42'), findsNothing);

        await tester.tap(find.text('Study'));
        await tester.pumpAndSettle();
        expect(find.text('Episode 42'), findsOneWidget);
        expect(find.text('Library'), findsWidgets);

        // Delete clip with confirmation dialog.
        await tester.tap(find.byTooltip('Clip options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete Clip?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Clip 1'), findsNothing);
      },
    );
  });
}
