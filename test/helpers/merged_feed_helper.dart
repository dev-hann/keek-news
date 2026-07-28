import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';
import 'package:humoruniv/domain/repositories/merged_feed_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockMergedFeedRepository extends Mock implements MergedFeedRepository {}

void registerMergedFeedFallbacks() {
  registerFallbackValue(
    MergedCursor(oldestSeen: DateTime(2000), perSourceTokens: const {}),
  );
  registerFallbackValue(<CommunityId>{});
  registerFallbackValue(CommunityId.humoruniv);
}

void setupMergedFeedMocks(MockMergedFeedRepository mock) {
  when(() => mock.fetchMerged(
        perSource: any(named: 'perSource'),
        cursor: any(named: 'cursor'),
        enabled: any(named: 'enabled'),
        maxRatioPerSource: any(named: 'maxRatioPerSource'),
      )).thenAnswer((_) async => const Right(MergedPage(items: [])));

  when(() => mock.fetchDetail(
        community: any(named: 'community'),
        id: any(named: 'id'),
      )).thenAnswer((_) async => const Left(ServerFailure('no detail in test')));
}
