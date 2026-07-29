import 'package:dartz/dartz.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/entities/merged_feed.dart';
import 'package:happy_news/domain/entities/post_detail.dart';

abstract class MergedFeedRepository {
  Future<Either<Failure, MergedPage>> fetchMerged({
    required int perSource,
    MergedCursor? cursor,
    Set<CommunityId> enabled = const {},
  });

  Future<Either<Failure, PostDetail>> fetchDetail({
    required CommunityId community,
    required String id,
  });
}
