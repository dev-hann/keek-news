import 'package:dartz/dartz.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockPostDetailUseCase extends Mock implements FeedUseCase {}

void setupPostDetailFailureMock(MockPostDetailUseCase mock) {
  when(
    () => mock.getPostDetail(
      community: any(named: 'community'),
      id: any(named: 'id'),
    ),
  ).thenAnswer((_) async => const Left(ServerFailure('none')));
}

void setupPostDetailResponseMock(
  MockPostDetailUseCase mock,
  PostDetail Function() detailFactory,
) {
  when(
    () => mock.getPostDetail(
      community: any(named: 'community'),
      id: any(named: 'id'),
    ),
  ).thenAnswer((_) async => Right(detailFactory()));
}

void registerPostDetailFallbacks() {
  registerFallbackValue(CommunityId.humoruniv);
}
