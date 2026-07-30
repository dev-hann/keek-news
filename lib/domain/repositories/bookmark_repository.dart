import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/entities/community.dart';

abstract class BookmarkRepository {
  Future<List<Bookmark>> getAll();

  Future<bool> isBookmarked(CommunityId community, String id);

  Future<void> add(Bookmark bookmark);

  Future<void> remove(CommunityId community, String id);
}
