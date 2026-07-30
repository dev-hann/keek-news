import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';

class IsBookmarked {
  const IsBookmarked({required this.repository});

  final BookmarkRepository repository;

  Future<bool> call(CommunityId community, String id) {
    return repository.isBookmarked(community, id);
  }
}
