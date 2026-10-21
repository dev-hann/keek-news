import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/repository/blocked_image/blocked_image_impl.dart';
import 'package:keek_news/service/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

const _storageKey = 'blocked_images';

void main() {
  late MockLocalStorageService storage;
  late BlockedImageImpl repo;

  BlockedImage image(String url) => BlockedImage(
    url: url,
    blockedAt: DateTime.fromMillisecondsSinceEpoch(1722324000000),
  );

  String encodeAll(List<BlockedImage> all) =>
      jsonEncode(all.map((b) => b.toJson()).toList());

  setUp(() {
    storage = MockLocalStorageService();
    repo = BlockedImageImpl(storage);
  });

  group('BlockedImageImpl getAll', () {
    test('should decode stored JSON into images', () async {
      when(
        () => storage.getString(_storageKey),
      ).thenReturn(encodeAll([image('https://x/a.jpg')]));

      final result = await repo.getAll();

      expect(result.length, 1);
      expect(result[0].url, 'https://x/a.jpg');
    });

    test('should return empty list when storage empty', () async {
      when(() => storage.getString(_storageKey)).thenReturn(null);

      final result = await repo.getAll();

      expect(result, isEmpty);
    });

    test('should skip malformed entries silently', () async {
      when(() => storage.getString(_storageKey)).thenReturn(
        jsonEncode([
          image('https://x/good.jpg').toJson(),
          {'not': 'a blocked image'},
          'string instead of map',
        ]),
      );

      final result = await repo.getAll();

      expect(result.length, 1);
      expect(result[0].url, 'https://x/good.jpg');
    });
  });

  group('BlockedImageImpl add', () {
    test('should prepend and persist as JSON', () async {
      when(
        () => storage.getString(_storageKey),
      ).thenReturn(encodeAll([image('https://x/old.jpg')]));
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      await repo.add(image('https://x/new.jpg'));

      final captured =
          verify(
                () => storage.setString(_storageKey, captureAny()),
              ).captured.single
              as String;
      final persisted = (jsonDecode(captured) as List)
          .cast<Map<String, dynamic>>()
          .map(BlockedImage.fromJson)
          .toList();
      expect(persisted.first.url, 'https://x/new.jpg');
      expect(persisted.length, 2);
    });

    test('should replace existing entry with same url', () async {
      when(
        () => storage.getString(_storageKey),
      ).thenReturn(encodeAll([image('https://x/same.jpg')]));
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      await repo.add(image('https://x/same.jpg'));

      final captured =
          verify(
                () => storage.setString(_storageKey, captureAny()),
              ).captured.single
              as String;
      final persisted = (jsonDecode(captured) as List)
          .cast<Map<String, dynamic>>()
          .map(BlockedImage.fromJson)
          .toList();
      expect(persisted.length, 1);
    });

    test('should emit changes after persisting', () async {
      when(() => storage.getString(_storageKey)).thenReturn(null);
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      var fired = 0;
      final subscription = repo.changes.listen((_) => fired++);
      await repo.add(image('https://x/a.jpg'));
      await Future<void>.delayed(Duration.zero);

      expect(fired, 1);
      await subscription.cancel();
    });
  });

  group('BlockedImageImpl hash matching', () {
    test('should persist and reload the hash field', () async {
      when(() => storage.getString(_storageKey)).thenReturn(
        encodeAll([
          BlockedImage(
            url: 'https://x/a.jpg',
            blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
            hash: '0123456789abcdef',
          ),
        ]),
      );

      final result = await repo.getAll();

      expect(result.single.hash, '0123456789abcdef');
    });

    test('isHashBlocked matches within the Hamming threshold', () async {
      when(() => storage.getString(_storageKey)).thenReturn(
        encodeAll([
          BlockedImage(
            url: 'https://x/a.jpg',
            blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
            hash: '0000000000000000',
          ),
        ]),
      );

      // 0x3f is 6 bits away — inside the threshold.
      expect(repo.isHashBlocked('3f'), isTrue);
      // 0xff is 8 bits away — outside.
      expect(repo.isHashBlocked('ff'), isFalse);
    });

    test('isHashBlocked reads storage lazily without a prior getAll', () async {
      when(() => storage.getString(_storageKey)).thenReturn(
        encodeAll([
          BlockedImage(
            url: 'https://x/a.jpg',
            blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
            hash: '0000000000000000',
          ),
        ]),
      );

      expect(repo.isHashBlocked('0000000000000000'), isTrue);
    });

    test('isHashBlocked skips entries without a hash', () async {
      when(() => storage.getString(_storageKey)).thenReturn(
        encodeAll([
          BlockedImage(
            url: 'https://x/a.jpg',
            blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ]),
      );

      expect(repo.isHashBlocked('0000000000000000'), isFalse);
    });

    test('add stores the hash captured at block time', () async {
      when(() => storage.getString(_storageKey)).thenReturn(null);
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      await repo.add(
        BlockedImage(
          url: 'https://x/a.jpg',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
          hash: 'abcdef0123456789',
        ),
      );

      final captured =
          verify(
                () => storage.setString(_storageKey, captureAny()),
              ).captured.single
              as String;
      final persisted = (jsonDecode(captured) as List)
          .cast<Map<String, dynamic>>()
          .map(BlockedImage.fromJson)
          .toList();
      expect(persisted.single.hash, 'abcdef0123456789');
    });
  });

  group('BlockedImageImpl remove', () {
    test('should remove matching url and persist', () async {
      when(() => storage.getString(_storageKey)).thenReturn(
        encodeAll([image('https://x/keep.jpg'), image('https://x/drop.jpg')]),
      );
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      await repo.remove('https://x/drop.jpg');

      final captured =
          verify(
                () => storage.setString(_storageKey, captureAny()),
              ).captured.single
              as String;
      final persisted = (jsonDecode(captured) as List)
          .cast<Map<String, dynamic>>()
          .map(BlockedImage.fromJson)
          .toList();
      expect(persisted.length, 1);
      expect(persisted.single.url, 'https://x/keep.jpg');
    });

    test('should emit changes after removing', () async {
      when(
        () => storage.getString(_storageKey),
      ).thenReturn(encodeAll([image('https://x/drop.jpg')]));
      when(
        () => storage.setString(_storageKey, any()),
      ).thenAnswer((_) async {});

      var fired = 0;
      final subscription = repo.changes.listen((_) => fired++);
      await repo.remove('https://x/drop.jpg');
      await Future<void>.delayed(Duration.zero);

      expect(fired, 1);
      await subscription.cancel();
    });
  });
}
