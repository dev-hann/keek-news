import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/service/service_locator.dart';
import 'package:keek_news/use_case/block_image_use_case.dart';

/// Bridge from GetIt so tests can override the use case without touching the
/// DI container.
final blockImageUseCaseProvider = Provider<BlockImageUseCase>(
  (ref) => sl<BlockImageUseCase>(),
);

/// Read-only mirror of the repo blocklist. All mutations go through
/// BlockedImagesNotifier.block / unblock; the repo's changes stream drives
/// reloads so writes from anywhere (sheet, management screen) stay in sync.
final blockedImagesProvider =
    StateNotifierProvider<BlockedImagesNotifier, List<BlockedImage>>(
      (ref) => BlockedImagesNotifier(ref.watch(blockImageUseCaseProvider)),
    );

class BlockedImagesNotifier extends StateNotifier<List<BlockedImage>> {
  BlockedImagesNotifier(this._useCase) : super(const []) {
    _subscription = _useCase.changes.listen((_) => _reload());
    _reload();
  }

  final BlockImageUseCase _useCase;
  StreamSubscription<void>? _subscription;

  Future<void> _reload() async {
    final result = await _useCase.getAll();
    if (mounted) {
      result.fold((_) {}, (images) => state = images);
    }
  }

  Future<Either<Failure, Unit>> block(String url) => _useCase.add(url);

  Future<Either<Failure, Unit>> unblock(String url) => _useCase.remove(url);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
