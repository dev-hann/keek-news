import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';

class GetBookmarks {
  const GetBookmarks({required this.repository});

  final BookmarkRepository repository;

  Future<List<Bookmark>> call() {
    return repository.getAll();
  }
}
