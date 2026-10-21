import 'dart:async';
import 'dart:convert';

import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/repository/blocked_image/blocked_image_repo.dart';
import 'package:keek_news/service/image_hash_service.dart';
import 'package:keek_news/service/local_storage_service.dart';

class BlockedImageImpl implements BlockedImageRepo {
  BlockedImageImpl(this._storage);

  final LocalStorageService _storage;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const _storageKey = 'blocked_images';

  /// Fingerprints within this Hamming distance count as the same picture.
  static const _matchDistance = 6;

  /// Parsed blocklist cache so render-time hash checks stay synchronous.
  List<BlockedImage>? _cache;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<BlockedImage>> getAll() async => _ensureCache();

  @override
  Future<void> add(BlockedImage image) async {
    final all = _ensureCache();
    final filtered = all.where((b) => b.url != image.url).toList();
    await _persist([image, ...filtered]);
  }

  @override
  Future<void> remove(String url) async {
    final all = _ensureCache();
    final filtered = all.where((b) => b.url != url).toList();
    await _persist(filtered);
  }

  @override
  bool isHashBlocked(String hash) {
    for (final image in _ensureCache()) {
      final blocked = image.hash;
      if (blocked == null) continue;
      if (FlutterImageHashService.distance(hash, blocked) <= _matchDistance) {
        return true;
      }
    }
    return false;
  }

  /// Parsed blocklist cache so render-time hash checks stay synchronous;
  /// storage reads are sync and this repo is the only writer.
  List<BlockedImage> _ensureCache() =>
      _cache ??= _decode(_storage.getString(_storageKey));

  Future<void> _persist(List<BlockedImage> images) async {
    _cache = images;
    await _storage.setString(
      _storageKey,
      jsonEncode(images.map((b) => b.toJson()).toList()),
    );
    _changes.add(null);
  }

  List<BlockedImage> _decode(String? raw) {
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
}
