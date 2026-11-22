import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data_models/audio_clip.dart';
import '../data_models/recording_session.dart';
import '../data_models/recording_state.dart';
import 'permission_service.dart';
import 'preferences_service.dart';
import 'recorder_channel.dart';
import 'session_repository.dart';
import 'storage_service.dart';

/// Coordinates native recording state, SQLite session/clip persistence,
/// storage paths, and user preferences using standard [ChangeNotifier].
class SessionController extends ChangeNotifier {
  SessionController({
    required this._recorderChannel,
    required this._sessionRepository,
    required this._storageService,
    required this._preferencesService,
    required this._permissionService,
    this.onNavigateToActiveSession,
  });

  final RecorderChannel _recorderChannel;
  final SessionRepository _sessionRepository;
  final StorageService _storageService;
  final PreferencesService _preferencesService;
  final PermissionService _permissionService;

  /// Optional hook invoked when tapping the ongoing Android notification.
  VoidCallback? onNavigateToActiveSession;

  StreamSubscription<RecordingState>? _stateSubscription;
  StreamSubscription<void>? _openSessionSubscription;
  final Set<String> _persistedClipPaths = <String>{};
  Future<void> _eventQueue = Future<void>.value();

  RecordingState _recordingState = const RecordingState.idle();
  RecordingSession? _activeSession;
  int _activeClipCount = 0;
  int _selectedBufferSeconds = RecordingSession.defaultBufferSeconds;
  bool _initialized = false;
  bool _isBusy = false;
  bool _disposed = false;
  String? _statusMessage;

  RecordingState get recordingState => _recordingState;
  RecordingSession? get activeSession => _activeSession;
  int get activeClipCount => _activeClipCount;
  int get selectedBufferSeconds => _selectedBufferSeconds;
  bool get isInitialized => _initialized;
  bool get isBusy => _isBusy;
  bool get isSessionActive =>
      _recordingState.isActive || _activeSession != null;
  String? get statusMessage => _statusMessage;

  PermissionService get permissionService => _permissionService;
  RecorderChannel get recorderChannel => _recorderChannel;

  Future<void> initialize() async {
    if (_initialized) return;

    _stateSubscription = _recorderChannel.stateStream.listen(_enqueueEvent);
    _openSessionSubscription = _recorderChannel.onOpenActiveSession.listen((_) {
      onNavigateToActiveSession?.call();
    });

    _selectedBufferSeconds = await _preferencesService.getLastBufferSeconds();

    try {
      final nativeState = await _recorderChannel.getState();
      _recordingState = nativeState;

      final dbActive = await _sessionRepository.getActiveSession();
      if (nativeState.isActive) {
        if (dbActive != null) {
          _activeSession = dbActive;
          final existingClips = await _sessionRepository.listClipsForSession(
            dbActive.id!,
          );
          _activeClipCount = existingClips.length;
          _persistedClipPaths.addAll(existingClips.map((c) => c.filePath));
        } else {
          // Native service is active without a DB row (e.g. restored state); create one.
          final seconds = nativeState.bufferSeconds > 0
              ? nativeState.bufferSeconds.clamp(
                  RecordingSession.minBufferSeconds,
                  RecordingSession.maxBufferSeconds,
                )
              : _selectedBufferSeconds;
          _activeSession = await _sessionRepository.createSession(
            RecordingSession.create(bufferSeconds: seconds),
          );
          _activeClipCount = 0;
        }
      } else if (dbActive != null) {
        // Reconcile orphaned active session left behind if the OS killed the service.
        await _sessionRepository.endSession(dbActive.id!);
        _activeSession = null;
        _activeClipCount = 0;
      }

      if (await _recorderChannel.consumeOpenActiveSession()) {
        onNavigateToActiveSession?.call();
      }
    } catch (_) {
      // Allow UI to initialize cleanly even if native channel is unavailable in tests.
    }

    _initialized = true;
    _notifySafe();
  }

  Future<void> setBufferSeconds(int seconds) async {
    if (seconds < RecordingSession.minBufferSeconds ||
        seconds > RecordingSession.maxBufferSeconds) {
      throw RangeError.range(
        seconds,
        RecordingSession.minBufferSeconds,
        RecordingSession.maxBufferSeconds,
        'seconds',
      );
    }
    _selectedBufferSeconds = seconds;
    _notifySafe();
    await _preferencesService.setLastBufferSeconds(seconds);
  }

  Future<bool> hasRequiredPermissions() async {
    final result = await _permissionService.checkAll();
    if (result.audioGranted && result.overlayGranted) {
      return true;
    }
    if (result.audioGranted) {
      try {
        return await _recorderChannel.hasOverlayPermission();
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Creates the DB session, launches Android MediaProjection consent, and starts capture.
  /// Returns `true` if started, `false` if consent was denied or an error occurred.
  Future<bool> startSession() async {
    if (_isBusy || isSessionActive) return false;

    _isBusy = true;
    _statusMessage = null;
    _notifySafe();

    RecordingSession? createdSession;
    try {
      createdSession = await _sessionRepository.createSession(
        RecordingSession.create(bufferSeconds: _selectedBufferSeconds),
      );
      final outputDir = await _storageService.getSessionDirectory(
        createdSession.id!,
      );

      final started = await _recorderChannel.startSession(
        bufferSeconds: _selectedBufferSeconds,
        outputDir: outputDir.path,
      );

      if (!started) {
        await _sessionRepository.deleteSession(createdSession.id!);
        _statusMessage = 'Screen capture permission was cancelled.';
        return false;
      }

      _persistedClipPaths.clear();
      _activeSession = createdSession;
      _activeClipCount = 0;
      _recordingState = RecordingState.active(
        bufferedMs: 0,
        bufferSeconds: _selectedBufferSeconds,
      );
      return true;
    } on PlatformException catch (e) {
      if (createdSession != null) {
        await _sessionRepository.deleteSession(createdSession.id!);
      }
      _statusMessage = e.message ?? 'Could not start recording session.';
      return false;
    } catch (_) {
      if (createdSession != null) {
        await _sessionRepository.deleteSession(createdSession.id!);
      }
      _statusMessage = 'Could not start recording session.';
      return false;
    } finally {
      _isBusy = false;
      _notifySafe();
    }
  }

  /// Saves the current rolling buffer immediately from within the app.
  Future<AudioClip?> saveClipNow() async {
    if (_isBusy || !isSessionActive) return null;

    _isBusy = true;
    _statusMessage = null;
    _notifySafe();

    try {
      final result = await _recorderChannel.saveClip();
      if (result == null) {
        _statusMessage = 'No audio buffered yet.';
        return null;
      }
      return await _persistClipIfNew(
        filePath: result.filePath,
        durationMs: result.durationMs,
        sizeBytes: result.sizeBytes,
      );
    } on PlatformException catch (e) {
      _statusMessage = e.message ?? 'Could not save clip.';
      return null;
    } finally {
      _isBusy = false;
      _notifySafe();
    }
  }

  /// Stops capture, removes the floating overlay & notification, and marks the DB session ended.
  Future<void> stopSession() async {
    if (_isBusy) return;

    _isBusy = true;
    _statusMessage = null;
    _notifySafe();

    try {
      await _recorderChannel.stopSession();
      await _finalizeActiveSessionInDb();
      _recordingState = const RecordingState.idle();
    } on PlatformException catch (e) {
      _statusMessage = e.message ?? 'Failed to stop session cleanly.';
    } finally {
      _isBusy = false;
      _notifySafe();
    }
  }

  void clearStatusMessage() {
    if (_statusMessage == null) return;
    _statusMessage = null;
    _notifySafe();
  }

  void _enqueueEvent(RecordingState state) {
    _eventQueue = _eventQueue
        .then((_) => _handleStateEvent(state))
        .catchError((Object _, StackTrace _) {});
  }

  Future<void> _handleStateEvent(RecordingState state) async {
    final wasActive = _recordingState.isActive || _activeSession != null;
    _recordingState = state;

    if (state.hasSavedClip) {
      final path = state.lastSavedClipPath!;
      final durationMs = state.lastSavedClipDurationMs ?? state.bufferedMs;
      final sizeBytes =
          state.lastSavedClipSizeBytes ??
          await _storageService.fileSizeBytes(path);
      await _persistClipIfNew(
        filePath: path,
        durationMs: durationMs,
        sizeBytes: sizeBytes,
      );
    }

    if (state.isIdle && wasActive) {
      await _finalizeActiveSessionInDb();
      if (state.hasError) {
        _statusMessage = _friendlyErrorMessage(state);
      }
    } else if (state.hasError) {
      _statusMessage = _friendlyErrorMessage(state);
    }

    _notifySafe();
  }

  Future<AudioClip?> _persistClipIfNew({
    required String filePath,
    required int durationMs,
    required int sizeBytes,
  }) async {
    if (!_persistedClipPaths.add(filePath)) {
      return null;
    }

    final session =
        _activeSession ?? await _sessionRepository.getActiveSession();
    if (session == null || session.id == null) {
      return null;
    }
    _activeSession = session;

    final nextNumber = _activeClipCount + 1;
    final saved = await _sessionRepository.addClip(
      AudioClip.create(
        sessionId: session.id!,
        filePath: filePath,
        durationMs: durationMs < 0 ? 0 : durationMs,
        sizeBytes: sizeBytes < 0 ? 0 : sizeBytes,
        clipNumber: nextNumber,
      ),
    );
    _activeClipCount = nextNumber;
    return saved;
  }

  Future<void> _finalizeActiveSessionInDb() async {
    final session = _activeSession;
    _activeSession = null;
    _activeClipCount = 0;
    _persistedClipPaths.clear();
    if (session != null && session.id != null) {
      await _sessionRepository.endSession(session.id!);
    }
  }

  String _friendlyErrorMessage(RecordingState state) {
    if (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty) {
      return state.errorMessage!;
    }
    return switch (state.error) {
      CaptureError.projectionDenied => 'Screen capture consent was cancelled.',
      CaptureError.projectionRevoked =>
        'Screen capture was stopped by Android.',
      CaptureError.permissionDenied => 'Audio capture permission is missing.',
      CaptureError.overlayPermissionDenied =>
        'Display over other apps permission is required.',
      CaptureError.audioInitFailed =>
        'Could not initialize device audio capture.',
      CaptureError.encodingFailed => 'Failed to save audio clip.',
      CaptureError.storageError => 'Insufficient storage to save clip.',
      CaptureError.unknown => 'Recording stopped unexpectedly.',
      CaptureError.none => '',
    };
  }

  void _notifySafe() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSubscription?.cancel();
    _openSessionSubscription?.cancel();
    super.dispose();
  }
}
