import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data_models/recording_session.dart';
import '../data_models/recording_state.dart';

@immutable
class SavedClipResult {
  const SavedClipResult({
    required this.filePath,
    required this.durationMs,
    required this.sizeBytes,
  });

  factory SavedClipResult.fromMap(Map<Object?, Object?> map) {
    return SavedClipResult(
      filePath: map['filePath'] as String,
      durationMs: (map['durationMs'] as num).toInt(),
      sizeBytes: (map['sizeBytes'] as num).toInt(),
    );
  }

  final String filePath;
  final int durationMs;
  final int sizeBytes;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'filePath': filePath,
      'durationMs': durationMs,
      'sizeBytes': sizeBytes,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SavedClipResult &&
            other.filePath == filePath &&
            other.durationMs == durationMs &&
            other.sizeBytes == sizeBytes);
  }

  @override
  int get hashCode => Object.hash(filePath, durationMs, sizeBytes);

  @override
  String toString() {
    return 'SavedClipResult(filePath: $filePath, durationMs: $durationMs, '
        'sizeBytes: $sizeBytes)';
  }
}

/// Dart platform-channel wrapper bridging Flutter to Android's RecordingService.
class RecorderChannel {
  RecorderChannel({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _methodChannel = methodChannel ?? const MethodChannel(methodChannelName),
      _eventChannel = eventChannel ?? const EventChannel(eventChannelName) {
    _methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  static const String methodChannelName = 'com.learnese.app/recorder';
  static const String eventChannelName = 'com.learnese.app/recorder_events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final StreamController<void> _openActiveSessionController =
      StreamController<void>.broadcast();

  Stream<RecordingState>? _stateStream;

  /// Emits whenever the user taps the ongoing recording notification while the app is open.
  Stream<void> get onOpenActiveSession => _openActiveSessionController.stream;

  /// Live stream of native recording state, buffered duration, saved clip events, and errors.
  Stream<RecordingState> get stateStream {
    return _stateStream ??= _eventChannel.receiveBroadcastStream().map((
      Object? event,
    ) {
      if (event is Map<Object?, Object?>) {
        return RecordingState.fromMap(event);
      }
      return const RecordingState.idle();
    });
  }

  /// Requests MediaProjection consent and starts the rolling capture session.
  /// Returns `true` if started, or `false` if the user cancelled/denied consent.
  Future<bool> startSession({
    required int bufferSeconds,
    String? outputDir,
  }) async {
    if (bufferSeconds < RecordingSession.minBufferSeconds ||
        bufferSeconds > RecordingSession.maxBufferSeconds) {
      throw RangeError.range(
        bufferSeconds,
        RecordingSession.minBufferSeconds,
        RecordingSession.maxBufferSeconds,
        'bufferSeconds',
      );
    }
    final args = <String, Object?>{
      'bufferSeconds': bufferSeconds,
      if (outputDir != null && outputDir.trim().isNotEmpty)
        'outputDir': outputDir,
    };
    final started = await _methodChannel.invokeMethod<bool>(
      'startSession',
      args,
    );
    return started ?? false;
  }

  /// Snapshots the rolling buffer and saves it to a new .wav clip.
  Future<SavedClipResult?> saveClip() async {
    final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'saveClip',
    );
    if (result == null) {
      return null;
    }
    return SavedClipResult.fromMap(result);
  }

  /// Stops capture, flushes any in-flight save, wipes the RAM buffer, and ends the session.
  Future<bool> stopSession() async {
    final stopped = await _methodChannel.invokeMethod<bool>('stopSession');
    return stopped ?? false;
  }

  /// Fetches the latest native recording state snapshot.
  Future<RecordingState> getState() async {
    final map = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'getState',
    );
    if (map == null) {
      return const RecordingState.idle();
    }
    return RecordingState.fromMap(map);
  }

  /// Checks and clears any pending cold-launch deep link from tapping the recording notification.
  Future<bool> consumeOpenActiveSession() async {
    final pending = await _methodChannel.invokeMethod<bool>(
      'consumeOpenActiveSession',
    );
    return pending ?? false;
  }

  /// Queries Android's Settings.canDrawOverlays() directly.
  Future<bool> hasOverlayPermission() async {
    final granted = await _methodChannel.invokeMethod<bool>(
      'hasOverlayPermission',
    );
    return granted ?? false;
  }

  /// Opens Android's "Display over other apps" settings screen directly for Learnese.
  Future<bool> openOverlayPermissionSettings() async {
    final opened = await _methodChannel.invokeMethod<bool>(
      'openOverlayPermissionSettings',
    );
    return opened ?? false;
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onOpenActiveSession' &&
        !_openActiveSessionController.isClosed) {
      _openActiveSessionController.add(null);
    }
    return null;
  }

  Future<void> dispose() async {
    _methodChannel.setMethodCallHandler(null);
    await _openActiveSessionController.close();
  }
}
