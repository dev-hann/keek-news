import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/feed_item.dart';
import 'package:happy_news/domain/entities/merged_feed.dart';
import 'package:happy_news/domain/repositories/merged_feed_repository.dart';
import 'package:happy_news/domain/usecases/get_merged_feed.dart';
import 'package:mocktail/mocktail.dart';

class MockMergedFeedRepo extends Mock implements MergedFeedRepository {}

void main() {
  late MockMergedFeedRepo repo;
  late GetMergedFeed useCase;

  setUp(() {
    repo = MockMergedFeedRepo();
    useCase = GetMergedFeed(repository: repo);
  });

  group('GetMergedFeed', () {
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
