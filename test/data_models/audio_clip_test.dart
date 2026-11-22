import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/audio_clip.dart';

void main() {
  group('AudioClip', () {
    final createdAt = DateTime(2026, 2, 10, 9, 30);

    test('create builds default name from clipNumber', () {
      final clip = AudioClip.create(
        sessionId: 4,
        filePath: '/data/user/0/com.learnese.app/files/clips/clip_1.wav',
        durationMs: 12500,
        sizeBytes: 102400,
        clipNumber: 2,
        createdAt: createdAt,
      );

      expect(clip.id, isNull);
      expect(clip.sessionId, 4);
      expect(clip.name, 'Clip 2');
      expect(clip.duration, const Duration(milliseconds: 12500));
      expect(clip.sizeBytes, 102400);
      expect(clip.createdAt, createdAt);
    });

    test('create supports partial-fill clips shorter than buffer length', () {
      final clip = AudioClip.create(
        sessionId: 1,
        filePath: '/clips/early.wav',
        durationMs: 3200,
        sizeBytes: 48000,
        name: '  Intro Quote  ',
        createdAt: createdAt,
      );

      expect(clip.name, 'Intro Quote');
      expect(clip.durationMs, 3200);
    });

    test('create rejects negative metrics or invalid clipNumber', () {
      expect(
        () => AudioClip.create(
          sessionId: 1,
          filePath: '/a.wav',
          durationMs: -1,
          sizeBytes: 100,
        ),
        throwsRangeError,
      );
      expect(
        () => AudioClip.create(
          sessionId: 1,
          filePath: '/a.wav',
          durationMs: 1000,
          sizeBytes: -5,
        ),
        throwsRangeError,
      );
      expect(
        () => AudioClip.create(
          sessionId: 1,
          filePath: '/a.wav',
          durationMs: 1000,
          sizeBytes: 100,
          clipNumber: 0,
        ),
        throwsRangeError,
      );
    });

    test('toMap and fromMap round-trip cleanly', () {
      final unsaved = AudioClip.create(
        sessionId: 9,
        filePath: '/clips/c1.wav',
        durationMs: 30000,
        sizeBytes: 240000,
        createdAt: createdAt,
      );
      final unsavedMap = unsaved.toMap();
      expect(unsavedMap.containsKey('id'), isFalse);
      expect(AudioClip.fromMap(unsavedMap), unsaved);

      final persisted = unsaved.copyWith(id: 42, name: 'Vocabulary');
      final persistedMap = persisted.toMap();
      expect(persistedMap['id'], 42);
      expect(AudioClip.fromMap(persistedMap), persisted);
    });

    test(
      'copyWith validates non-negative values and preserves other fields',
      () {
        final clip = AudioClip(
          id: 1,
          sessionId: 3,
          name: 'Clip 1',
          filePath: '/clips/1.wav',
          durationMs: 5000,
          sizeBytes: 12000,
          createdAt: createdAt,
        );

        final renamed = clip.copyWith(name: 'Key Phrase');
        expect(renamed.name, 'Key Phrase');
        expect(renamed.filePath, clip.filePath);
        expect(renamed, isNot(clip));

        expect(() => clip.copyWith(durationMs: -10), throwsRangeError);
        expect(() => clip.copyWith(sizeBytes: -1), throwsRangeError);
      },
    );
  });
}
