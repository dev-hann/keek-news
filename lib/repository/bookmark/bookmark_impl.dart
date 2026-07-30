import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/service/bookmark_local_data_source.dart';

class BookmarkImpl implements BookmarkRepo {
  BookmarkImpl(this._dataSource);

  final BookmarkLocalDataSource _dataSource;

  String _keyOf(CommunityId community, String id) => '${community.name}:$id';

  @override
  Future<List<Bookmark>> getAll() => _dataSource.getAll();

  @override
  Future<bool> isBookmarked(CommunityId community, String id) {
    return _dataSource.exists(_keyOf(community, id));
  }

  @override
  Future<void> add(Bookmark bookmark) => _dataSource.upsert(bookmark);

  @override
  Future<void> remove(CommunityId community, String id) {
    return _dataSource.remove(_keyOf(community, id));
  }
}
