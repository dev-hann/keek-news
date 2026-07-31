import 'dart:convert';

import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/service/bookmark_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsBookmarkLocalService implements BookmarkLocalService {
  PrefsBookmarkLocalService(this._prefs);

  static const String storageKey = 'bookmarks';

  final SharedPreferences _prefs;

  @override
  Future<List<Bookmark>> getAll() async {
    final raw = _prefs.getString(storageKey);
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
  Future<bool> exists(String key) async {
    final all = await getAll();
    return all.any((b) => b.key == key);
  }

  @override
  Future<void> upsert(Bookmark bookmark) async {
    final all = await getAll();
    final filtered = all.where((b) => b.key != bookmark.key).toList();
    final next = [bookmark, ...filtered];
    await _prefs.setString(
      storageKey,
      jsonEncode(next.map((b) => b.toJson()).toList()),
    );
  }

  @override
  Future<void> remove(String key) async {
    final all = await getAll();
    final filtered = all.where((b) => b.key != key).toList();
    await _prefs.setString(
      storageKey,
      jsonEncode(filtered.map((b) => b.toJson()).toList()),
    );
  }
}
