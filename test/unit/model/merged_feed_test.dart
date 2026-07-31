import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';

void main() {
  group('MergedCursor', () {
    test('should create with perSourceTokens', () {
      const cursor = MergedCursor(
        perSourceTokens: {
          CommunityId.humoruniv: '2',
          CommunityId.todayhumor: null,
        },
      );

      expect(cursor.perSourceTokens[CommunityId.humoruniv], '2');
      expect(cursor.perSourceTokens[CommunityId.todayhumor], isNull);
    });

    test('should support value equality', () {
      const a = MergedCursor(perSourceTokens: {CommunityId.humoruniv: '1'});
      const b = MergedCursor(perSourceTokens: {CommunityId.humoruniv: '1'});

      expect(a, equals(b));
    });

    test('hasMore should be true when any token is non-null', () {
      const cursor = MergedCursor(
        perSourceTokens: {
          CommunityId.humoruniv: '2',
          CommunityId.todayhumor: null,
        },
      );

      expect(cursor.hasMore, isTrue);
    });

    test('hasMore should be false when all tokens are null', () {
      const cursor = MergedCursor(
        perSourceTokens: {
          CommunityId.humoruniv: null,
          CommunityId.todayhumor: null,
        },
      );

      expect(cursor.hasMore, isFalse);
    });

    test('hasMore should be false when tokens map is empty', () {
      const cursor = MergedCursor(perSourceTokens: {});

      expect(cursor.hasMore, isFalse);
    });
  });

  group('MergedPage', () {
    test('should create with items and defaults', () {
      const page = MergedPage(items: []);

      expect(page.items, isEmpty);
      expect(page.next, isNull);
      expect(page.failedSources, isEmpty);
    });

    test('should create with cursor and failed sources', () {
      const cursor = MergedCursor(
        perSourceTokens: {CommunityId.humoruniv: '1'},
      );
      const page = MergedPage(
        items: [
          FeedItem(
            community: CommunityId.humoruniv,
            id: '1',
            title: 't',
            url: 'u',
          ),
        ],
        next: cursor,
        failedSources: {CommunityId.dogdrip},
      );

      expect(page.items, hasLength(1));
      expect(page.next, isNotNull);
      expect(page.failedSources, contains(CommunityId.dogdrip));
    });
  });
}
