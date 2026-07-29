import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:happy_news/domain/repositories/post_repository.dart';
import 'package:happy_news/domain/usecases/get_post_detail.dart';
import 'package:mocktail/mocktail.dart';

class MockPostRepository extends Mock implements PostRepository {}

void main() {
  late MockPostRepository mockRepo;
  late GetPostDetail useCase;

  setUp(() {
    mockRepo = MockPostRepository();
    useCase = GetPostDetail(repository: mockRepo);
  });

  test('should return PostDetail from repository', () async {
    final detail = PostDetail(
      id: 1,
      title: '테스트',
      author: '작성자',
      date: DateTime(2026, 5, 15),
      contentHtml: '<p>내용</p>',
      contentBlocks: const [],
      imageUrls: const [],
      recommendCount: 100,
      notRecommendCount: 0,
      viewCount: 500,
      commentCount: 10,
      comments: const [],
    );
    when(
      () => mockRepo.getPostDetail(any()),
    ).thenAnswer((_) async => Right(detail));

    final result = await useCase('/test');

    expect(result, isA<Right<Failure, PostDetail>>());
    result.fold(
      (l) => fail('Should not return left'),
      (d) => expect(d.title, '테스트'),
    );
  });

  test('should return failure when repository fails', () async {
    when(
      () => mockRepo.getPostDetail(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('fail')));

    final result = await useCase('/test');

    expect(result, isA<Left<Failure, PostDetail>>());
    result.fold(
      (failure) => expect(failure, isA<ServerFailure>()),
      (_) => fail('Should not return right'),
    );
  });

  test('should propagate NetworkFailure from repository', () async {
    when(
      () => mockRepo.getPostDetail(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('No connection')));

    final result = await useCase('/test');

    expect(result, isA<Left<Failure, PostDetail>>());
    result.fold(
      (failure) => expect(failure, isA<NetworkFailure>()),
      (_) => fail('Should not return right'),
    );
  });

  test('should pass correct url to repository', () async {
    const url = '/board/read.html?table=pds&number=123';
    final detail = PostDetail(
      id: 1,
      title: 't',
      author: 'a',
      date: DateTime(2026),
      contentHtml: '',
      contentBlocks: const [],
      imageUrls: const [],
      recommendCount: 0,
      notRecommendCount: 0,
      viewCount: 0,
      commentCount: 0,
      comments: const [],
    );
    when(
      () => mockRepo.getPostDetail(any()),
    ).thenAnswer((_) async => Right(detail));

    await useCase(url);

    verify(() => mockRepo.getPostDetail(url)).called(1);
  });
}
