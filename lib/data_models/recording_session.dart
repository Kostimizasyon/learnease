import 'package:flutter/foundation.dart';

@immutable
class RecordingSession {
  const RecordingSession({
    this.id,
    required this.name,
    required this.startedAt,
    this.endedAt,
    required this.bufferSeconds,
    this.folderId,
  }) : assert(
         bufferSeconds >= minBufferSeconds && bufferSeconds <= maxBufferSeconds,
         'bufferSeconds must be between $minBufferSeconds and $maxBufferSeconds.',
       );

  factory RecordingSession.create({
    required int bufferSeconds,
    String? name,
    DateTime? startedAt,
    int? folderId,
  }) {
    if (bufferSeconds < minBufferSeconds || bufferSeconds > maxBufferSeconds) {
      throw RangeError.range(
        bufferSeconds,
        minBufferSeconds,
        maxBufferSeconds,
        'bufferSeconds',
      );
    }
    final normalizedStart = _truncateToMillis(startedAt ?? DateTime.now());
    final resolvedName = (name == null || name.trim().isEmpty)
        ? defaultName(normalizedStart)
        : name.trim();
    return RecordingSession(
      name: resolvedName,
      startedAt: normalizedStart,
      bufferSeconds: bufferSeconds,
      folderId: folderId,
    );
  }

  factory RecordingSession.fromMap(Map<String, Object?> map) {
    final bufferSeconds = (map['buffer_seconds'] as num).toInt();
    if (bufferSeconds < minBufferSeconds || bufferSeconds > maxBufferSeconds) {
      throw RangeError.range(
        bufferSeconds,
        minBufferSeconds,
        maxBufferSeconds,
        'buffer_seconds',
      );
    }
    final endedAtMs = map['ended_at'] as num?;
    return RecordingSession(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['started_at'] as num).toInt(),
      ),
      endedAt: endedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endedAtMs.toInt()),
      bufferSeconds: bufferSeconds,
      folderId: (map['folder_id'] as num?)?.toInt(),
    );
  }

  static const int minBufferSeconds = 1;
  static const int maxBufferSeconds = 180;
  static const int defaultBufferSeconds = 30;
  static const List<int> presetBufferSeconds = <int>[5, 10, 15, 30, 60];

  final int? id;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int bufferSeconds;
  final int? folderId;

  bool get isActive => endedAt == null;

  Duration? get duration => endedAt?.difference(startedAt);

  static String defaultName(DateTime timestamp) {
    final d = timestamp.day.toString().padLeft(2, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    final y = (timestamp.year % 100).toString().padLeft(2, '0');
    return 'S-$d:$m:$y';
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'buffer_seconds': bufferSeconds,
      'folder_id': folderId,
    };
  }

  RecordingSession copyWith({
    int? id,
    String? name,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    int? bufferSeconds,
    int? folderId,
    bool clearFolderId = false,
  }) {
    final nextBufferSeconds = bufferSeconds ?? this.bufferSeconds;
    if (nextBufferSeconds < minBufferSeconds ||
        nextBufferSeconds > maxBufferSeconds) {
      throw RangeError.range(
        nextBufferSeconds,
        minBufferSeconds,
        maxBufferSeconds,
        'bufferSeconds',
      );
    }
    return RecordingSession(
      id: id ?? this.id,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      bufferSeconds: nextBufferSeconds,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
    );
  }

  RecordingSession finish({DateTime? endedAt}) {
    return copyWith(endedAt: _truncateToMillis(endedAt ?? DateTime.now()));
  }

  static DateTime _truncateToMillis(DateTime value) {
    return DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RecordingSession &&
            other.id == id &&
            other.name == name &&
            other.startedAt == startedAt &&
            other.endedAt == endedAt &&
            other.bufferSeconds == bufferSeconds &&
            other.folderId == folderId);
  }

  @override
  int get hashCode =>
      Object.hash(id, name, startedAt, endedAt, bufferSeconds, folderId);

  @override
  String toString() {
    return 'RecordingSession(id: $id, name: $name, startedAt: $startedAt, '
        'endedAt: $endedAt, bufferSeconds: $bufferSeconds, folderId: $folderId)';
  }
}
