import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';

class IsBookmarkedUseCase {
  const IsBookmarkedUseCase({required this.repository});

  final BookmarkRepo repository;

  Future<bool> call(CommunityId community, String id) {
    return repository.isBookmarked(community, id);
  }
}
