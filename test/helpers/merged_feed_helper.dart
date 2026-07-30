import 'package:dartz/dartz.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockMergedFeedUseCase extends Mock implements GetMergedFeedUseCase {}

void registerMergedFeedFallbacks() {
  registerFallbackValue(const MergedFeedParams());
}

void setupMergedFeedMocks(MockMergedFeedUseCase mock) {
  when(
    () => mock.call(any()),
  ).thenAnswer((_) async => const Right(MergedPage(items: [])));
}
