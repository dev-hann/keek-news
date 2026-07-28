import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/di/injection.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';
import 'package:humoruniv/domain/repositories/merged_feed_repository.dart';
import 'package:humoruniv/domain/usecases/get_merged_feed.dart';

final mergedFeedProvider =
    FutureProvider.autoDispose<Either<Failure, MergedPage>>((ref) {
  return sl<GetMergedFeed>()(const MergedFeedParams());
});

final mergedDetailProvider = FutureProvider.autoDispose
    .family<Either<Failure, PostDetail>, ({CommunityId community, String id})>(
        (ref, key) {
  return sl<MergedFeedRepository>().fetchDetail(
    community: key.community,
    id: key.id,
  );
});
