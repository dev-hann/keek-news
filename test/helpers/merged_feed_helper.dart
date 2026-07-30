import 'package:dartz/dartz.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:mocktail/mocktail.dart';

class MockMergedFeedRepository extends Mock implements MergedFeedRepo {}

void registerMergedFeedFallbacks() {
  registerFallbackValue(
    MergedCursor(oldestSeen: DateTime(2000), perSourceTokens: const {}),
  );
  registerFallbackValue(<CommunityId>{});
  registerFallbackValue(CommunityId.humoruniv);
}

void setupMergedFeedMocks(MockMergedFeedRepository mock) {
  when(
    () => mock.fetchMerged(
      perSource: any(named: 'perSource'),
      cursor: any(named: 'cursor'),
      enabled: any(named: 'enabled'),
    ),
  ).thenAnswer((_) async => const Right(MergedPage(items: [])));

  when(
    () => mock.fetchDetail(
      community: any(named: 'community'),
      id: any(named: 'id'),
    ),
  ).thenAnswer((_) async => const Left(ServerFailure('no detail in test')));
}
