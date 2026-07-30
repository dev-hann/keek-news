import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/service/image_cache_service.dart';
import 'package:keek_news/service/service_locator.dart';

class CacheManagementState {
  const CacheManagementState({this.sizeBytes, this.loading = false});
  final int? sizeBytes;
  final bool loading;

  CacheManagementState copyWith({int? sizeBytes, bool? loading}) =>
      CacheManagementState(
        sizeBytes: sizeBytes ?? this.sizeBytes,
        loading: loading ?? this.loading,
      );
}

class CacheManagementNotifier extends StateNotifier<CacheManagementState> {
  CacheManagementNotifier(this._service) : super(const CacheManagementState());
  final ImageCacheService _service;

  Future<void> loadSize() async {
    state = state.copyWith(loading: true);
    final size = await _service.getSizeBytes();
    state = CacheManagementState(sizeBytes: size);
  }

  Future<void> clear() async {
    state = state.copyWith(loading: true);
    await _service.clear();
    final size = await _service.getSizeBytes();
    state = CacheManagementState(sizeBytes: size);
  }
}

final cacheManagementProvider =
    StateNotifierProvider<CacheManagementNotifier, CacheManagementState>(
      (ref) => CacheManagementNotifier(sl<ImageCacheService>()),
    );
