import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/pages/home_view.dart';
import 'package:keek_news/provider/shared_preferences_provider.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';
import 'package:keek_news/widgets/error_state_view.dart';
import 'package:keek_news/widgets/feed_card.dart';
import 'package:keek_news/widgets/skeleton_feed_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/merged_feed_helper.dart';
import '../../helpers/package_info_helper.dart';

void main() {
  late MockMergedFeedRepository mockRepo;
  late SharedPreferences prefs;

  setUpAll(() async {
    await setupPackageInfoMock();
    registerMergedFeedFallbacks();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockRepo = MockMergedFeedRepository();
    await di.configureDependencies();
    if (di.sl.isRegistered<MergedFeedRepo>()) {
      di.sl.unregister<MergedFeedRepo>();
    }
    if (di.sl.isRegistered<GetMergedFeedUseCase>()) {
      di.sl.unregister<GetMergedFeedUseCase>();
    }
    di.sl.registerLazySingleton<MergedFeedRepo>(() => mockRepo);
    di.sl.registerLazySingleton(
      () => GetMergedFeedUseCase(repository: mockRepo),
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

  Widget buildApp() => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MaterialApp(home: HomeView()),
  );

  testWidgets('should display post titles when data loads', (tester) async {
    when(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => Right(page(sampleItems())));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('첫 번째 글'), findsOneWidget);
    expect(find.text('두 번째 글'), findsOneWidget);
  });

  testWidgets('should render a FeedCard for each item', (tester) async {
    when(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => Right(page(sampleItems())));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(FeedCard), findsNWidgets(2));
  });

  testWidgets('should toggle bookmark icon when bookmark button tapped', (
    tester,
  ) async {
    when(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => Right(page(sampleItems())));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.bookmark_border).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('should show skeleton feed cards while loading', (tester) async {
    final completer = Completer<Either<Failure, MergedPage>>();
    when(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byType(SkeletonFeedCard), findsWidgets);
    completer.complete(const Right(MergedPage(items: [])));
  });

  testWidgets('should show empty message when no posts', (tester) async {
    when(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => Right(page([])));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('게시글이 없습니다.'), findsOneWidget);
  });

  testWidgets('should show error message when fetch fails', (tester) async {
    when(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('error')));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(ErrorStateView), findsOneWidget);
  });

  testWidgets('should display AppBar with 통합 유머 피드 title', (tester) async {
    when(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => Right(page([])));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = (appBar.title! as Text).data;
    expect(title, '웃긴대학');
  });

  testWidgets('should display settings gear action', (tester) async {
    when(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => Right(page([])));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('설정'), findsOneWidget);
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
      next: MergedCursor(oldestSeen: DateTime(2024), perSourceTokens: const {}),
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
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => Right(call++ == 0 ? firstPage : secondPage));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(FeedCard), findsWidgets);

    final feedList = find.ancestor(
      of: find.byType(FeedCard).first,
      matching: find.byType(ListView),
    );

    for (var i = 0; i < 4; i++) {
      await tester.drag(feedList, const Offset(0, -1500));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final captured = verify(
      () => mockRepo.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: captureAny(named: 'cursor'),
        enabled: any(named: 'enabled'),
      ),
    ).captured;

    expect(captured.length, 2);
    expect(captured[0], isNull);
    expect(captured[1], isA<MergedCursor>());
  });
}
