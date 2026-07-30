import 'package:dartz/dartz.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/merged_feed.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';

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

class GetMergedFeedUseCase {
  const GetMergedFeedUseCase({required this.repository});
  final MergedFeedRepo repository;

  Future<Either<Failure, MergedPage>> call(MergedFeedParams params) {
    return repository.fetchMerged(
      perSource: params.perSource,
      cursor: params.cursor,
      enabled: params.enabled,
    );
  }
}
