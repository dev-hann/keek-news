import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds.dart';
import 'package:happy_news/domain/entities/board_list_result.dart';
import 'package:happy_news/domain/entities/post.dart';
import 'package:happy_news/domain/entities/post_detail.dart';
import 'package:happy_news/domain/entities/sort_option.dart';
import 'package:happy_news/domain/repositories/post_repository.dart';

class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl({required this.remoteDs});
  final HumorunivRemoteDs remoteDs;
  final Map<String, PostDetail> _detailCache = {};
  final Map<String, Future<Either<Failure, PostDetail>>> _inFlight = {};

  @override
  Future<Either<Failure, List<Post>>> getBestPosts() async {
    try {
      final dtos = await remoteDs.fetchMainPage();
      final posts = dtos.map((dto) => dto.toEntity()).toList();
      return Right(posts);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, PostDetail>> getPostDetail(String url) async {
    final cached = _detailCache[url];
    if (cached != null) return Right(cached);

    final existing = _inFlight[url];
    if (existing != null) return existing;

    final future = _fetchDetail(url);
    _inFlight[url] = future;
    try {
      final result = await future;
      result.fold((_) => null, (detail) => _detailCache[url] = detail);
      return result;
    } finally {
      _inFlight.remove(url);
    }
  }

  Future<Either<Failure, PostDetail>> _fetchDetail(String url) async {
    try {
      final detail = await remoteDs.fetchPostDetail(url);
      return Right(detail);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, BoardListResult>> getBoardPosts(
    String table,
    int page,
    SortOption sort,
  ) async {
    try {
      final result = await remoteDs.fetchBoardList(table, page, sort.value);
      final posts = result.posts.map((dto) => dto.toEntity()).toList();
      return Right(
        BoardListResult(
          posts: posts,
          currentPage: result.currentPage,
          totalPage: result.totalPage,
        ),
      );
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
