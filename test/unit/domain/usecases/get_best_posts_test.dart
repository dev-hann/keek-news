import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/post.dart';
import 'package:happy_news/domain/repositories/post_repository.dart';
import 'package:happy_news/domain/usecases/get_best_posts.dart';
import 'package:mocktail/mocktail.dart';

class MockPostRepository extends Mock implements PostRepository {}

void main() {
  late MockPostRepository mockRepository;
  late GetBestPosts useCase;

  setUp(() {
    mockRepository = MockPostRepository();
    useCase = GetBestPosts(repository: mockRepository);
  });

  group('GetBestPosts', () {
    test('should return list of posts from repository', () async {
      final posts = [
        const Post(id: 1, title: 'Post 1', recommendCount: 100, url: '/test'),
        const Post(id: 2, title: 'Post 2', recommendCount: 200, url: '/test'),
      ];
      when(
        () => mockRepository.getBestPosts(),
      ).thenAnswer((_) async => Right(posts));

      final result = await useCase();

      expect(result, Right<Failure, List<Post>>(posts));
      verify(() => mockRepository.getBestPosts()).called(1);
    });

    test('should return failure when repository fails', () async {
      const failure = ServerFailure('Server error');
      when(
        () => mockRepository.getBestPosts(),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase();

      expect(result, const Left<Failure, List<Post>>(failure));
    });
  });
}
