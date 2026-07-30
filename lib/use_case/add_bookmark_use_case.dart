import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';

class AddBookmarkUseCase {
  const AddBookmarkUseCase({required this.repository});

  final BookmarkRepo repository;

  Future<void> call(Bookmark bookmark) {
    return repository.add(bookmark);
  }
}
