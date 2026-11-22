import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/services/permission_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

class MockPermissionGateway extends Mock implements PermissionGateway {}

void main() {
  setUpAll(() {
    registerFallbackValue(Permission.microphone);
  });

  group('PermissionService', () {
    late MockPermissionGateway gateway;
    late PermissionService service;

    setUp(() {
      gateway = MockPermissionGateway();
      service = PermissionService(gateway: gateway);
    });

    test(
      'checkAll returns allGranted when every permission is granted',
      () async {
        when(() => gateway.status(Permission.microphone))
            .thenAnswer((_) async => PermissionStatus.granted);
        when(() => gateway.status(Permission.notification))
            .thenAnswer((_) async => PermissionStatus.granted);
        when(() => gateway.status(Permission.systemAlertWindow))
            .thenAnswer((_) async => PermissionStatus.granted);

        final result = await service.checkAll();

        expect(result, const PermissionCheckResult.allGranted());
        expect(result.canCaptureAudio, isTrue);
        expect(result.allGrantedForSession, isTrue);
        expect(result.permanentlyDenied, isFalse);
      },
    );

    test(
      'requestRecordingPermissions requests only missing permissions',
      () async {
        when(() => gateway.status(Permission.microphone))
            .thenAnswer((_) async => PermissionStatus.granted);
        when(() => gateway.status(Permission.notification))
            .thenAnswer((_) async => PermissionStatus.denied);
        when(() => gateway.request(Permission.notification))
            .thenAnswer((_) async => PermissionStatus.granted);
        when(() => gateway.status(Permission.systemAlertWindow))
            .thenAnswer((_) async => PermissionStatus.denied);
        when(() => gateway.request(Permission.systemAlertWindow))
            .thenAnswer((_) async => PermissionStatus.denied);

        final result = await service.requestRecordingPermissions();

        expect(result.audioGranted, isTrue);
        expect(result.notificationGranted, isTrue);
        expect(result.overlayGranted, isFalse);
        expect(result.canCaptureAudio, isTrue);
        expect(result.allGrantedForSession, isFalse);
        verifyNever(() => gateway.request(Permission.microphone));
        verify(() => gateway.request(Permission.notification)).called(1);
        verify(() => gateway.request(Permission.systemAlertWindow)).called(1);
      },
    );

    test(
      'requestRecordingPermissions skips overlay request when disabled',
      () async {
        when(() => gateway.status(Permission.microphone))
            .thenAnswer((_) async => PermissionStatus.denied);
        when(() => gateway.request(Permission.microphone))
            .thenAnswer((_) async => PermissionStatus.permanentlyDenied);
        when(() => gateway.status(Permission.notification))
            .thenAnswer((_) async => PermissionStatus.denied);
        when(() => gateway.request(Permission.notification))
            .thenAnswer((_) async => PermissionStatus.denied);
        when(() => gateway.status(Permission.systemAlertWindow))
            .thenAnswer((_) async => PermissionStatus.denied);

        final result = await service.requestRecordingPermissions(
          includeOverlay: false,
        );

        expect(result.canCaptureAudio, isFalse);
        expect(result.permanentlyDenied, isTrue);
        verifyNever(() => gateway.request(Permission.systemAlertWindow));
      },
    );

    test('overlay helpers and openSettings delegate to gateway', () async {
      when(() => gateway.status(Permission.systemAlertWindow))
          .thenAnswer((_) async => PermissionStatus.denied);
      when(() => gateway.request(Permission.systemAlertWindow))
          .thenAnswer((_) async => PermissionStatus.granted);
      when(() => gateway.openSettings()).thenAnswer((_) async => true);

      expect(await service.hasOverlayPermission(), isFalse);
      expect(await service.requestOverlayPermission(), isTrue);
      expect(await service.openSettings(), isTrue);
    });
  });
}
