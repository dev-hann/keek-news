import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';

class RemoveBookmark {
  const RemoveBookmark({required this.repository});

  final BookmarkRepository repository;

  Future<void> call(CommunityId community, String id) {
    return repository.remove(community, id);
  }
}
