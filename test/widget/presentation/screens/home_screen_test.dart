import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/core/widgets/molecules/feed_card.dart';
import 'package:humoruniv/core/widgets/states/skeleton_feed_card.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';
import 'package:humoruniv/presentation/providers/merged_feed_provider.dart';
import 'package:humoruniv/presentation/providers/shared_preferences_provider.dart';
import 'package:humoruniv/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

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
          community: CommunityId.todayhumor,
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

  Widget buildWith({
    required Either<Failure, MergedPage> data,
    Duration? delay,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mergedFeedProvider.overrideWith(
          (ref) => delay != null
              ? Future.delayed(delay, () => data)
              : Future.value(data),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('should display post titles when data loads', (tester) async {
    await tester.pumpWidget(buildWith(data: Right(page(sampleItems()))));
    await tester.pumpAndSettle();

    expect(find.text('첫 번째 글'), findsOneWidget);
    expect(find.text('두 번째 글'), findsOneWidget);
  });

  testWidgets('should render a FeedCard for each item', (tester) async {
    await tester.pumpWidget(buildWith(data: Right(page(sampleItems()))));
    await tester.pumpAndSettle();

    expect(find.byType(FeedCard), findsNWidgets(2));
  });

  testWidgets('should show skeleton feed cards while loading', (tester) async {
    final completer = Completer<Either<Failure, MergedPage>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mergedFeedProvider.overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(SkeletonFeedCard), findsWidgets);
    completer.complete(const Right(MergedPage(items: [])));
  });

  testWidgets('should show empty message when no posts', (tester) async {
    await tester.pumpWidget(buildWith(data: Right(page([]))));
    await tester.pumpAndSettle();

    expect(find.text('게시글이 없습니다.'), findsOneWidget);
  });

  testWidgets('should show error message when fetch fails', (tester) async {
    await tester.pumpWidget(
      buildWith(data: const Left(ServerFailure('error'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('게시글을 불러올 수 없습니다.'), findsOneWidget);
  });

  testWidgets('should display AppBar with 통합 유머 피드 title', (tester) async {
    await tester.pumpWidget(buildWith(data: Right(page([]))));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = (appBar.title! as Text).data;
    expect(title, '통합 유머 피드');
  });

  testWidgets('should display settings gear action', (tester) async {
    await tester.pumpWidget(buildWith(data: Right(page([]))));
    await tester.pumpAndSettle();

    expect(find.byTooltip('설정'), findsOneWidget);
  });
}
