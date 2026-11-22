import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/recording_session.dart';
import 'package:learnese/data_models/recording_state.dart';
import 'package:learnese/services/database_helper.dart';
import 'package:learnese/services/permission_service.dart';
import 'package:learnese/services/preferences_service.dart';
import 'package:learnese/services/recorder_channel.dart';
import 'package:learnese/services/session_controller.dart';
import 'package:learnese/services/session_repository.dart';
import 'package:learnese/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockRecorderChannel extends Mock implements RecorderChannel {}

class MockPermissionService extends Mock implements PermissionService {}

void main() {
  sqfliteFfiInit();

  group('SessionController', () {
    late Directory tempRoot;
    late DatabaseHelper dbHelper;
    late StorageService storageService;
    late SessionRepository sessionRepo;
    late PreferencesService prefsService;
    late MockRecorderChannel recorderChannel;
    late MockPermissionService permissionService;
    late StreamController<RecordingState> stateStreamController;
    late StreamController<void> openSessionController;
    late SessionController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempRoot = await Directory.systemTemp.createTemp('learnese_ctrl_test_');
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
      prefsService = PreferencesService();
      recorderChannel = MockRecorderChannel();
      permissionService = MockPermissionService();
      stateStreamController = StreamController<RecordingState>.broadcast();
      openSessionController = StreamController<void>.broadcast();

      when(() => recorderChannel.stateStream)
          .thenAnswer((_) => stateStreamController.stream);
      when(() => recorderChannel.onOpenActiveSession)
          .thenAnswer((_) => openSessionController.stream);
      when(() => recorderChannel.getState())
          .thenAnswer((_) async => const RecordingState.idle());
      when(() => recorderChannel.consumeOpenActiveSession())
          .thenAnswer((_) async => false);
      when(() => recorderChannel.stopSession()).thenAnswer((_) async => true);

      controller = SessionController(
        recorderChannel: recorderChannel,
        sessionRepository: sessionRepo,
        storageService: storageService,
        preferencesService: prefsService,
        permissionService: permissionService,
      );
    });

    tearDown(() async {
      controller.dispose();
      await stateStreamController.close();
      await openSessionController.close();
      await dbHelper.close();
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('initialize closes stale DB session when native is idle and routes on cold notification tap', () async {
      final stale = await sessionRepo.createSession(
        RecordingSession.create(bufferSeconds: 45),
      );
      when(() => recorderChannel.consumeOpenActiveSession())
          .thenAnswer((_) async => true);

      var navigated = false;
      controller.onNavigateToActiveSession = () => navigated = true;

      await controller.initialize();

      expect(controller.isInitialized, isTrue);
      expect(controller.isSessionActive, isFalse);
      expect((await sessionRepo.getSession(stale.id!))?.isActive, isFalse);
      expect(navigated, isTrue);
    });

    test('startSession deletes empty DB session if projection consent is cancelled', () async {
      await controller.initialize();
      when(
        () => recorderChannel.startSession(
          bufferSeconds: any(named: 'bufferSeconds'),
          outputDir: any(named: 'outputDir'),
        ),
      ).thenAnswer((_) async => false);

      final started = await controller.startSession();

      expect(started, isFalse);
      expect(controller.isSessionActive, isFalse);
      expect(await sessionRepo.listSessions(), isEmpty);
      expect(controller.statusMessage, isNotNull);
    });

    test('persists saved clips from native events, deduplicates paths, and ends DB session on idle', () async {
      await controller.initialize();
      await controller.setBufferSeconds(60);

      String? passedOutputDir;
      when(
        () => recorderChannel.startSession(
          bufferSeconds: 60,
          outputDir: any(named: 'outputDir'),
        ),
      ).thenAnswer((Invocation inv) async {
        passedOutputDir = inv.namedArguments[#outputDir] as String?;
        return true;
      });

      expect(await controller.startSession(), isTrue);
      expect(controller.isSessionActive, isTrue);
      expect(passedOutputDir, isNotNull);
      final sessionId = controller.activeSession!.id!;

      // Emit first clip saved event (and duplicate replay).
      const clip1Event = RecordingState.active(
        bufferedMs: 12000,
        bufferSeconds: 60,
        lastSavedClipPath: '/clips/clip_1.wav',
        lastSavedClipDurationMs: 12000,
        lastSavedClipSizeBytes: 1058444,
      );
      stateStreamController.add(clip1Event);
      stateStreamController.add(clip1Event);

      // Emit second clip saved event.
      stateStreamController.add(
        const RecordingState.active(
          bufferedMs: 25000,
          bufferSeconds: 60,
          lastSavedClipPath: '/clips/clip_2.wav',
          lastSavedClipDurationMs: 25000,
          lastSavedClipSizeBytes: 2205044,
        ),
      );
      await pumpEventQueue();

      expect(controller.activeClipCount, 2);
      final storedClips = await sessionRepo.listClipsForSession(sessionId);
      expect(storedClips, hasLength(2));
      expect(storedClips[0].name, 'Clip 1');
      expect(storedClips[1].name, 'Clip 2');
      expect(storedClips[0].durationMs, 12000);

      // Simulate overlay drag-to-dismiss or projection revocation ending session.
      stateStreamController.add(
        const RecordingState.idle(
          error: CaptureError.projectionRevoked,
          errorMessage: 'Screen capture permission was revoked.',
        ),
      );
      await pumpEventQueue();

      expect(controller.isSessionActive, isFalse);
      expect(controller.statusMessage, contains('revoked'));
      final ended = await sessionRepo.getSession(sessionId);
      expect(ended?.isActive, isFalse);
    });

    test(
      'stopSession invokes native stop and ends active session in DB',
      () async {
        await controller.initialize();
        when(
          () => recorderChannel.startSession(
            bufferSeconds: any(named: 'bufferSeconds'),
            outputDir: any(named: 'outputDir'),
          ),
        ).thenAnswer((_) async => true);

        await controller.startSession();
        final sessionId = controller.activeSession!.id!;

        await controller.stopSession();

        verify(() => recorderChannel.stopSession()).called(1);
        expect(controller.isSessionActive, isFalse);
        expect((await sessionRepo.getSession(sessionId))?.isActive, isFalse);
      },
    );
  });
}
