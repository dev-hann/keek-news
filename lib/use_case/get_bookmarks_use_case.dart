import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';

class GetBookmarksUseCase {
  const GetBookmarksUseCase({required this.repository});

  final BookmarkRepo repository;

  Future<List<Bookmark>> call() {
    return repository.getAll();
  }
}
