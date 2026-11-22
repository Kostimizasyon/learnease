import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/folder.dart';

void main() {
  group('Folder', () {
    final createdAt = DateTime(2026, 3, 1, 12, 0);

    test('Folder.root creates top-level folder with null parentId', () {
      final folder = Folder.root(name: '  Languages  ', createdAt: createdAt);

      expect(folder.id, isNull);
      expect(folder.name, 'Languages');
      expect(folder.parentId, isNull);
      expect(folder.isRoot, isTrue);
      expect(folder.createdAt, createdAt);
    });

    test('Folder.nested creates sub-folder bound to parentId', () {
      final sub = Folder.nested(
        id: 10,
        name: 'Japanese',
        parentId: 2,
        createdAt: createdAt,
      );

      expect(sub.id, 10);
      expect(sub.name, 'Japanese');
      expect(sub.parentId, 2);
      expect(sub.isRoot, isFalse);
    });

    test('named constructors reject empty names', () {
      expect(() => Folder.root(name: '   '), throwsArgumentError);
      expect(() => Folder.nested(name: '', parentId: 1), throwsArgumentError);
    });

    test('toMap and fromMap round-trip root and nested folders', () {
      final root = Folder.root(name: 'Podcasts', createdAt: createdAt);
      final rootMap = root.toMap();
      expect(rootMap.containsKey('id'), isFalse);
      expect(rootMap['parent_id'], isNull);
      expect(Folder.fromMap(rootMap), root);

      final nested = Folder.nested(
        id: 8,
        name: 'Season 2',
        parentId: 4,
        createdAt: createdAt,
      );
      final nestedMap = nested.toMap();
      expect(nestedMap['id'], 8);
      expect(nestedMap['parent_id'], 4);
      expect(Folder.fromMap(nestedMap), nested);
    });

    test('copyWith moves nested folder to root when clearParentId is true', () {
      final nested = Folder.nested(
        id: 11,
        name: 'Sub',
        parentId: 5,
        createdAt: createdAt,
      );

      final promoted = nested.copyWith(name: 'Promoted', clearParentId: true);
      expect(promoted.id, 11);
      expect(promoted.name, 'Promoted');
      expect(promoted.parentId, isNull);
      expect(promoted.isRoot, isTrue);

      expect(() => promoted.copyWith(name: '  '), throwsArgumentError);
    });
  });
}
