import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/recording_state.dart';

void main() {
  group('RecordingState', () {
    test('idle named constructor sets clean defaults', () {
      const state = RecordingState.idle();

      expect(state.sessionState, SessionStatus.idle);
      expect(state.isIdle, isTrue);
      expect(state.isActive, isFalse);
      expect(state.bufferedMs, 0);
      expect(state.bufferSeconds, 0);
      expect(state.bufferFillFraction, 0);
      expect(state.hasSavedClip, isFalse);
      expect(state.hasError, isFalse);
    });

    test('active named constructor computes clamped bufferFillFraction', () {
      const half = RecordingState.active(bufferedMs: 15000, bufferSeconds: 30);
      const over = RecordingState.active(bufferedMs: 35000, bufferSeconds: 30);

      expect(half.isActive, isTrue);
      expect(half.bufferFillFraction, 0.5);
      expect(over.bufferFillFraction, 1.0);
    });

    test('error named constructor captures error metadata', () {
      const state = RecordingState.error(
        error: CaptureError.projectionDenied,
        errorMessage: 'User cancelled media projection dialog.',
      );

      expect(state.isIdle, isTrue);
      expect(state.hasError, isTrue);
      expect(state.error, CaptureError.projectionDenied);
      expect(state.errorMessage, 'User cancelled media projection dialog.');
    });

    test('fromMap parses minimal EventChannel payload and round-trips', () {
      final minimal = RecordingState.fromMap(<Object?, Object?>{
        'sessionState': 'active',
        'bufferedMs': 12345,
        'lastSavedClipPath': '/clips/c1.wav',
      });

      expect(minimal.sessionState, SessionStatus.active);
      expect(minimal.bufferedMs, 12345);
      expect(minimal.hasSavedClip, isTrue);
      expect(minimal.lastSavedClipPath, '/clips/c1.wav');
      expect(minimal.error, CaptureError.none);

      final roundTripped = RecordingState.fromMap(minimal.toMap());
      expect(roundTripped, minimal);
    });

    test(
      'fromMap clamps negative values and maps known/unknown errors safely',
      () {
        final overlayError = RecordingState.fromMap(<Object?, Object?>{
          'sessionState': 'idle',
          'bufferedMs': 0,
          'error': 'overlay_permission_denied',
        });
        expect(overlayError.error, CaptureError.overlayPermissionDenied);

        final parsed = RecordingState.fromMap(<Object?, Object?>{
          'sessionState': 'unexpected_value',
          'bufferedMs': -500,
          'bufferSeconds': -10,
          'error': 'some_future_error',
        });

        expect(parsed.sessionState, SessionStatus.idle);
        expect(parsed.bufferedMs, 0);
        expect(parsed.bufferSeconds, 0);
        expect(parsed.error, CaptureError.unknown);
      },
    );

    test('copyWith clears saved clip and error cleanly', () {
      const initial = RecordingState(
        sessionState: SessionStatus.active,
        bufferedMs: 20000,
        bufferSeconds: 30,
        lastSavedClipPath: '/clips/a.wav',
        lastSavedClipDurationMs: 20000,
        lastSavedClipSizeBytes: 99000,
        error: CaptureError.encodingFailed,
        errorMessage: 'Disk full',
      );

      final cleared = initial.copyWith(
        clearLastSavedClip: true,
        clearError: true,
      );

      expect(cleared.isActive, isTrue);
      expect(cleared.bufferedMs, 20000);
      expect(cleared.lastSavedClipPath, isNull);
      expect(cleared.lastSavedClipDurationMs, isNull);
      expect(cleared.lastSavedClipSizeBytes, isNull);
      expect(cleared.hasSavedClip, isFalse);
      expect(cleared.error, CaptureError.none);
      expect(cleared.errorMessage, isNull);
      expect(cleared.hasError, isFalse);
    });
  });
}
