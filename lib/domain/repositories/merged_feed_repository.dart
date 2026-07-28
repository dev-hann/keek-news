import 'package:dartz/dartz.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';

abstract class MergedFeedRepository {
  Future<Either<Failure, MergedPage>> fetchMerged({
    required int perSource,
    MergedCursor? cursor,
    Set<CommunityId> enabled = const {},
    double maxRatioPerSource = 0.4,
  });

  Future<Either<Failure, PostDetail>> fetchDetail({
    required CommunityId community,
    required String id,
  });
}
