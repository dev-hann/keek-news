import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:keek_news/service/image_cache_service.dart';
import 'package:path_provider/path_provider.dart';

class DefaultImageCacheService implements ImageCacheService {
  const DefaultImageCacheService();

  /// `flutter_cache_manager`'s `DefaultCacheManager` stores files under a
  /// folder named [DefaultCacheManager.key] ("libCachedImageData") inside the
  /// system temporary directory.
  static const String _cacheFolderName = DefaultCacheManager.key;

  @override
  Future<int> getSizeBytes() async {
    final tmp = await getTemporaryDirectory();
    final cacheDir = Directory('${tmp.path}/$_cacheFolderName');
    if (!cacheDir.existsSync()) return 0;
    var total = 0;
    await for (final entity in cacheDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  @override
  Future<void> clear() async {
    await DefaultCacheManager().emptyCache();
  }
}
