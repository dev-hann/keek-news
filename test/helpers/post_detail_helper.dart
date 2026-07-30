import 'package:dartz/dartz.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/use_case/get_post_detail_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockPostDetailUseCase extends Mock implements GetPostDetailUseCase {}

void setupPostDetailFailureMock(MockPostDetailUseCase mock) {
  when(
    () => mock.call(
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
    () => mock.call(
      community: any(named: 'community'),
      id: any(named: 'id'),
    ),
  ).thenAnswer((_) async => Right(detailFactory()));
}

void registerPostDetailFallbacks() {
  registerFallbackValue(CommunityId.humoruniv);
}
