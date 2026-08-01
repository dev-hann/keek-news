import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/widgets/feed_error_card.dart';

import '../../helpers/shad_harness.dart';

void main() {
  const post = FeedItem(
    community: CommunityId.dogdrip,
    id: '716784390',
    title: '싱글벙글',
    url: '/716784390',
  );

  FeedErrorCard cardWith({required Failure failure, VoidCallback? onCopyTap}) =>
      FeedErrorCard(
        post: post,
        errorDetail: ErrorPostDetail(
          id: 716784390,
          community: CommunityId.dogdrip,
          failure: failure,
        ),
        onCopyTap: onCopyTap ?? () {},
      );

  group('FeedErrorCard', () {
    testWidgets('renders community label and failure headline', (tester) async {
      await tester.pumpWidget(
        shadHarness(cardWith(failure: const NetworkFailure('timeout'))),
      );

      expect(find.textContaining('DogDrip'), findsOneWidget);
      expect(find.textContaining('불러오기 실패'), findsOneWidget);
      expect(find.textContaining('네트워크 오류'), findsOneWidget);
    });

    testWidgets('renders ParseFailure reason as block/structure hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(cardWith(failure: const ParseFailure('본문 없음'))),
      );

      expect(find.textContaining('차단 또는 구조 변경 가능성'), findsOneWidget);
    });

    testWidgets('renders copy button', (tester) async {
      await tester.pumpWidget(
        shadHarness(cardWith(failure: const ServerFailure('x'))),
      );

      expect(find.text('오류 정보 복사'), findsOneWidget);
    });

    testWidgets('invokes onCopyTap when copy button tapped', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        shadHarness(
          cardWith(
            failure: const ServerFailure('x'),
            onCopyTap: () => tapped++,
          ),
        ),
      );

      await tester.tap(find.text('오류 정보 복사'));
      expect(tapped, 1);
    });

    testWidgets('does not render the post title (full-card replace)', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(cardWith(failure: const ServerFailure('x'))),
      );

      expect(find.text('싱글벙글'), findsNothing);
    });
  });
}
