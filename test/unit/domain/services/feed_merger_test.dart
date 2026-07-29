import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/feed_item.dart';
import 'package:happy_news/domain/services/feed_merger.dart';

void main() {
  group('mergeFeedStreams', () {
    test(
      'should merge items from two streams sorted by publishedAt descending',
      () {
        final streams = <CommunityId, List<FeedItem>>{
          CommunityId.humoruniv: [
            FeedItem(
              community: CommunityId.humoruniv,
              id: '1',
              title: 'hu-1',
              url: 'u1',
              publishedAt: DateTime(2026, 7, 26, 10),
            ),
            FeedItem(
              community: CommunityId.humoruniv,
              id: '2',
              title: 'hu-2',
              url: 'u2',
              publishedAt: DateTime(2026, 7, 26, 8),
            ),
          ],
          CommunityId.todayhumor: [
            FeedItem(
              community: CommunityId.todayhumor,
              id: '1',
              title: 'th-1',
              url: 'u3',
              publishedAt: DateTime(2026, 7, 26, 12),
            ),
          ],
        };

        final result = mergeFeedStreams(streams: streams);

        expect(result.items.map((e) => '${e.community}-${e.id}'), [
          CommunityId.todayhumor.toString() + '-1',
          CommunityId.humoruniv.toString() + '-1',
          CommunityId.humoruniv.toString() + '-2',
        ]);
      },
    );

    test('should respect maxItems limit', () {
      final streams = <CommunityId, List<FeedItem>>{
        CommunityId.humoruniv: List.generate(
          10,
          (i) => FeedItem(
            community: CommunityId.humoruniv,
            id: '$i',
            title: 'hu-$i',
            url: 'u$i',
            publishedAt: DateTime(2026, 7, 26, 10 - i),
          ),
        ),
      };

      final result = mergeFeedStreams(streams: streams, maxItems: 3);

      expect(result.items, hasLength(3));
    });

    test('should filter items older than olderThan', () {
      final cutoff = DateTime(2026, 7, 26, 9);
      final streams = <CommunityId, List<FeedItem>>{
        CommunityId.humoruniv: [
          FeedItem(
            community: CommunityId.humoruniv,
            id: '1',
            title: 'new',
            url: 'u1',
            publishedAt: DateTime(2026, 7, 26, 10),
          ),
          FeedItem(
            community: CommunityId.humoruniv,
            id: '2',
            title: 'old',
            url: 'u2',
            publishedAt: DateTime(2026, 7, 26, 8),
          ),
        ],
      };

      final result = mergeFeedStreams(streams: streams, olderThan: cutoff);

      expect(result.items, hasLength(1));
      expect(result.items.first.id, '2');
    });

    test('should place null publishedAt items at front', () {
      final streams = <CommunityId, List<FeedItem>>{
        CommunityId.humoruniv: [
          const FeedItem(
            community: CommunityId.humoruniv,
            id: 'null-ts',
            title: 'no-date',
            url: 'u1',
          ),
          FeedItem(
            community: CommunityId.humoruniv,
            id: 'has-ts',
            title: 'has-date',
            url: 'u2',
            publishedAt: DateTime(2026, 7, 26, 10),
          ),
        ],
      };

      final result = mergeFeedStreams(streams: streams);

      expect(result.items.first.id, 'null-ts');
    });

    test('should return empty page when streams are empty', () {
      final result = mergeFeedStreams(streams: {});

      expect(result.items, isEmpty);
    });

    test('should build cursor with oldestSeen and nextTokens', () {
      final streams = <CommunityId, List<FeedItem>>{
        CommunityId.humoruniv: [
          FeedItem(
            community: CommunityId.humoruniv,
            id: '1',
            title: 'a',
            url: 'u',
            publishedAt: DateTime(2026, 7, 26, 10),
          ),
          FeedItem(
            community: CommunityId.humoruniv,
            id: '2',
            title: 'b',
            url: 'u',
            publishedAt: DateTime(2026, 7, 26, 8),
          ),
        ],
      };

      final result = mergeFeedStreams(
        streams: streams,
        nextTokens: {CommunityId.humoruniv: 'page3'},
      );

      expect(result.next, isNotNull);
      expect(result.next!.oldestSeen, DateTime(2026, 7, 26, 8));
      expect(result.next!.perSourceTokens[CommunityId.humoruniv], 'page3');
    });

    test('should interleave items with same timestamp by round-robin', () {
      final ts = DateTime(2026, 7, 26, 10);
      final streams = <CommunityId, List<FeedItem>>{
        CommunityId.humoruniv: [
          FeedItem(
            community: CommunityId.humoruniv,
            id: 'a',
            title: 'a',
            url: 'u',
            publishedAt: ts,
          ),
          FeedItem(
            community: CommunityId.humoruniv,
            id: 'b',
            title: 'b',
            url: 'u',
            publishedAt: ts,
          ),
        ],
        CommunityId.todayhumor: [
          FeedItem(
            community: CommunityId.todayhumor,
            id: 'c',
            title: 'c',
            url: 'u',
            publishedAt: ts,
          ),
          FeedItem(
            community: CommunityId.todayhumor,
            id: 'd',
            title: 'd',
            url: 'u',
            publishedAt: ts,
          ),
        ],
      };

      final result = mergeFeedStreams(streams: streams);

      final communities = result.items.map((e) => e.community).toList();
      expect(communities[0], isNot(communities[1]));
      expect(communities[1], isNot(communities[2]));
      expect(communities[2], isNot(communities[3]));
    });

    test('should respect maxItems limit', () async {
      final ts = DateTime(2026, 7, 26, 10);
      final streams = <CommunityId, List<FeedItem>>{
        CommunityId.dogdrip: List.generate(
          8,
          (i) => FeedItem(
            community: CommunityId.dogdrip,
            id: 'dd$i',
            title: 'dd-$i',
            url: 'u',
            publishedAt: ts.subtract(Duration(minutes: i)),
          ),
        ),
        CommunityId.humoruniv: [
          FeedItem(
            community: CommunityId.humoruniv,
            id: 'hu1',
            title: 'hu-1',
            url: 'u',
            publishedAt: ts,
          ),
        ],
      };

      final result = mergeFeedStreams(streams: streams);

      expect(result.items.length, lessThanOrEqualTo(9));
    });
  });
}
