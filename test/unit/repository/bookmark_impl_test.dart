import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_impl.dart';
import 'package:keek_news/service/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

const _storageKey = 'bookmarks';

void main() {
  late MockLocalStorageService storage;
  late BookmarkImpl repo;

  Bookmark bookmark({
    CommunityId community = CommunityId.humoruniv,
    String id = '1',
    String title = 't',
    String url = 'u',
  }) {
    return Bookmark(
      community: community,
      id: id,
      title: title,
      url: url,
      savedAt: DateTime.fromMillisecondsSinceEpoch(1722324000000),
    );
  }

  String encodeAll(List<Bookmark> all) =>
      jsonEncode(all.map((b) => b.toJson()).toList());

  setUp(() {
    storage = MockLocalStorageService();
    repo = BookmarkImpl(storage);
  });

  group('BookmarkImpl getAll', () {
    test('should decode stored JSON into bookmarks', () async {
      final b = bookmark(title: 'first');
      when(() => storage.getString(_storageKey)).thenReturn(encodeAll([b]));

      final result = await repo.getAll();

      expect(result.length, 1);
      expect(result[0].title, 'first');
    });

    test('should return empty list when storage empty', () async {
      when(() => storage.getString(_storageKey)).thenReturn(null);

      final result = await repo.getAll();

      expect(result, isEmpty);
    });

    test('should skip malformed entries silently', () async {
      final b = bookmark(title: 'good');
      when(() => storage.getString(_storageKey)).thenReturn(
        jsonEncode([
          b.toJson(),
          {'not': 'a bookmark'},
          'string instead of map',
        ]),
      );

      final result = await repo.getAll();

      expect(result.length, 1);
      expect(result[0].title, 'good');
    });
  });

  group('BookmarkImpl isBookmarked', () {
    test('should return true when composite key present', () async {
      final b = bookmark(community: CommunityId.humoruniv, id: '1');
      when(() => storage.getString(_storageKey)).thenReturn(encodeAll([b]));

      final result = await repo.isBookmarked(CommunityId.humoruniv, '1');

      expect(result, isTrue);
    });

    test('should return false when composite key absent', () async {
      final b = bookmark(community: CommunityId.humoruniv, id: '1');
      when(() => storage.getString(_storageKey)).thenReturn(encodeAll([b]));

      final result = await repo.isBookmarked(CommunityId.humoruniv, '99');

      expect(result, isFalse);
    });

    test('should build composite key as community:id', () async {
      final b = bookmark(community: CommunityId.dogdrip, id: '42');
      when(() => storage.getString(_storageKey)).thenReturn(encodeAll([b]));

      await repo.isBookmarked(CommunityId.dogdrip, '42');

      verify(() => storage.getString(_storageKey)).called(1);
    });
  });

  group('BookmarkImpl add', () {
    test('should prepend new bookmark and persist as JSON', () async {
      final existing = bookmark(id: '2', title: 'old');
      final incoming = bookmark(id: '1', title: 'new');
      when(
        () => storage.getString(_storageKey),
      ).thenReturn(encodeAll([existing]));
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      await repo.add(incoming);

      final captured =
          verify(
                () => storage.setString(_storageKey, captureAny()),
              ).captured.single
              as String;
      final decoded = (jsonDecode(captured) as List)
          .cast<Map<String, dynamic>>();
      final persisted = decoded.map(Bookmark.fromJson).toList();
      expect(persisted.first.id, '1');
      expect(persisted.first.title, 'new');
      expect(persisted.length, 2);
    });

    test('should replace existing bookmark with same key', () async {
      final existing = bookmark(id: '1', title: 'old');
      final incoming = bookmark(id: '1', title: 'updated');
      when(
        () => storage.getString(_storageKey),
      ).thenReturn(encodeAll([existing]));
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      await repo.add(incoming);

      final captured =
          verify(
                () => storage.setString(_storageKey, captureAny()),
              ).captured.single
              as String;
      final decoded = (jsonDecode(captured) as List)
          .cast<Map<String, dynamic>>();
      final persisted = decoded.map(Bookmark.fromJson).toList();
      expect(persisted.length, 1);
      expect(persisted.first.title, 'updated');
    });
  });

  group('BookmarkImpl remove', () {
    test('should remove matching composite key and persist', () async {
      final keep = bookmark(id: '2', title: 'keep');
      final drop = bookmark(id: '7', title: 'drop');
      when(
        () => storage.getString(_storageKey),
      ).thenReturn(encodeAll([keep, drop]));
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      await repo.remove(CommunityId.humoruniv, '7');

      final captured =
          verify(
                () => storage.setString(_storageKey, captureAny()),
              ).captured.single
              as String;
      final decoded = (jsonDecode(captured) as List)
          .cast<Map<String, dynamic>>();
      final persisted = decoded.map(Bookmark.fromJson).toList();
      expect(persisted.length, 1);
      expect(persisted.first.id, '2');
    });

    test('should be no-op when key absent', () async {
      final keep = bookmark(id: '2', title: 'keep');
      when(() => storage.getString(_storageKey)).thenReturn(encodeAll([keep]));
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      await repo.remove(CommunityId.humoruniv, '99');

      final captured =
          verify(
                () => storage.setString(_storageKey, captureAny()),
              ).captured.single
              as String;
      final decoded = (jsonDecode(captured) as List)
          .cast<Map<String, dynamic>>();
      expect(decoded.length, 1);
    });
  });
}
