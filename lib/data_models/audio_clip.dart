import 'package:flutter/foundation.dart';

@immutable
class AudioClip {
  const AudioClip({
    this.id,
    required this.sessionId,
    required this.name,
    required this.filePath,
    required this.durationMs,
    required this.sizeBytes,
    required this.createdAt,
  }) : assert(durationMs >= 0, 'durationMs must be non-negative.'),
       assert(sizeBytes >= 0, 'sizeBytes must be non-negative.');

  factory AudioClip.create({
    required int sessionId,
    required String filePath,
    required int durationMs,
    required int sizeBytes,
    String? name,
    int clipNumber = 1,
    DateTime? createdAt,
  }) {
    if (durationMs < 0) {
      throw RangeError.value(durationMs, 'durationMs', 'must be non-negative');
    }
    if (sizeBytes < 0) {
      throw RangeError.value(sizeBytes, 'sizeBytes', 'must be non-negative');
    }
    if (clipNumber < 1) {
      throw RangeError.value(clipNumber, 'clipNumber', 'must be >= 1');
    }
    final normalizedCreatedAt = _truncateToMillis(createdAt ?? DateTime.now());
    final resolvedName = (name == null || name.trim().isEmpty)
        ? defaultName(clipNumber)
        : name.trim();
    return AudioClip(
      sessionId: sessionId,
      name: resolvedName,
      filePath: filePath,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
      createdAt: normalizedCreatedAt,
    );
  }

  factory AudioClip.fromMap(Map<String, Object?> map) {
    final durationMs = (map['duration_ms'] as num).toInt();
    final sizeBytes = (map['size_bytes'] as num).toInt();
    if (durationMs < 0) {
      throw RangeError.value(durationMs, 'duration_ms', 'must be non-negative');
    }
    if (sizeBytes < 0) {
      throw RangeError.value(sizeBytes, 'size_bytes', 'must be non-negative');
    }
    return AudioClip(
      id: (map['id'] as num?)?.toInt(),
      sessionId: (map['session_id'] as num).toInt(),
      name: map['name'] as String,
      filePath: map['file_path'] as String,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }

  final int? id;
  final int sessionId;
  final String name;
  final String filePath;
  final int durationMs;
  final int sizeBytes;
  final DateTime createdAt;

  Duration get duration => Duration(milliseconds: durationMs);

  static String defaultName(int clipNumber) => 'Clip $clipNumber';

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'session_id': sessionId,
      'name': name,
      'file_path': filePath,
      'duration_ms': durationMs,
      'size_bytes': sizeBytes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  AudioClip copyWith({
    int? id,
    int? sessionId,
    String? name,
    String? filePath,
    int? durationMs,
    int? sizeBytes,
    DateTime? createdAt,
  }) {
    final nextDuration = durationMs ?? this.durationMs;
    final nextSize = sizeBytes ?? this.sizeBytes;
    if (nextDuration < 0) {
      throw RangeError.value(
        nextDuration,
        'durationMs',
        'must be non-negative',
      );
    }
    if (nextSize < 0) {
      throw RangeError.value(nextSize, 'sizeBytes', 'must be non-negative');
    }
    return AudioClip(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      durationMs: nextDuration,
      sizeBytes: nextSize,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime _truncateToMillis(DateTime value) {
    return DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is AudioClip &&
            other.id == id &&
            other.sessionId == sessionId &&
            other.name == name &&
            other.filePath == filePath &&
            other.durationMs == durationMs &&
            other.sizeBytes == sizeBytes &&
            other.createdAt == createdAt);
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    name,
    filePath,
    durationMs,
    sizeBytes,
    createdAt,
  );

  @override
  String toString() {
    return 'AudioClip(id: $id, sessionId: $sessionId, name: $name, '
        'filePath: $filePath, durationMs: $durationMs, sizeBytes: $sizeBytes, '
        'createdAt: $createdAt)';
  }
}
