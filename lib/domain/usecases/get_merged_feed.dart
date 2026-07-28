import 'package:dartz/dartz.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';
import 'package:humoruniv/domain/repositories/merged_feed_repository.dart';

class MergedFeedParams {
  const MergedFeedParams({
    this.perSource = 20,
    this.cursor,
    this.enabled = const {},
  });

  final int perSource;
  final MergedCursor? cursor;
  final Set<CommunityId> enabled;
}

class GetMergedFeed {
  const GetMergedFeed({required this.repository});
  final MergedFeedRepository repository;

  Future<Either<Failure, MergedPage>> call(MergedFeedParams params) {
    return repository.fetchMerged(
      perSource: params.perSource,
      cursor: params.cursor,
      enabled: params.enabled,
    );
  }
}
