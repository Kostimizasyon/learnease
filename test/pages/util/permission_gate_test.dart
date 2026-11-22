import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/pages/util/permission_gate.dart';
import 'package:learnese/services/permission_service.dart';
import 'package:learnese/services/recorder_channel.dart';
import 'package:learnese/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

class MockPermissionGateway extends Mock implements PermissionGateway {}

class MockRecorderChannel extends Mock implements RecorderChannel {}

void main() {
  setUpAll(() {
    registerFallbackValue(Permission.microphone);
  });

  group('PermissionGate', () {
    late MockPermissionGateway gateway;
    late MockRecorderChannel channel;
    late PermissionService permissionService;

    setUp(() {
      gateway = MockPermissionGateway();
      channel = MockRecorderChannel();
      permissionService = PermissionService(gateway: gateway);
    });

    Widget wrap(Widget child) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      );
    }

    testWidgets(
      'sessionSetup disables Continue until audio and overlay are granted',
      (WidgetTester tester) async {
        var audioStatus = PermissionStatus.denied;
        var notifStatus = PermissionStatus.denied;
        var overlayGranted = false;

        when(() => gateway.status(Permission.microphone))
            .thenAnswer((_) async => audioStatus);
        when(() => gateway.status(Permission.notification))
            .thenAnswer((_) async => notifStatus);
        when(() => gateway.status(Permission.systemAlertWindow)).thenAnswer(
          (_) async => overlayGranted
              ? PermissionStatus.granted
              : PermissionStatus.denied,
        );
        when(() => channel.hasOverlayPermission())
            .thenAnswer((_) async => overlayGranted);

        when(() => gateway.request(Permission.microphone))
            .thenAnswer((_) async {
              audioStatus = PermissionStatus.granted;
              return audioStatus;
            });
        when(() => gateway.request(Permission.notification))
            .thenAnswer((_) async {
              notifStatus = PermissionStatus.granted;
              return notifStatus;
            });
        when(() => channel.openOverlayPermissionSettings())
            .thenAnswer((_) async {
              overlayGranted = true;
              return true;
            });

        var readyCalled = false;
        await tester.pumpWidget(
          wrap(
            PermissionGate.sessionSetup(
              permissionService: permissionService,
              recorderChannel: channel,
              onReady: () => readyCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        FilledButton continueButton() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Continue'),
        );

        expect(continueButton().onPressed, isNull);
        expect(find.text('Audio Output Capture'), findsOneWidget);
        expect(find.text('Display Over Other Apps'), findsOneWidget);

        // Grant standard permissions first.
        await tester.tap(find.text('Allow').first);
        await tester.pumpAndSettle();
        expect(continueButton().onPressed, isNull);

        // Enable overlay permission via native settings shortcut.
        await tester.tap(find.text('Enable'));
        await tester.pumpAndSettle();
        verify(() => channel.openOverlayPermissionSettings()).called(1);
        expect(continueButton().onPressed, isNotNull);

        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        expect(readyCalled, isTrue);
      },
    );

    testWidgets(
      'overlayOnly shows only overlay step and refreshes on lifecycle resume',
      (WidgetTester tester) async {
        var overlayGranted = false;

        when(() => gateway.status(Permission.microphone))
            .thenAnswer((_) async => PermissionStatus.granted);
        when(() => gateway.status(Permission.notification))
            .thenAnswer((_) async => PermissionStatus.granted);
        when(() => gateway.status(Permission.systemAlertWindow)).thenAnswer(
          (_) async => overlayGranted
              ? PermissionStatus.granted
              : PermissionStatus.denied,
        );
        when(() => channel.hasOverlayPermission())
            .thenAnswer((_) async => overlayGranted);

        await tester.pumpWidget(
          wrap(
            PermissionGate.overlayOnly(
              permissionService: permissionService,
              recorderChannel: channel,
              onReady: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Audio Output Capture'), findsNothing);
        expect(find.text('Display Over Other Apps'), findsOneWidget);

        FilledButton continueButton() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Continue'),
        );
        expect(continueButton().onPressed, isNull);

        // Simulate user granting permission in Android Settings and returning.
        overlayGranted = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(continueButton().onPressed, isNotNull);
      },
    );
  });
}
