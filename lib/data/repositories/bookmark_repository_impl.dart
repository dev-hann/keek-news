import 'package:happy_news/data/datasources/bookmark_local_data_source.dart';
import 'package:happy_news/data/models/bookmark_dto.dart';
import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  BookmarkRepositoryImpl(this._dataSource);

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
