import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

@immutable
class PermissionCheckResult {
  const PermissionCheckResult({
    required this.audioGranted,
    required this.notificationGranted,
    required this.overlayGranted,
    this.permanentlyDenied = false,
  });

  const PermissionCheckResult.allGranted()
    : audioGranted = true,
      notificationGranted = true,
      overlayGranted = true,
      permanentlyDenied = false;

  const PermissionCheckResult.missing({
    required this.audioGranted,
    required this.notificationGranted,
    required this.overlayGranted,
    this.permanentlyDenied = false,
  });

  final bool audioGranted;
  final bool notificationGranted;
  final bool overlayGranted;
  final bool permanentlyDenied;

  /// Audio playback capture strictly requires RECORD_AUDIO.
  bool get canCaptureAudio => audioGranted;

  /// Full session UX requires RECORD_AUDIO, overlay permission, and notifications.
  bool get allGrantedForSession =>
      audioGranted && notificationGranted && overlayGranted;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PermissionCheckResult &&
            other.audioGranted == audioGranted &&
            other.notificationGranted == notificationGranted &&
            other.overlayGranted == overlayGranted &&
            other.permanentlyDenied == permanentlyDenied);
  }

  @override
  int get hashCode => Object.hash(
    audioGranted,
    notificationGranted,
    overlayGranted,
    permanentlyDenied,
  );

  @override
  String toString() {
    return 'PermissionCheckResult(audio: $audioGranted, '
        'notification: $notificationGranted, overlay: $overlayGranted, '
        'permanentlyDenied: $permanentlyDenied)';
  }
}

/// Thin abstraction over `permission_handler` for unit testability.
abstract class PermissionGateway {
  Future<PermissionStatus> status(Permission permission);
  Future<PermissionStatus> request(Permission permission);
  Future<bool> openSettings();
}

class DefaultPermissionGateway implements PermissionGateway {
  const DefaultPermissionGateway();

  @override
  Future<PermissionStatus> status(Permission permission) => permission.status;

  @override
  Future<PermissionStatus> request(Permission permission) =>
      permission.request();

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// Checks and requests the Android runtime permissions required by Learnese.
/// Note: Android requires RECORD_AUDIO (`Permission.microphone`) for AudioPlaybackCapture,
/// even though Learnese only captures internal playback and never uses the microphone.
class PermissionService {
  PermissionService({PermissionGateway? gateway})
    : _gateway = gateway ?? const DefaultPermissionGateway();

  final PermissionGateway _gateway;

  Future<PermissionCheckResult> checkAll() async {
    final audio = await _gateway.status(Permission.microphone);
    final notification = await _gateway.status(Permission.notification);
    final overlay = await _gateway.status(Permission.systemAlertWindow);

    return _buildResult(
      audio: audio,
      notification: notification,
      overlay: overlay,
    );
  }

  Future<PermissionCheckResult> requestRecordingPermissions({
    bool includeOverlay = true,
  }) async {
    var audio = await _gateway.status(Permission.microphone);
    if (!audio.isGranted) {
      audio = await _gateway.request(Permission.microphone);
    }

    var notification = await _gateway.status(Permission.notification);
    if (!notification.isGranted) {
      notification = await _gateway.request(Permission.notification);
    }

    var overlay = await _gateway.status(Permission.systemAlertWindow);
    if (includeOverlay && !overlay.isGranted) {
      overlay = await _gateway.request(Permission.systemAlertWindow);
    }

    return _buildResult(
      audio: audio,
      notification: notification,
      overlay: overlay,
    );
  }

  Future<bool> hasOverlayPermission() async {
    final status = await _gateway.status(Permission.systemAlertWindow);
    return status.isGranted;
  }

  Future<bool> requestOverlayPermission() async {
    final status = await _gateway.request(Permission.systemAlertWindow);
    return status.isGranted;
  }

  Future<bool> openSettings() => _gateway.openSettings();

  PermissionCheckResult _buildResult({
    required PermissionStatus audio,
    required PermissionStatus notification,
    required PermissionStatus overlay,
  }) {
    final permanentlyDenied =
        audio.isPermanentlyDenied ||
        notification.isPermanentlyDenied ||
        overlay.isPermanentlyDenied;

    if (audio.isGranted && notification.isGranted && overlay.isGranted) {
      return const PermissionCheckResult.allGranted();
    }

    return PermissionCheckResult.missing(
      audioGranted: audio.isGranted,
      notificationGranted: notification.isGranted,
      overlayGranted: overlay.isGranted,
      permanentlyDenied: permanentlyDenied,
    );
  }
}
