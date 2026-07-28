import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';

void main() {
  group('MergedCursor', () {
    test('should create with oldestSeen and perSourceTokens', () {
      final cursor = MergedCursor(
        oldestSeen: DateTime(2026, 7, 26, 10),
        perSourceTokens: {
          CommunityId.humoruniv: '2',
          CommunityId.todayhumor: null,
        },
      );

      expect(cursor.oldestSeen, DateTime(2026, 7, 26, 10));
      expect(cursor.perSourceTokens[CommunityId.humoruniv], '2');
      expect(cursor.perSourceTokens[CommunityId.todayhumor], isNull);
    });

    test('should support value equality', () {
      final a = MergedCursor(
        oldestSeen: DateTime(2026, 7, 26),
        perSourceTokens: {CommunityId.humoruniv: '1'},
      );
      final b = MergedCursor(
        oldestSeen: DateTime(2026, 7, 26),
        perSourceTokens: {CommunityId.humoruniv: '1'},
      );

      expect(a, equals(b));
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
      final cursor = MergedCursor(
        oldestSeen: DateTime(2026, 7, 26),
        perSourceTokens: {},
      );
      final page = MergedPage(
        items: [
          const FeedItem(
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
