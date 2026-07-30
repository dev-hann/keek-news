import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/board_post.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/service/parser/post_detail_parser.dart';
import 'package:keek_news/widgets/feed_card.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';

void main() {
  final skip = Platform.environment['SMOKE'] != '1';

  group('FeedCard render with fixture post 1419432', () {
    testWidgets('should render image carousel with parsed detail', (
      tester,
    ) async {
      final html = File('test/fixtures/post_1419432.html').readAsStringSync();
      final detail = PostDetailParser.parse(html);

      print('--- parsed imageUrls: ${detail.imageUrls}');
      print('--- parsed contentBlocks: ${detail.contentBlocks.length}');

      final detailForRender = PostDetail(
        id: detail.id,
        title: detail.title,
        author: detail.author,
        date: detail.date,
        contentHtml: detail.contentHtml,
        contentBlocks: detail.contentBlocks,
        imageUrls: List<String>.unmodifiable(
          detail.imageUrls.map(
            (u) => 'https://example.com/smoke-${u.hashCode}.jpg',
          ),
        ),
        recommendCount: detail.recommendCount,
        notRecommendCount: detail.notRecommendCount,
        viewCount: detail.viewCount,
        commentCount: detail.commentCount,
        comments: detail.comments,
      );

      const post = BoardPost(
        id: 1419432,
        title: '하닉 1주보다 버튜버 도네가 나은 이유',
        url: '/board/read.html?table=pds&number=1419432',
        author: '이거뭐야품번모야',
        date: '2026-07-29',
        recommendCount: 242,
        notRecommendCount: 0,
        commentCount: 21,
        viewCount: 19504,
        thumbnailUrl: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedCard(post: post, detail: detailForRender),
            ),
          ),
        ),
      );

      expect(find.byType(FeedCard), findsOneWidget);
      expect(find.text('하닉 1주보다 버튜버 도네가 나은 이유'), findsOneWidget);
      expect(
        find.byType(FeedImageCarousel),
        findsOneWidget,
        reason: '이미지가 있으면 FeedImageCarousel이 렌더되어야 함',
      );
      expect(find.text('이거뭐야품번모야'), findsOneWidget);

      final carousel = tester.widget<FeedImageCarousel>(
        find.byType(FeedImageCarousel),
      );
      print('--- carousel imageUrls count: ${carousel.imageUrls.length}');

      expect(
        carousel.imageUrls.length,
        detail.imageUrls.length,
        reason: '캐러셀에 파싱된 이미지 개수만큼 URL 전달되어야 함',
      );
    }, skip: skip);
  });
}
