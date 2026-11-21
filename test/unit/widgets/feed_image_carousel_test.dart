import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/image_hash_service.dart';
import 'package:keek_news/use_case/block_image_use_case.dart';
import 'package:keek_news/widgets/feed_image_carousel.dart';
import 'package:keek_news/widgets/video_thumbnail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/media_action_fakes.dart';
import '../../helpers/shad_harness.dart';

/// URL별로 다른 핑거프린트를 돌려주는 더블 — 한 게시글 안에서 일부 이미지만
/// 차단되는 시나리오를 만들 때 사용.
class _PerUrlFakeImageHashService implements ImageHashService {
  const _PerUrlFakeImageHashService(this.hashes);

  final Map<String, String> hashes;

  @override
  Future<String?> hashFor(String url) async => hashes[url];
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(GetIt.I.reset);

  group('FeedImageCarousel', () {
    testWidgets('single image shows no indicator', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: ['https://example.com/a.jpg'],
            postId: 1,
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('1/1'), findsNothing);
    });

    testWidgets('multiple images show "1/N" indicator', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(imageUrls: ['a', 'b', 'c'], postId: 1),
        ),
      );
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('swipe advances the indicator', (tester) async {
      await tester.pumpWidget(
        shadHarness(const FeedImageCarousel(imageUrls: ['a', 'b'], postId: 1)),
      );
      expect(find.text('1/2'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('tap calls onImageTap with index', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(
        shadHarness(
          FeedImageCarousel(
            imageUrls: const ['a', 'b'],
            postId: 1,
            onImageTap: (i) => tapped = i,
          ),
        ),
      );
      await tester.tap(find.byType(FeedImageCarousel));
      expect(tapped, 0);
    });

    testWidgets('page indicator is positioned at the top of the carousel', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(const FeedImageCarousel(imageUrls: ['a', 'b'], postId: 1)),
      );
      final badgeCenter = tester.getCenter(find.text('1/2'));
      final carouselCenter = tester.getCenter(find.byType(FeedImageCarousel));
      expect(
        badgeCenter.dy,
        lessThan(carouselCenter.dy),
        reason: 'indicator should sit at the top, away from video controls',
      );
    });

    testWidgets('video block without thumbnail renders VideoThumbnail '
        '(local frame fallback)', (tester) async {
      const block = VideoBlock(url: 'https://example.com/nthumb.mp4');
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: [],
            videoBlocks: [block],
            postId: 9,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byType(VideoThumbnail),
        findsOneWidget,
        reason:
            'null-thumbnail videos must use VideoThumbnail for local '
            'frame extraction',
      );
    });

    testWidgets('long-press on an image opens the media action sheet', (
      tester,
    ) async {
      final repo = StubMediaSaveRepo();
      registerMediaActionFakes(repo);
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: ['https://example.com/a.jpg'],
            postId: 1,
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(PageView));
      await tester.pumpAndSettle();

      expect(find.text('갤러리에 저장'), findsOneWidget);
      expect(repo.savedImages, isEmpty);
    });

    testWidgets('long-press on a video thumbnail opens the sheet '
        'for the video target', (tester) async {
      final repo = StubMediaSaveRepo();
      registerMediaActionFakes(repo);
      const block = VideoBlock(url: 'https://example.com/v.mp4');
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: [],
            videoBlocks: [block],
            postId: 2,
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(PageView));
      await tester.pumpAndSettle();

      expect(find.text('갤러리에 저장'), findsOneWidget);
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
    });

    testWidgets('video poster skips the blocked-image fingerprint check', (
      tester,
    ) async {
      // Regression: every synthesized video poster shares one fingerprint,
      // so a single hash-colliding blocklist entry must not hide the poster.
      final blockedRepo = StubBlockedImageRepo();
      await blockedRepo.add(
        BlockedImage(
          url: 'https://example.com/blocked.jpg',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
          hash: '7e7e7e7e7e7e7e7e',
        ),
      );
      final sl = GetIt.I;
      sl.registerLazySingleton<ImageHashService>(
        () => const FakeImageHashService('7e7e7e7e7e7e7e7a'),
      );
      sl.registerLazySingleton<BlockImageUseCase>(
        () => BlockImageUseCase(blockedRepo),
      );
      const block = VideoBlock(
        url: 'https://example.com/v.mp4',
        thumbnailUrl:
            'https://timg.humoruniv.com/thumb.php?url=https%3A%2F%2Fexample.com%2Fv.mp4',
      );
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: [],
            videoBlocks: [block],
            postId: 3,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('차단된 이미지'), findsNothing);
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('drops fingerprint-blocked pages and collapses when no '
        'media remains', (tester) async {
      final blockedRepo = StubBlockedImageRepo();
      await blockedRepo.add(
        BlockedImage(
          url: 'https://example.com/blocked.jpg',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
          hash: '7e7e7e7e7e7e7e7e',
        ),
      );
      final sl = GetIt.I;
      sl.registerLazySingleton<ImageHashService>(
        () => const FakeImageHashService('7e7e7e7e7e7e7e7a'),
      );
      sl.registerLazySingleton<BlockImageUseCase>(
        () => BlockImageUseCase(blockedRepo),
      );
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: ['https://example.com/repost.webp'],
            postId: 4,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('차단된 이미지'), findsNothing);
      expect(find.byType(PageView), findsNothing);
      expect(
        tester.getSize(find.byType(FeedImageCarousel)),
        Size.zero,
        reason: '모든 이미지가 핑거프린트 차단되면 미디어 영역은 붕괴해야 함',
      );
    });

    testWidgets('keeps the original onImageTap index after dropping a '
        'blocked page', (tester) async {
      var tapped = -1;
      final blockedRepo = StubBlockedImageRepo();
      await blockedRepo.add(
        BlockedImage(
          url: 'https://example.com/blocked.jpg',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
          hash: '7e7e7e7e7e7e7e7e',
        ),
      );
      final sl = GetIt.I;
      sl.registerLazySingleton<ImageHashService>(
        () => const _PerUrlFakeImageHashService({
          'https://example.com/a.jpg': '7e7e7e7e7e7e7e7a',
          'https://example.com/b.jpg': '8181818181818181',
        }),
      );
      sl.registerLazySingleton<BlockImageUseCase>(
        () => BlockImageUseCase(blockedRepo),
      );
      await tester.pumpWidget(
        shadHarness(
          FeedImageCarousel(
            imageUrls: const [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
            ],
            postId: 5,
            onImageTap: (i) => tapped = i,
          ),
        ),
      );
      expect(find.text('1/2'), findsOneWidget);

      await tester.pump();
      await tester.pump();

      expect(
        find.text('1/2'),
        findsNothing,
        reason: '차단 페이지 제거 후 단일 페이지가 되면 배지는 사라짐',
      );
      expect(find.text('차단된 이미지'), findsNothing);
      await tester.tap(find.byType(PageView));
      await tester.pump();
      expect(tapped, 1, reason: '뷰어 initialIndex는 원본 목록 기준이므로 원본 인덱스 전달');
      await tester.pumpAndSettle();
    });

    testWidgets('keeps video pages when every image is fingerprint-blocked', (
      tester,
    ) async {
      final blockedRepo = StubBlockedImageRepo();
      await blockedRepo.add(
        BlockedImage(
          url: 'https://example.com/blocked.jpg',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
          hash: '7e7e7e7e7e7e7e7e',
        ),
      );
      final sl = GetIt.I;
      sl.registerLazySingleton<ImageHashService>(
        () => const FakeImageHashService('7e7e7e7e7e7e7e7a'),
      );
      sl.registerLazySingleton<BlockImageUseCase>(
        () => BlockImageUseCase(blockedRepo),
      );
      await tester.pumpWidget(
        shadHarness(
          const FeedImageCarousel(
            imageUrls: ['https://example.com/repost.webp'],
            videoBlocks: [VideoBlock(url: 'https://example.com/v.mp4')],
            postId: 6,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byType(VideoThumbnail),
        findsOneWidget,
        reason: '이미지만 차단되어도 영상 페이지는 유지되어야 함',
      );
      expect(
        tester.getSize(find.byType(FeedImageCarousel)).height,
        greaterThan(0),
      );
    });

    testWidgets('clamps the visible page when the media list shrinks', (
      tester,
    ) async {
      Widget harness(FeedImageCarousel carousel) => shadHarness(carousel);
      await tester.pumpWidget(
        harness(
          const FeedImageCarousel(
            imageUrls: [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
              'https://example.com/c.jpg',
            ],
            postId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);

      // Simulates a blocked image being filtered out of the loaded detail.
      await tester.pumpWidget(
        harness(
          const FeedImageCarousel(
            imageUrls: [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
            ],
            postId: 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('2/2'),
        findsOneWidget,
        reason: 'page index must clamp to the last remaining page',
      );
    });
  });
}
