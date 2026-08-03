import 'dart:convert';

import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/service/local_storage_service.dart';

class BookmarkImpl implements BookmarkRepo {
  BookmarkImpl(this._storage);

  final LocalStorageService _storage;

  static const _storageKey = 'bookmarks';

  String _keyOf(CommunityId community, String id) => '${community.name}:$id';

  @override
  Future<List<Bookmark>> getAll() async {
    final raw = _storage.getString(_storageKey);
    if (raw == null) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final result = <Bookmark>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          result.add(Bookmark.fromJson(entry));
        } catch (_) {
          continue;
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> isBookmarked(CommunityId community, String id) async {
    final all = await getAll();
    return all.any((b) => b.key == _keyOf(community, id));
  }

  @override
  Future<void> add(Bookmark bookmark) async {
    final all = await getAll();
    final filtered = all.where((b) => b.key != bookmark.key).toList();
    final next = [bookmark, ...filtered];
    await _storage.setString(
      _storageKey,
      jsonEncode(next.map((b) => b.toJson()).toList()),
    );
  }

  @override
  Future<void> remove(CommunityId community, String id) async {
    final all = await getAll();
    final filtered = all.where((b) => b.key != _keyOf(community, id)).toList();
    await _storage.setString(
      _storageKey,
      jsonEncode(filtered.map((b) => b.toJson()).toList()),
    );
  }
}
