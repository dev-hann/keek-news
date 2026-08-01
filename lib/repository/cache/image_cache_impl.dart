import 'package:keek_news/repository/cache/image_cache_repo.dart';
import 'package:keek_news/service/image_cache_service.dart';

class ImageCacheImpl implements ImageCacheRepo {
  ImageCacheImpl(this._service);

  final ImageCacheService _service;

  @override
  Future<int> getSizeBytes() => _service.getSizeBytes();

  @override
  Future<void> clear() => _service.clear();
}
