import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/recording_state.dart';
import 'package:learnese/services/recorder_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecorderChannel', () {
    const methodChannel = MethodChannel(RecorderChannel.methodChannelName);
    const eventChannel = EventChannel(RecorderChannel.eventChannelName);
    late RecorderChannel recorderChannel;
    late List<MethodCall> recordedCalls;

    setUp(() {
      recordedCalls = <MethodCall>[];
      recorderChannel = RecorderChannel(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
    });

    tearDown(() async {
      await recorderChannel.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('startSession validates bufferSeconds and sends arguments', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            recordedCalls.add(call);
            return true;
          });

      final started = await recorderChannel.startSession(
        bufferSeconds: 45,
        outputDir: '/data/clips/session_1',
      );

      expect(started, isTrue);
      expect(recordedCalls.single.method, 'startSession');
      expect(recordedCalls.single.arguments, <String, Object?>{
        'bufferSeconds': 45,
        'outputDir': '/data/clips/session_1',
      });

      await expectLater(
        recorderChannel.startSession(bufferSeconds: 0),
        throwsRangeError,
      );
      await expectLater(
        recorderChannel.startSession(bufferSeconds: 181),
        throwsRangeError,
      );
    });

    test(
      'startSession returns false when projection consent is denied',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
              return false;
            });

        expect(await recorderChannel.startSession(bufferSeconds: 30), isFalse);
      },
    );

    test('saveClip parses SavedClipResult from native map', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            recordedCalls.add(call);
            return <String, Object?>{
              'filePath': '/data/clips/session_1/clip_1000.wav',
              'durationMs': 15250,
              'sizeBytes': 1345094,
            };
          });

      final saved = await recorderChannel.saveClip();

      expect(recordedCalls.single.method, 'saveClip');
      expect(
        saved,
        const SavedClipResult(
          filePath: '/data/clips/session_1/clip_1000.wav',
          durationMs: 15250,
          sizeBytes: 1345094,
        ),
      );
    });

    test('stopSession, getState, consumeOpenActiveSession, and overlay methods invoke native', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            recordedCalls.add(call);
            return switch (call.method) {
              'stopSession' => true,
              'consumeOpenActiveSession' => true,
              'hasOverlayPermission' => true,
              'openOverlayPermissionSettings' => true,
              'getState' => <String, Object?>{
                'sessionState': 'active',
                'bufferedMs': 9000,
                'bufferSeconds': 30,
                'error': 'none',
              },
              _ => null,
            };
          });

      expect(await recorderChannel.stopSession(), isTrue);
      expect(await recorderChannel.consumeOpenActiveSession(), isTrue);
      expect(await recorderChannel.hasOverlayPermission(), isTrue);
      expect(await recorderChannel.openOverlayPermissionSettings(), isTrue);
      final state = await recorderChannel.getState();
      expect(state.isActive, isTrue);
      expect(state.bufferedMs, 9000);
      expect(state.bufferSeconds, 30);
    });

    test(
      'stateStream decodes EventChannel payloads into RecordingState',
      () async {
        MockStreamHandlerEventSink? capturedSink;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(
              eventChannel,
              MockStreamHandler.inline(
                onListen: (Object? args, MockStreamHandlerEventSink events) {
                  capturedSink = events;
                },
              ),
            );

        final received = <RecordingState>[];
        final sub = recorderChannel.stateStream.listen(received.add);
        await pumpEventQueue();

        capturedSink!.success(<String, Object?>{
          'sessionState': 'active',
          'bufferedMs': 5000,
          'bufferSeconds': 30,
        });
        capturedSink!.success(<String, Object?>{
          'sessionState': 'active',
          'bufferedMs': 10000,
          'bufferSeconds': 30,
          'lastSavedClipPath': '/clips/clip_1.wav',
          'lastSavedClipDurationMs': 10000,
          'lastSavedClipSizeBytes': 882044,
        });
        capturedSink!.success(<String, Object?>{
          'sessionState': 'idle',
          'bufferedMs': 0,
          'bufferSeconds': 0,
          'error': 'projection_revoked',
          'errorMessage': 'Revoked',
        });
        await pumpEventQueue();
        await sub.cancel();

        expect(received, hasLength(3));
        expect(received[0].isActive, isTrue);
        expect(received[0].bufferedMs, 5000);
        expect(received[1].lastSavedClipPath, '/clips/clip_1.wav');
        expect(received[2].isIdle, isTrue);
        expect(received[2].error, CaptureError.projectionRevoked);
      },
    );

    test('onOpenActiveSession emits when native calls back', () async {
      var firedCount = 0;
      final sub = recorderChannel.onOpenActiveSession.listen((_) {
        firedCount++;
      });

      const codec = StandardMethodCodec();
      final encoded = codec.encodeMethodCall(
        const MethodCall('onOpenActiveSession'),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            RecorderChannel.methodChannelName,
            encoded,
            (_) {},
          );
      await pumpEventQueue();
      await sub.cancel();

      expect(firedCount, 1);
    });
  });
}
