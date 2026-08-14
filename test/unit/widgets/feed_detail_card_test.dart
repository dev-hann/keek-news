import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/widgets/feed_detail_card.dart';

import '../../helpers/shad_harness.dart';

const _post = FeedItem(
  community: CommunityId.dogdrip,
  id: '716784390',
  title: '싱글벙글',
  url: '/716784390',
);

LoadedPostDetail _loaded() => LoadedPostDetail(
  id: 716784390,
  community: CommunityId.dogdrip,
  title: '싱글벙글',
  author: 'a',
  date: DateTime(2026),
  contentBlocks: const [],
  imageUrls: const [],
  recommendCount: 0,
  notRecommendCount: 0,
  viewCount: 0,
  commentCount: 0,
  comments: const [],
);

Widget _card({PostDetail? detail, bool loading = false}) => shadHarness(
  FeedDetailCard(
    post: _post,
    detail: detail,
    detailLoading: loading,
    isBookmarked: false,
    onBookmarkTap: () {},
    onRetryTap: () {},
  ),
);

void main() {
  group('FeedDetailCard', () {
    testWidgets('renders loaded FeedCardEntry with post title', (
      tester,
    ) async {
      await tester.pumpWidget(_card(detail: _loaded()));

      expect(find.text('싱글벙글'), findsWidgets);
    });

    testWidgets('renders error card when detail failed', (tester) async {
      await tester.pumpWidget(
        _card(
          detail: const ErrorPostDetail(
            id: 716784390,
            community: CommunityId.dogdrip,
            failure: NetworkFailure('timeout'),
          ),
        ),
      );

      expect(find.textContaining('불러오기 실패'), findsOneWidget);
      expect(find.text('오류 정보 복사'), findsOneWidget);
    });

    testWidgets('renders list-level entry while loading', (tester) async {
      await tester.pumpWidget(_card(loading: true));

      expect(find.text('싱글벙글'), findsWidgets);
      expect(find.textContaining('불러오기 실패'), findsNothing);
    });

    testWidgets('renders entry when detail is null', (tester) async {
      await tester.pumpWidget(_card());

      expect(find.text('싱글벙글'), findsWidgets);
    });
  });
}
