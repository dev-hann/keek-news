import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/bookmark_dto.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/service/bookmark_local_data_source.dart';

class BookmarkImpl implements BookmarkRepo {
  BookmarkImpl(this._dataSource);

  final BookmarkLocalDataSource _dataSource;

  String _keyOf(CommunityId community, String id) => '${community.name}:$id';

  @override
  Future<List<Bookmark>> getAll() async {
    final dtos = await _dataSource.getAll();
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<bool> isBookmarked(CommunityId community, String id) async {
    return _dataSource.exists(_keyOf(community, id));
  }

  @override
  Future<void> add(Bookmark bookmark) async {
    await _dataSource.upsert(BookmarkDto.fromEntity(bookmark));
  }

  @override
  Future<void> remove(CommunityId community, String id) async {
    await _dataSource.remove(_keyOf(community, id));
  }
}
