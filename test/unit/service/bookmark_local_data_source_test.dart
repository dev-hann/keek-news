import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/service/bookmark_local_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late BookmarkLocalDataSource dataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dataSource = BookmarkLocalDataSourceImpl(prefs);
  });

  Bookmark bookmark({
    CommunityId community = CommunityId.humoruniv,
    String id = '1',
    String title = 't',
    String url = 'u',
    int savedAtMillis = 1722324000000,
  }) {
    return Bookmark(
      community: community,
      id: id,
      title: title,
      url: url,
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMillis),
    );
  }

  group('BookmarkLocalDataSource getAll', () {
    test('should return empty list when no stored value', () async {
      final result = await dataSource.getAll();

      expect(result, isEmpty);
    });

    test('should return parsed bookmarks from stored JSON list', () async {
      final b = bookmark(id: '100', title: '제목');
      await prefs.setString(
        BookmarkLocalDataSourceImpl.storageKey,
        jsonEncode([b.toJson()]),
      );

      final result = await dataSource.getAll();

      expect(result.length, 1);
      expect(result.first.id, '100');
      expect(result.first.title, '제목');
    });

    test('should return multiple bookmarks in stored order', () async {
      final a = bookmark(savedAtMillis: 1000);
      final b = bookmark(id: '2', savedAtMillis: 2000);
      await prefs.setString(
        BookmarkLocalDataSourceImpl.storageKey,
        jsonEncode([a.toJson(), b.toJson()]),
      );

      final result = await dataSource.getAll();

      expect(result.length, 2);
      expect(result[0].id, '1');
      expect(result[1].id, '2');
    });

    test('should return empty list when stored JSON is corrupted', () async {
      await prefs.setString(
        BookmarkLocalDataSourceImpl.storageKey,
        'not-valid-json',
      );

      final result = await dataSource.getAll();

      expect(result, isEmpty);
    });

    test('should skip entries that fail to parse', () async {
      final valid = bookmark().toJson();
      final broken = <String, dynamic>{'community': 'not_a_community'};
      await prefs.setString(
        BookmarkLocalDataSourceImpl.storageKey,
        jsonEncode([valid, broken]),
      );

      final result = await dataSource.getAll();

      expect(result.length, 1);
      expect(result.first.id, '1');
    });
  });

  group('BookmarkLocalDataSource exists', () {
    test('should return true when key present', () async {
      final b = bookmark(id: '42');
      await dataSource.upsert(b);

      final exists = await dataSource.exists('humoruniv:42');

      expect(exists, isTrue);
    });

    test('should return false when key absent', () async {
      final exists = await dataSource.exists('humoruniv:99');

      expect(exists, isFalse);
    });

    test('should distinguish keys across communities', () async {
      final b = bookmark();
      await dataSource.upsert(b);

      expect(await dataSource.exists('humoruniv:1'), isTrue);
      expect(await dataSource.exists('todayhumor:1'), isFalse);
    });
  });

  group('BookmarkLocalDataSource upsert', () {
    test('should add new bookmark to empty storage', () async {
      final b = bookmark();

      await dataSource.upsert(b);

      final result = await dataSource.getAll();
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test(
      'should update existing bookmark with same key without duplicating',
      () async {
        final original = bookmark(title: 'old');
        await dataSource.upsert(original);

        final updated = bookmark(title: 'new');
        await dataSource.upsert(updated);

        final result = await dataSource.getAll();
        expect(result.length, 1);
        expect(result.first.title, 'new');
      },
    );

    test(
      'should place new bookmark at front (most-recent-saved-first)',
      () async {
        await dataSource.upsert(bookmark(savedAtMillis: 1000));
        await dataSource.upsert(bookmark(id: '2', savedAtMillis: 2000));

        final result = await dataSource.getAll();
        expect(result.first.id, '2');
        expect(result.last.id, '1');
      },
    );

    test('should move updated bookmark to front', () async {
      await dataSource.upsert(bookmark(savedAtMillis: 1000));
      await dataSource.upsert(bookmark(id: '2', savedAtMillis: 2000));
      await dataSource.upsert(
        bookmark(savedAtMillis: 3000, title: 'refreshed'),
      );

      final result = await dataSource.getAll();
      expect(result.first.id, '1');
      expect(result.first.title, 'refreshed');
      expect(result.last.id, '2');
    });

    test('should preserve other bookmarks when adding new one', () async {
      await dataSource.upsert(bookmark());
      await dataSource.upsert(bookmark(id: '2'));

      final result = await dataSource.getAll();
      expect(result.length, 2);
    });

    test('should persist across instances', () async {
      final b = bookmark();
      await dataSource.upsert(b);

      final fresh = BookmarkLocalDataSourceImpl(prefs);
      final result = await fresh.getAll();

      expect(result.length, 1);
      expect(result.first.id, '1');
    });
  });

  group('BookmarkLocalDataSource remove', () {
    test('should delete bookmark by key', () async {
      await dataSource.upsert(bookmark());
      await dataSource.upsert(bookmark(id: '2'));

      await dataSource.remove('humoruniv:1');

      final result = await dataSource.getAll();
      expect(result.length, 1);
      expect(result.first.id, '2');
    });

    test('should be no-op when key absent', () async {
      await dataSource.upsert(bookmark());

      await dataSource.remove('humoruniv:99');

      final result = await dataSource.getAll();
      expect(result.length, 1);
    });
  });
}
