import 'package:dartz/dartz.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';

abstract class CommunityRepo {
  CommunityId get communityId;

  Future<Either<Failure, CommunityListResult>> fetchLatest({String? pageToken});

  Future<Either<Failure, PostDetail>> fetchDetail(String id);
}

class CommunityListResult {
  const CommunityListResult({required this.items, this.pageToken});
  final List<FeedItem> items;
  final String? pageToken;
}

Failure toFailure(Object error) {
  if (error is Failure) return error;
  return ServerFailure(error.toString());
}
