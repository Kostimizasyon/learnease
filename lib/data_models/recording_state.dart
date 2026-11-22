import 'package:flutter/foundation.dart';

enum SessionStatus {
  idle('idle'),
  active('active');

  const SessionStatus(this.wireValue);

  final String wireValue;

  static SessionStatus fromWire(String? value) {
    return switch (value) {
      'active' => SessionStatus.active,
      _ => SessionStatus.idle,
    };
  }
}

enum CaptureError {
  none('none'),
  projectionDenied('projection_denied'),
  projectionRevoked('projection_revoked'),
  permissionDenied('permission_denied'),
  overlayPermissionDenied('overlay_permission_denied'),
  audioInitFailed('audio_init_failed'),
  encodingFailed('encoding_failed'),
  storageError('storage_error'),
  unknown('unknown');

  const CaptureError(this.wireValue);

  final String wireValue;

  static CaptureError fromWire(String? value) {
    for (final code in CaptureError.values) {
      if (code.wireValue == value) {
        return code;
      }
    }
    return value == null ? CaptureError.none : CaptureError.unknown;
  }
}

@immutable
class RecordingState {
  const RecordingState({
    required this.sessionState,
    required this.bufferedMs,
    this.bufferSeconds = 0,
    this.lastSavedClipPath,
    this.lastSavedClipDurationMs,
    this.lastSavedClipSizeBytes,
    this.error = CaptureError.none,
    this.errorMessage,
  }) : assert(bufferedMs >= 0, 'bufferedMs must be non-negative.'),
       assert(bufferSeconds >= 0, 'bufferSeconds must be non-negative.');

  const RecordingState.idle({this.error = CaptureError.none, this.errorMessage})
    : sessionState = SessionStatus.idle,
      bufferedMs = 0,
      bufferSeconds = 0,
      lastSavedClipPath = null,
      lastSavedClipDurationMs = null,
      lastSavedClipSizeBytes = null;

  const RecordingState.active({
    required this.bufferedMs,
    this.bufferSeconds = 0,
    this.lastSavedClipPath,
    this.lastSavedClipDurationMs,
    this.lastSavedClipSizeBytes,
  }) : sessionState = SessionStatus.active,
       error = CaptureError.none,
       errorMessage = null;

  const RecordingState.error({
    required this.error,
    this.errorMessage,
    this.sessionState = SessionStatus.idle,
    this.bufferedMs = 0,
    this.bufferSeconds = 0,
  }) : lastSavedClipPath = null,
       lastSavedClipDurationMs = null,
       lastSavedClipSizeBytes = null;

  /// Parses the platform EventChannel payload ({sessionState, bufferedMs, lastSavedClipPath?}).
  factory RecordingState.fromMap(Map<Object?, Object?> map) {
    final rawBufferedMs = (map['bufferedMs'] as num?)?.toInt() ?? 0;
    final rawBufferSeconds = (map['bufferSeconds'] as num?)?.toInt() ?? 0;
    return RecordingState(
      sessionState: SessionStatus.fromWire(map['sessionState'] as String?),
      bufferedMs: rawBufferedMs < 0 ? 0 : rawBufferedMs,
      bufferSeconds: rawBufferSeconds < 0 ? 0 : rawBufferSeconds,
      lastSavedClipPath: map['lastSavedClipPath'] as String?,
      lastSavedClipDurationMs: (map['lastSavedClipDurationMs'] as num?)
          ?.toInt(),
      lastSavedClipSizeBytes: (map['lastSavedClipSizeBytes'] as num?)?.toInt(),
      error: CaptureError.fromWire(map['error'] as String?),
      errorMessage: map['errorMessage'] as String?,
    );
  }

  final SessionStatus sessionState;
  final int bufferedMs;
  final int bufferSeconds;
  final String? lastSavedClipPath;
  final int? lastSavedClipDurationMs;
  final int? lastSavedClipSizeBytes;
  final CaptureError error;
  final String? errorMessage;

  bool get isActive => sessionState == SessionStatus.active;
  bool get isIdle => sessionState == SessionStatus.idle;
  bool get hasError => error != CaptureError.none;
  bool get hasSavedClip =>
      lastSavedClipPath != null && lastSavedClipPath!.isNotEmpty;

  double get bufferFillFraction {
    if (bufferSeconds <= 0) {
      return 0;
    }
    final ratio = bufferedMs / (bufferSeconds * 1000);
    return ratio.clamp(0.0, 1.0);
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'sessionState': sessionState.wireValue,
      'bufferedMs': bufferedMs,
      'bufferSeconds': bufferSeconds,
      if (lastSavedClipPath != null) 'lastSavedClipPath': lastSavedClipPath,
      if (lastSavedClipDurationMs != null)
        'lastSavedClipDurationMs': lastSavedClipDurationMs,
      if (lastSavedClipSizeBytes != null)
        'lastSavedClipSizeBytes': lastSavedClipSizeBytes,
      'error': error.wireValue,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  RecordingState copyWith({
    SessionStatus? sessionState,
    int? bufferedMs,
    int? bufferSeconds,
    String? lastSavedClipPath,
    int? lastSavedClipDurationMs,
    int? lastSavedClipSizeBytes,
    bool clearLastSavedClip = false,
    CaptureError? error,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecordingState(
      sessionState: sessionState ?? this.sessionState,
      bufferedMs: bufferedMs ?? this.bufferedMs,
      bufferSeconds: bufferSeconds ?? this.bufferSeconds,
      lastSavedClipPath: clearLastSavedClip
          ? null
          : (lastSavedClipPath ?? this.lastSavedClipPath),
      lastSavedClipDurationMs: clearLastSavedClip
          ? null
          : (lastSavedClipDurationMs ?? this.lastSavedClipDurationMs),
      lastSavedClipSizeBytes: clearLastSavedClip
          ? null
          : (lastSavedClipSizeBytes ?? this.lastSavedClipSizeBytes),
      error: clearError ? CaptureError.none : (error ?? this.error),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RecordingState &&
            other.sessionState == sessionState &&
            other.bufferedMs == bufferedMs &&
            other.bufferSeconds == bufferSeconds &&
            other.lastSavedClipPath == lastSavedClipPath &&
            other.lastSavedClipDurationMs == lastSavedClipDurationMs &&
            other.lastSavedClipSizeBytes == lastSavedClipSizeBytes &&
            other.error == error &&
            other.errorMessage == errorMessage);
  }

  @override
  int get hashCode => Object.hash(
    sessionState,
    bufferedMs,
    bufferSeconds,
    lastSavedClipPath,
    lastSavedClipDurationMs,
    lastSavedClipSizeBytes,
    error,
    errorMessage,
  );

  @override
  String toString() {
    return 'RecordingState(sessionState: ${sessionState.wireValue}, '
        'bufferedMs: $bufferedMs, bufferSeconds: $bufferSeconds, '
        'lastSavedClipPath: $lastSavedClipPath, error: ${error.wireValue})';
  }
}
