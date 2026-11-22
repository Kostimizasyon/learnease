import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/recording_state.dart';
import 'package:learnese/main.dart';
import 'package:learnese/pages/util/floating_pill_nav_bar.dart';
import 'package:learnese/services/permission_service.dart';
import 'package:learnese/services/preferences_service.dart';
import 'package:learnese/services/recorder_channel.dart';
import 'package:learnese/services/session_controller.dart';
import 'package:learnese/services/session_repository.dart';
import 'package:learnese/services/storage_service.dart';
import 'package:learnese/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRecorderChannel extends Mock implements RecorderChannel {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockStorageService extends Mock implements StorageService {}

void main() {
  testWidgets(
    'LearneseApp wires light/dark themes and home/library navigation',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final channel = _MockRecorderChannel();
      final permissions = _MockPermissionService();
      final sessionRepo = _MockSessionRepository();
      final storage = _MockStorageService();
      final stateStream = StreamController<RecordingState>.broadcast();
      final openStream = StreamController<void>.broadcast();

      when(() => channel.stateStream).thenAnswer((_) => stateStream.stream);
      when(() => channel.onOpenActiveSession)
          .thenAnswer((_) => openStream.stream);
      when(() => channel.getState())
          .thenAnswer((_) async => const RecordingState.idle());
      when(() => channel.consumeOpenActiveSession())
          .thenAnswer((_) async => false);
      when(() => sessionRepo.getActiveSession()).thenAnswer((_) async => null);

      final controller = SessionController(
        recorderChannel: channel,
        sessionRepository: sessionRepo,
        storageService: storage,
        preferencesService: PreferencesService(),
        permissionService: permissions,
      );

      addTearDown(() async {
        controller.dispose();
        await stateStream.close();
        await openStream.close();
      });

      await tester.pumpWidget(LearneseApp(sessionController: controller));
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Learnese');
      expect(materialApp.themeMode, ThemeMode.system);
      expect(materialApp.theme?.extension<AppRecordingColors>(), isNotNull);
      expect(materialApp.darkTheme?.extension<AppRecordingColors>(), isNotNull);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(FloatingPillNavBar), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Record Now'), findsOneWidget);
    },
  );
}
