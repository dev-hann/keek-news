import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';

class AddBookmark {
  const AddBookmark({required this.repository});

  final BookmarkRepository repository;

  Future<void> call(Bookmark bookmark) {
    return repository.add(bookmark);
  }
}
