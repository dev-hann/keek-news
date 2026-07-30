import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockMergedFeedRepo extends Mock implements MergedFeedRepo {}

void main() {
  late MockMergedFeedRepo repo;
  late GetMergedFeedUseCase useCase;

  setUp(() {
    repo = MockMergedFeedRepo();
    useCase = GetMergedFeedUseCase(repository: repo);
  });

  group('GetMergedFeedUseCase', () {
    test('should delegate to repository.fetchMerged', () async {
      const page = MergedPage(
        items: [
          FeedItem(
            community: CommunityId.humoruniv,
            id: '1',
            title: 't',
            url: 'u',
          ),
        ],
      );
      when(
        () => repo.fetchMerged(
          perSource: any(named: 'perSource'),
          cursor: any(named: 'cursor'),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async => const Right(page));

      final result = await useCase(const MergedFeedParams());

      expect(result.isRight(), isTrue);
      verify(() => repo.fetchMerged(perSource: 20)).called(1);
    });

    test('should forward cursor and enabled set', () async {
      final cursor = MergedCursor(
        oldestSeen: DateTime(2026, 7, 26),
        perSourceTokens: const {CommunityId.humoruniv: '2'},
      );
      when(
        () => repo.fetchMerged(
          perSource: any(named: 'perSource'),
          cursor: any(named: 'cursor'),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async => const Right(MergedPage(items: [])));

      await useCase(
        MergedFeedParams(
          perSource: 15,
          cursor: cursor,
          enabled: {CommunityId.humoruniv},
        ),
      );

      verify(
        () => repo.fetchMerged(
          perSource: 15,
          cursor: cursor,
          enabled: {CommunityId.humoruniv},
        ),
      ).called(1);
    });

    test('should return Left when repository fails', () async {
      when(
        () => repo.fetchMerged(
          perSource: any(named: 'perSource'),
          cursor: any(named: 'cursor'),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('all failed')));

      final result = await useCase(const MergedFeedParams());

      expect(result.isLeft(), isTrue);
    });
  });
}
