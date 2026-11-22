import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/audio_clip.dart';
import 'package:learnese/data_models/recording_session.dart';
import 'package:learnese/data_models/recording_state.dart';
import 'package:learnese/main.dart';
import 'package:learnese/services/permission_service.dart';
import 'package:learnese/services/preferences_service.dart';
import 'package:learnese/services/recorder_channel.dart';
import 'package:learnese/services/session_controller.dart';
import 'package:learnese/services/session_repository.dart';
import 'package:learnese/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRecorderChannel extends Mock implements RecorderChannel {}

class MockPermissionService extends Mock implements PermissionService {}

class MockSessionRepository extends Mock implements SessionRepository {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  setUpAll(() {
    registerFallbackValue(RecordingSession.create(bufferSeconds: 30));
    registerFallbackValue(
      AudioClip.create(
        sessionId: 1,
        filePath: '/clips/fallback.wav',
        durationMs: 1000,
        sizeBytes: 100,
      ),
    );
  });

  group('Home & Active Session Flow', () {
    late MockSessionRepository sessionRepo;
    late MockStorageService storageService;
    late PreferencesService prefsService;
    late MockRecorderChannel recorderChannel;
    late MockPermissionService permissionService;
    late StreamController<RecordingState> stateStreamController;
    late StreamController<void> openSessionController;
    late SessionController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      sessionRepo = MockSessionRepository();
      storageService = MockStorageService();
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
      when(
        () => recorderChannel.startSession(
          bufferSeconds: any(named: 'bufferSeconds'),
          outputDir: any(named: 'outputDir'),
        ),
      ).thenAnswer((_) async => true);
      when(() => recorderChannel.stopSession()).thenAnswer((_) async => true);
      when(() => permissionService.checkAll())
          .thenAnswer((_) async => const PermissionCheckResult.allGranted());
      when(() => sessionRepo.getActiveSession()).thenAnswer((_) async => null);
      when(() => sessionRepo.createSession(any()))
          .thenAnswer((Invocation inv) async {
            final session = inv.positionalArguments.first as RecordingSession;
            return session.copyWith(id: 1);
          });
      when(() => sessionRepo.addClip(any())).thenAnswer((Invocation inv) async {
        final clip = inv.positionalArguments.first as AudioClip;
        return clip.copyWith(id: 10);
      });
      when(() => sessionRepo.endSession(any())).thenAnswer((_) async {});
      when(() => storageService.getSessionDirectory(any()))
          .thenAnswer((_) async => Directory('/tmp/clips/session_1'));

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
    });

    testWidgets(
      'transitions Home -> ActiveSession, increments clip count, routes notification tap, and stops back to Home',
      (WidgetTester tester) async {
        await tester.pumpWidget(LearneseApp(sessionController: controller));
        await tester.pumpAndSettle();

        // Idle home screen with disclosure notes & Record Now.
        expect(find.text('Audio Instant Replay'), findsOneWidget);
        expect(find.text('Record Now'), findsOneWidget);
        expect(find.textContaining('never the microphone'), findsOneWidget);

        // Pick 60s preset and start session.
        await tester.tap(find.text('60s'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record Now'));
        await tester.pumpAndSettle();

        // ActiveSessionPage is now visible.
        expect(find.text('Active Session'), findsOneWidget);
        expect(find.text('Buffering last 60s'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('active_session_clip_count')))
              .data,
          '0',
        );

        // Simulate overlay clip save event from native side.
        stateStreamController.add(
          const RecordingState.active(
            bufferedMs: 14000,
            bufferSeconds: 60,
            lastSavedClipPath: '/clips/clip_1.wav',
            lastSavedClipDurationMs: 14000,
            lastSavedClipSizeBytes: 1234844,
          ),
        );
        await tester.runAsync(() => pumpEventQueue());
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Text>(find.byKey(const Key('active_session_clip_count')))
              .data,
          '1',
        );

        // Open Library tab, then simulate notification tap routing back to Active Session.
        await tester.tap(find.text('Open Library'));
        await tester.pumpAndSettle();
        expect(
          find.text('Saved sessions and clips will appear here.'),
          findsOneWidget,
        );

        openSessionController.add(null);
        await tester.runAsync(() => pumpEventQueue());
        await tester.pumpAndSettle();
        expect(find.text('Active Session'), findsOneWidget);

        // Tap Stop Session -> returns to idle HomePage.
        await tester.tap(find.text('Stop Session'));
        await tester.pumpAndSettle();
        expect(find.text('Record Now'), findsOneWidget);
      },
    );
  });
}
