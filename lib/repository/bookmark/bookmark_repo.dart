import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';

abstract class BookmarkRepo {
  Future<List<Bookmark>> getAll();

  Future<bool> isBookmarked(CommunityId community, String id);

  Future<void> add(Bookmark bookmark);

  Future<void> remove(CommunityId community, String id);
}
