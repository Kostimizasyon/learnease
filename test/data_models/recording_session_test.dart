import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/recording_session.dart';

void main() {
  group('RecordingSession', () {
    final startedAt = DateTime(2026, 1, 31, 14, 5);
    final endedAt = DateTime(2026, 1, 31, 14, 20);

    test('create uses S-DD:MM:YY default name and active state', () {
      final session = RecordingSession.create(
        bufferSeconds: 30,
        startedAt: startedAt,
      );

      expect(session.id, isNull);
      expect(session.name, 'S-31:01:26');
      expect(
        RecordingSession.defaultName(DateTime(2026, 4, 5, 9, 0)),
        'S-05:04:26',
      );
      expect(RecordingSession.presetBufferSeconds, <int>[5, 10, 15, 30, 60]);
      expect(session.startedAt, startedAt);
      expect(session.endedAt, isNull);
      expect(session.bufferSeconds, 30);
      expect(session.folderId, isNull);
      expect(session.isActive, isTrue);
      expect(session.duration, isNull);
    });

    test('create trims explicit name and falls back on blank name', () {
      final named = RecordingSession.create(
        bufferSeconds: 15,
        name: '  Podcast Notes  ',
        startedAt: startedAt,
      );
      final blank = RecordingSession.create(
        bufferSeconds: 15,
        name: '   ',
        startedAt: startedAt,
      );

      expect(named.name, 'Podcast Notes');
      expect(blank.name, 'S-31:01:26');
    });

    test('create rejects out-of-range bufferSeconds', () {
      expect(() => RecordingSession.create(bufferSeconds: 0), throwsRangeError);
      expect(
        () => RecordingSession.create(
          bufferSeconds: RecordingSession.maxBufferSeconds + 1,
        ),
        throwsRangeError,
      );
    });

    test('toMap and fromMap round-trip active and finished sessions', () {
      final active = RecordingSession.create(
        bufferSeconds: 60,
        startedAt: startedAt,
      );
      final activeMap = active.toMap();
      expect(activeMap.containsKey('id'), isFalse);
      expect(activeMap['ended_at'], isNull);
      expect(RecordingSession.fromMap(activeMap), active);

      final finished = RecordingSession(
        id: 7,
        name: 'Lecture 1',
        startedAt: startedAt,
        endedAt: endedAt,
        bufferSeconds: 120,
        folderId: 3,
      );
      final finishedMap = finished.toMap();
      expect(finishedMap['id'], 7);
      expect(finishedMap['folder_id'], 3);
      expect(RecordingSession.fromMap(finishedMap), finished);
      expect(finished.isActive, isFalse);
      expect(finished.duration, const Duration(minutes: 15));
    });

    test('fromMap rejects out-of-range buffer_seconds', () {
      expect(
        () => RecordingSession.fromMap(<String, Object?>{
          'id': 1,
          'name': 'Bad',
          'started_at': startedAt.millisecondsSinceEpoch,
          'ended_at': null,
          'buffer_seconds': 999,
          'folder_id': null,
        }),
        throwsRangeError,
      );
    });

    test('copyWith updates fields and clears nullable fields', () {
      final session = RecordingSession(
        id: 2,
        name: 'Original',
        startedAt: startedAt,
        endedAt: endedAt,
        bufferSeconds: 30,
        folderId: 5,
      );

      final movedToRoot = session.copyWith(
        name: 'Renamed',
        clearFolderId: true,
        clearEndedAt: true,
      );
      expect(movedToRoot.id, 2);
      expect(movedToRoot.name, 'Renamed');
      expect(movedToRoot.folderId, isNull);
      expect(movedToRoot.endedAt, isNull);
      expect(movedToRoot.isActive, isTrue);

      final finished = movedToRoot.finish(endedAt: endedAt);
      expect(finished.isActive, isFalse);
      expect(finished.endedAt, endedAt);
    });

    test('equality and hashCode compare all fields', () {
      final a = RecordingSession(
        id: 1,
        name: 'S1',
        startedAt: startedAt,
        bufferSeconds: 30,
      );
      final b = RecordingSession(
        id: 1,
        name: 'S1',
        startedAt: startedAt,
        bufferSeconds: 30,
      );
      final c = a.copyWith(name: 'S2');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
