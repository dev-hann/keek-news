import 'package:humoruniv/domain/entities/community.dart';
import 'package:meta/meta.dart';

@immutable
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.recommendCount,
    required this.url,
    this.community = CommunityId.humoruniv,
  });
  final int id;
  final String title;
  final int recommendCount;
  final String url;
  final CommunityId community;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          recommendCount == other.recommendCount &&
          url == other.url &&
          community == other.community;

  @override
  int get hashCode => Object.hash(id, title, recommendCount, url, community);
}
