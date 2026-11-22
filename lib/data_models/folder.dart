import 'package:flutter/foundation.dart';

@immutable
class Folder {
  const Folder({
    this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
  });

  factory Folder.root({int? id, required String name, DateTime? createdAt}) {
    return Folder(
      id: id,
      name: _validateName(name),
      createdAt: _truncateToMillis(createdAt ?? DateTime.now()),
    );
  }

  factory Folder.nested({
    int? id,
    required String name,
    required int parentId,
    DateTime? createdAt,
  }) {
    return Folder(
      id: id,
      name: _validateName(name),
      parentId: parentId,
      createdAt: _truncateToMillis(createdAt ?? DateTime.now()),
    );
  }

  factory Folder.fromMap(Map<String, Object?> map) {
    return Folder(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String,
      parentId: (map['parent_id'] as num?)?.toInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
    );
  }

  final int? id;
  final String name;
  final int? parentId;
  final DateTime createdAt;

  bool get isRoot => parentId == null;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'parent_id': parentId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Folder copyWith({
    int? id,
    String? name,
    int? parentId,
    bool clearParentId = false,
    DateTime? createdAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name != null ? _validateName(name) : this.name,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _validateName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(raw, 'name', 'Folder name cannot be empty.');
    }
    return trimmed;
  }

  static DateTime _truncateToMillis(DateTime value) {
    return DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Folder &&
            other.id == id &&
            other.name == name &&
            other.parentId == parentId &&
            other.createdAt == createdAt);
  }

  @override
  int get hashCode => Object.hash(id, name, parentId, createdAt);

  @override
  String toString() {
    return 'Folder(id: $id, name: $name, parentId: $parentId, '
        'createdAt: $createdAt)';
  }
}
