import 'package:keek_news/repository/cache/image_cache_repo.dart';

class ManageCacheUseCase {
  const ManageCacheUseCase(this._repo);

  final ImageCacheRepo _repo;

  Future<int> getSizeBytes() => _repo.getSizeBytes();

  Future<void> clear() => _repo.clear();
}
