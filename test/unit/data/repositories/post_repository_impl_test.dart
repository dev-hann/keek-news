import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds.dart';
import 'package:happy_news/data/models/board_post_dto.dart';
import 'package:happy_news/data/models/post_dto.dart';
import 'package:happy_news/data/repositories/post_repository_impl.dart';
import 'package:happy_news/domain/entities/board_list_result.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/domain/entities/post.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:happy_news/domain/entities/sort_option.dart';
import 'package:mocktail/mocktail.dart';

class MockHumorunivRemoteDs extends Mock implements HumorunivRemoteDs {}

void main() {
  late MockHumorunivRemoteDs mockRemoteDs;
  late PostRepositoryImpl repository;

  setUp(() {
    mockRemoteDs = MockHumorunivRemoteDs();
    repository = PostRepositoryImpl(remoteDs: mockRemoteDs);
  });

  group('PostRepositoryImpl', () {
    test('should return Right with Post list when remoteDs succeeds', () async {
      final dtos = [
        const PostDto(
          id: 1,
          title: 'Post 1',
          recommendCount: 100,
          url: '/board/read.html?table=pds&number=1',
        ),
        const PostDto(
          id: 2,
          title: 'Post 2',
          recommendCount: 200,
          url: '/board/read.html?table=pds&number=2',
        ),
      ];
      when(() => mockRemoteDs.fetchMainPage()).thenAnswer((_) async => dtos);

      final result = await repository.getBestPosts();

      expect(result, isA<Right<Failure, List<Post>>>());
      result.fold((l) => fail('Should not return left'), (posts) {
        expect(posts.length, equals(2));
        expect(posts.first.id, equals(1));
        expect(posts.first.title, equals('Post 1'));
        expect(posts.last.recommendCount, equals(200));
      });
    });

    test(
      'should return Left with ServerFailure when remoteDs throws',
      () async {
        when(
          () => mockRemoteDs.fetchMainPage(),
        ).thenThrow(const ServerFailure('HTTP 500'));

        final result = await repository.getBestPosts();

        expect(result, isA<Left<Failure, List<Post>>>());
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (r) => fail('Should not return right'),
        );
      },
    );

    test(
      'should return Left with NetworkFailure when connection fails',
      () async {
        when(
          () => mockRemoteDs.fetchMainPage(),
        ).thenThrow(const NetworkFailure('No connection'));

        final result = await repository.getBestPosts();

        expect(result, isA<Left<Failure, List<Post>>>());
        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (r) => fail('Should not return right'),
        );
      },
    );

    test(
      'should return Right with PostDetail when getPostDetail succeeds',
      () async {
        final detail = PostDetail(
          id: 123,
          title: '테스트',
          author: '작성자',
          date: DateTime(2026, 5, 15),
          contentHtml: '<p>내용</p>',
          contentBlocks: const [TextBlock('내용')],
          imageUrls: const [],
          recommendCount: 100,
          notRecommendCount: 5,
          viewCount: 1000,
          commentCount: 10,
          comments: const [],
        );
        when(
          () => mockRemoteDs.fetchPostDetail(any()),
        ).thenAnswer((_) async => detail);

        final result = await repository.getPostDetail(
          '/board/read.html?table=pds&number=123',
        );

        expect(result, isA<Right<Failure, PostDetail>>());
        result.fold((l) => fail('Should not return left'), (detail) {
          expect(detail.title, '테스트');
          expect(detail.author, '작성자');
          expect(detail.recommendCount, 100);
        });
      },
    );

    test(
      'should return Left with ServerFailure when getPostDetail throws',
      () async {
        when(
          () => mockRemoteDs.fetchPostDetail(any()),
        ).thenThrow(const ServerFailure('fail'));

        final result = await repository.getPostDetail(
          '/board/read.html?table=pds&number=123',
        );

        expect(result, isA<Left<Failure, PostDetail>>());
      },
    );

    test(
      'should cache PostDetail and skip remoteDs on second call with same url',
      () async {
        final detail = PostDetail(
          id: 123,
          title: '캐시',
          author: '작성자',
          date: DateTime(2026, 5, 15),
          contentHtml: '<p>x</p>',
          contentBlocks: const [TextBlock('x')],
          imageUrls: const [],
          recommendCount: 1,
          notRecommendCount: 0,
          viewCount: 1,
          commentCount: 0,
          comments: const [],
        );
        when(
          () => mockRemoteDs.fetchPostDetail(any()),
        ).thenAnswer((_) async => detail);

        await repository.getPostDetail('/board/read.html?table=pds&number=123');
        await repository.getPostDetail('/board/read.html?table=pds&number=123');

        verify(() => mockRemoteDs.fetchPostDetail(any())).called(1);
      },
    );

    test(
      'should dedup concurrent getPostDetail calls to a single remoteDs call',
      () async {
        final detail = PostDetail(
          id: 123,
          title: '동시',
          author: '작성자',
          date: DateTime(2026, 5, 15),
          contentHtml: '<p>x</p>',
          contentBlocks: const [TextBlock('x')],
          imageUrls: const [],
          recommendCount: 1,
          notRecommendCount: 0,
          viewCount: 1,
          commentCount: 0,
          comments: const [],
        );
        when(() => mockRemoteDs.fetchPostDetail(any())).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return detail;
        });

        final results = await Future.wait([
          repository.getPostDetail('/board/read.html?table=pds&number=123'),
          repository.getPostDetail('/board/read.html?table=pds&number=123'),
        ]);

        verify(() => mockRemoteDs.fetchPostDetail(any())).called(1);
        expect(results.every((r) => r.isRight()), isTrue);
      },
    );

    test(
      'should return Right with BoardListResult when getBoardPosts succeeds',
      () async {
        const dsResult = BoardListDsResult(
          posts: [
            BoardPostDto(
              id: 1,
              title: 'Board Post',
              url: '/board/read.html?table=pds&number=1',
              author: 'user',
              date: '2026-05-15',
              recommendCount: 50,
              notRecommendCount: 2,
              commentCount: 10,
              viewCount: 500,
              thumbnailUrl: '',
            ),
          ],
          currentPage: 0,
          totalPage: 5,
        );
        when(
          () => mockRemoteDs.fetchBoardList('pds', 0, ''),
        ).thenAnswer((_) async => dsResult);

        final result = await repository.getBoardPosts('pds', 0, SortOption.all);

        expect(result, isA<Right<Failure, BoardListResult>>());
        result.fold((_) => fail('Should not return left'), (data) {
          expect(data.posts, hasLength(1));
          expect(data.posts.first.title, 'Board Post');
          expect(data.currentPage, 0);
          expect(data.totalPage, 5);
        });
      },
    );

    test(
      'should return Left with ServerFailure when getBoardPosts throws',
      () async {
        when(
          () => mockRemoteDs.fetchBoardList(any(), any(), any()),
        ).thenThrow(const ServerFailure('fail'));

        final result = await repository.getBoardPosts('pds', 0, SortOption.all);

        expect(result, isA<Left<Failure, BoardListResult>>());
      },
    );
  });
}
