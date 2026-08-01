import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/service/service_locator.dart';
import 'package:keek_news/use_case/cache_use_case.dart';

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
  CacheManagementNotifier(this._useCase) : super(const CacheManagementState());
  final CacheUseCase _useCase;

  Future<void> loadSize() async {
    state = state.copyWith(loading: true);
    final result = await _useCase.getSizeBytes();
    result.fold(
      (_) => state = state.copyWith(loading: false),
      (size) => state = CacheManagementState(sizeBytes: size),
    );
  }

  Future<void> clear() async {
    state = state.copyWith(loading: true);
    final clearResult = await _useCase.clear();
    if (clearResult.isRight()) {
      final sizeResult = await _useCase.getSizeBytes();
      sizeResult.fold(
        (_) => state = state.copyWith(loading: false),
        (size) => state = CacheManagementState(sizeBytes: size),
      );
    } else {
      state = state.copyWith(loading: false);
    }
  }
}

final cacheManagementProvider =
    StateNotifierProvider<CacheManagementNotifier, CacheManagementState>(
      (ref) => CacheManagementNotifier(sl<CacheUseCase>()),
    );
