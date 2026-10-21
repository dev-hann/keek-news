import 'dart:async';
import 'dart:convert';

import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/repository/blocked_image/blocked_image_repo.dart';
import 'package:keek_news/service/local_storage_service.dart';

class BlockedImageImpl implements BlockedImageRepo {
  BlockedImageImpl(this._storage);

  final LocalStorageService _storage;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const _storageKey = 'blocked_images';

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<BlockedImage>> getAll() async {
    final raw = _storage.getString(_storageKey);
    if (raw == null) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final result = <BlockedImage>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          result.add(BlockedImage.fromJson(entry));
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
  Future<void> add(BlockedImage image) async {
    final all = await getAll();
    final filtered = all.where((b) => b.url != image.url).toList();
    final next = [image, ...filtered];
    await _storage.setString(
      _storageKey,
      jsonEncode(next.map((b) => b.toJson()).toList()),
    );
    _changes.add(null);
  }

  @override
  Future<void> remove(String url) async {
    final all = await getAll();
    final filtered = all.where((b) => b.url != url).toList();
    await _storage.setString(
      _storageKey,
      jsonEncode(filtered.map((b) => b.toJson()).toList()),
    );
    _changes.add(null);
  }
}
