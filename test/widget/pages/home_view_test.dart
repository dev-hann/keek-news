import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/pages/home_view.dart';
import 'package:keek_news/provider/shared_preferences_provider.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:keek_news/widgets/community_tab_bar.dart';
import 'package:keek_news/widgets/error_state_view.dart';
import 'package:keek_news/widgets/feed_card.dart';
import 'package:keek_news/widgets/skeleton_feed_card.dart';
import 'package:keek_news/widgets/scroll_to_top_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/merged_feed_helper.dart';
import '../../helpers/package_info_helper.dart';
import '../../helpers/path_provider_helper.dart';
import '../../helpers/shad_harness.dart';

void main() {
  late MockMergedFeedUseCase mockUseCase;
  late SharedPreferences prefs;

  setUpAll(() async {
    await setupPackageInfoMock();
    setupPathProviderMock();
    registerMergedFeedFallbacks();
    registerFallbackValue(CommunityId.humoruniv);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockUseCase = MockMergedFeedUseCase();
    await di.configureDependencies();
    if (di.sl.isRegistered<FeedUseCase>()) {
      di.sl.unregister<FeedUseCase>();
    }
    di.sl.registerLazySingleton<FeedUseCase>(() => mockUseCase);
    when(
      () => mockUseCase.getEnabledCommunities(),
    ).thenAnswer((_) => CommunityId.values.toSet());
    when(
      () => mockUseCase.getPostDetail(
        community: any(named: 'community'),
        id: any(named: 'id'),
      ),
    ).thenAnswer(
      (_) async => LoadedPostDetail(
        id: 0,
        community: CommunityId.humoruniv,
        title: '',
        author: '',
        date: DateTime(2026),
        contentBlocks: const [],
        imageUrls: const [],
        recommendCount: 0,
        notRecommendCount: 0,
        viewCount: 0,
        commentCount: 0,
        comments: const [],
      ),
    );
  });

  tearDown(di.sl.reset);

  List<FeedItem> sampleItems() => [
    const FeedItem(
      community: CommunityId.humoruniv,
      id: '1',
      title: '첫 번째 글',
      url: '/u1',
      author: '작성자1',
      recommendCount: 100,
      commentCount: 5,
      viewCount: 1000,
    ),
    const FeedItem(
      community: CommunityId.humoruniv,
      id: '2',
      title: '두 번째 글',
      url: '/u2',
      author: '작성자2',
      recommendCount: 200,
      commentCount: 8,
      viewCount: 2000,
    ),
  ];

  MergedPage page(List<FeedItem> items) => MergedPage(items: items);

  void stubMergedPage(MergedPage Function() factory) {
    when(
      () => mockUseCase.getMergedFeed(any()),
    ).thenAnswer((_) async => Right(factory()));
  }

  Widget buildApp() => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: shadApp(home: const HomeView()),
  );

  testWidgets('should display post titles when data loads', (tester) async {
    stubMergedPage(() => page(sampleItems()));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('첫 번째 글'), findsOneWidget);
    expect(find.text('두 번째 글'), findsOneWidget);
  });

  testWidgets('should render a FeedCard for each item', (tester) async {
    stubMergedPage(() => page(sampleItems()));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(FeedCard), findsNWidgets(2));
  });

  testWidgets('should toggle bookmark icon when bookmark button tapped', (
    tester,
  ) async {
    stubMergedPage(() => page(sampleItems()));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.bookmark), findsNWidgets(2));

    await tester.tap(find.byIcon(LucideIcons.bookmark).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
  });

  testWidgets('should show skeleton feed cards while loading', (tester) async {
    final completer = Completer<Either<Failure, MergedPage>>();
    when(
      () => mockUseCase.getMergedFeed(any()),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byType(SkeletonFeedCard), findsWidgets);
    completer.complete(const Right(MergedPage(items: [])));
  });

  testWidgets('should show empty message when no posts', (tester) async {
    stubMergedPage(() => page([]));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('게시글이 없습니다.'), findsOneWidget);
  });

  testWidgets('should show error message when fetch fails', (tester) async {
    when(
      () => mockUseCase.getMergedFeed(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('error')));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(ErrorStateView), findsOneWidget);
  });

  testWidgets('should display AppBar with 통합 유머 피드 title', (tester) async {
    stubMergedPage(() => page([]));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Two SliverAppBars exist (top + tab bar). First is the title AppBar.
    final appBar = tester.widgetList<AppBar>(find.byType(AppBar)).first;
    final title = (appBar.title! as GestureDetector).child! as Text;
    expect(title.data, '웃긴대학');
  });

  testWidgets('should display settings gear action', (tester) async {
    stubMergedPage(() => page([]));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('설정'), findsOneWidget);
  });

  testWidgets('tapping AppBar title at top triggers silent refresh', (
    tester,
  ) async {
    stubMergedPage(() => page(sampleItems()));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    verify(() => mockUseCase.getMergedFeed(any())).called(1);

    await tester.tap(find.text('웃긴대학'));
    await tester.pumpAndSettle();

    verify(() => mockUseCase.getMergedFeed(any())).called(1);
  });

  testWidgets('tapping scroll-to-top FAB triggers silent refresh', (
    tester,
  ) async {
    stubMergedPage(
      () => page(
        List.generate(
          20,
          (i) => FeedItem(
            community: CommunityId.humoruniv,
            id: '${i + 1}',
            title: '글 ${i + 1}',
            url: '/u${i + 1}',
            author: 'a',
            recommendCount: i,
            commentCount: i,
            viewCount: i,
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    verify(() => mockUseCase.getMergedFeed(any())).called(1);

    final feedList = find.ancestor(
      of: find.byType(FeedCard).first,
      matching: find.byType(CustomScrollView),
    );
    await tester.drag(feedList, const Offset(0, -1500));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ScrollToTopButton));
    await tester.pumpAndSettle();

    verify(() => mockUseCase.getMergedFeed(any())).called(1);
    expect(find.byType(SkeletonFeedCard), findsNothing);
    expect(find.text('글 1'), findsOneWidget);
  });

  testWidgets('hides CommunityTabBar when only one community enabled', (
    tester,
  ) async {
    when(
      () => mockUseCase.getEnabledCommunities(),
    ).thenAnswer((_) => {CommunityId.humoruniv});
    stubMergedPage(() => page(sampleItems()));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(CommunityTabBar), findsNothing);
    // Title still shows the single community's display name.
    expect(find.text('웃긴대학'), findsWidgets);
  });

  testWidgets('shows CommunityTabBar when multiple communities enabled', (
    tester,
  ) async {
    stubMergedPage(() => page(sampleItems()));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(CommunityTabBar), findsOneWidget);
  });

  testWidgets('scroll near bottom triggers fetchNextPage with cursor', (
    tester,
  ) async {
    final firstPage = MergedPage(
      items: List.generate(
        20,
        (i) => FeedItem(
          community: CommunityId.humoruniv,
          id: '${i + 1}',
          title: '글 ${i + 1}',
          url: '/u${i + 1}',
          author: 'a',
          recommendCount: i,
          commentCount: i,
          viewCount: i,
        ),
      ),
      next: const MergedCursor(perSourceTokens: {CommunityId.humoruniv: '2'}),
    );
    final secondPage = MergedPage(
      items: List.generate(
        5,
        (i) => FeedItem(
          community: CommunityId.humoruniv,
          id: '${100 + i}',
          title: '다음글 ${100 + i}',
          url: '/n${100 + i}',
          author: 'a',
        ),
      ),
    );

    var call = 0;
    when(
      () => mockUseCase.getMergedFeed(any()),
    ).thenAnswer((_) async => Right(call++ == 0 ? firstPage : secondPage));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(FeedCard), findsWidgets);

    // Feed renders inside a SliverList inside CustomScrollView (no ListView).
    final feedList = find.ancestor(
      of: find.byType(FeedCard).first,
      matching: find.byType(CustomScrollView),
    );

    for (var i = 0; i < 6; i++) {
      await tester.drag(feedList, const Offset(0, -1500));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 1));

    final captured = verify(
      () => mockUseCase.getMergedFeed(captureAny()),
    ).captured;

    expect(captured.length, greaterThanOrEqualTo(2));
    expect((captured[0] as MergedFeedParams).cursor, isNull);
    expect((captured[1] as MergedFeedParams).cursor, isA<MergedCursor>());
  });
}
