import 'package:dartz/dartz.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockMergedFeedUseCase extends Mock implements FeedUseCase {}

void registerMergedFeedFallbacks() {
  registerFallbackValue(const MergedFeedParams());
}

void setupMergedFeedMocks(MockMergedFeedUseCase mock) {
  when(
    () => mock.getMergedFeed(any()),
  ).thenAnswer((_) async => const Right(MergedPage(items: [])));
  when(
    mock.getEnabledCommunities,
  ).thenAnswer((_) => CommunityId.values.toSet());
}
