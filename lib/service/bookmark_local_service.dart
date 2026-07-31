import 'package:keek_news/model/bookmark.dart';

abstract class BookmarkLocalService {
  Future<List<Bookmark>> getAll();

  Future<bool> exists(String key);

  Future<void> upsert(Bookmark bookmark);

  Future<void> remove(String key);
}
