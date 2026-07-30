import 'package:dartz/dartz.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/model/post_detail.dart';

abstract class MergedFeedRepo {
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
