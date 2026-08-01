import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';

class BookmarkUseCase {
  const BookmarkUseCase(this._repo);

  final BookmarkRepo _repo;

  Future<List<Bookmark>> getAll() => _repo.getAll();

  Future<bool> isBookmarked(CommunityId community, String id) {
    return _repo.isBookmarked(community, id);
  }

  Future<void> add(Bookmark bookmark) => _repo.add(bookmark);

  Future<void> remove(CommunityId community, String id) {
    return _repo.remove(community, id);
  }
}
