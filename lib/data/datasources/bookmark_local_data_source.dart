import 'dart:convert';

import 'package:happy_news/data/models/bookmark_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class BookmarkLocalDataSource {
  Future<List<BookmarkDto>> getAll();

  Future<bool> exists(String key);

  Future<void> upsert(BookmarkDto dto);

  Future<void> remove(String key);
}

class BookmarkLocalDataSourceImpl implements BookmarkLocalDataSource {
  BookmarkLocalDataSourceImpl(this._prefs);

  static const String storageKey = 'bookmarks';

  final SharedPreferences _prefs;

  String _keyOf(BookmarkDto dto) => '${dto.community.name}:${dto.id}';

  @override
  Future<List<BookmarkDto>> getAll() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final result = <BookmarkDto>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          result.add(BookmarkDto.fromJson(entry));
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
  Future<bool> exists(String key) async {
    final all = await getAll();
    return all.any((dto) => _keyOf(dto) == key);
  }

  @override
  Future<void> upsert(BookmarkDto dto) async {
    final all = await getAll();
    final key = _keyOf(dto);
    final filtered = all.where((d) => _keyOf(d) != key).toList();
    final next = <BookmarkDto>[dto, ...filtered];
    await _prefs.setString(
      storageKey,
      jsonEncode(next.map((d) => d.toJson()).toList()),
    );
  }

  @override
  Future<void> remove(String key) async {
    final all = await getAll();
    final filtered = all.where((d) => _keyOf(d) != key).toList();
    await _prefs.setString(
      storageKey,
      jsonEncode(filtered.map((d) => d.toJson()).toList()),
    );
  }
}
