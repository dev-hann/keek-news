import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';

class RemoveBookmarkUseCase {
  const RemoveBookmarkUseCase({required this.repository});

  final BookmarkRepo repository;

  Future<void> call(CommunityId community, String id) {
    return repository.remove(community, id);
  }
}
