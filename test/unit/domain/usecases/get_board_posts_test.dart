import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/board_list_result.dart';
import 'package:happy_news/domain/entities/board_post.dart';
import 'package:happy_news/domain/entities/sort_option.dart';
import 'package:happy_news/domain/repositories/post_repository.dart';
import 'package:happy_news/domain/usecases/get_board_posts.dart';
import 'package:mocktail/mocktail.dart';

class MockPostRepository extends Mock implements PostRepository {}

void main() {
  late MockPostRepository mockRepo;
  late GetBoardPosts useCase;

  setUp(() {
    mockRepo = MockPostRepository();
    useCase = GetBoardPosts(repository: mockRepo);
    registerFallbackValue(SortOption.all);
  });

  test('should return BoardListResult from repository', () async {
    const result = BoardListResult(
      posts: [
        BoardPost(
          id: 1,
          title: 'Post',
          url: '/test',
          author: 'user',
          date: '2026-05-15',
          recommendCount: 10,
          notRecommendCount: 0,
          commentCount: 5,
          viewCount: 100,
          thumbnailUrl: '',
        ),
      ],
      currentPage: 0,
      totalPage: 3,
    );
    when(
      () => mockRepo.getBoardPosts('pds', 0, SortOption.all),
    ).thenAnswer((_) async => const Right(result));

    final response = await useCase('pds', 0, SortOption.all);

    expect(response, isA<Right<Failure, BoardListResult>>());
    response.fold((_) => fail('Should not return left'), (data) {
      expect(data.posts, hasLength(1));
      expect(data.totalPage, 3);
    });
  });

  test('should return failure when repository fails', () async {
    when(
      () => mockRepo.getBoardPosts(any(), any(), any()),
    ).thenAnswer((_) async => const Left(ServerFailure('fail')));

    final response = await useCase('pds', 0, SortOption.all);

    expect(response, isA<Left<Failure, BoardListResult>>());
  });

  test('should pass correct parameters to repository', () async {
    const result = BoardListResult(posts: [], currentPage: 0, totalPage: 1);
    when(
      () => mockRepo.getBoardPosts(any(), any(), any()),
    ).thenAnswer((_) async => const Right(result));

    await useCase('pds', 2, SortOption.day);

    verify(() => mockRepo.getBoardPosts('pds', 2, SortOption.day)).called(1);
  });
}
