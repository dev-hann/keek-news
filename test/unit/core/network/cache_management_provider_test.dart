import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/datasources/image_cache_service.dart';
import 'package:happy_news/presentation/providers/cache_management_provider.dart';
import 'package:mocktail/mocktail.dart';

class _FakeImageCacheService extends Mock implements ImageCacheService {}

void main() {
  late _FakeImageCacheService service;
  late CacheManagementNotifier notifier;

  setUp(() {
    service = _FakeImageCacheService();
    notifier = CacheManagementNotifier(service);
  });

  tearDown(() => notifier.dispose());

  group('CacheManagementNotifier', () {
    test('initial state has null size and not loading', () {
      expect(notifier.state.sizeBytes, isNull);
      expect(notifier.state.loading, false);
    });

    test('loadSize stores the reported cache size', () async {
      when(service.getSizeBytes).thenAnswer((_) async => 4096);

      await notifier.loadSize();

      expect(notifier.state.sizeBytes, 4096);
      expect(notifier.state.loading, false);
    });

    test('clear empties the cache and refreshes the size', () async {
      when(service.clear).thenAnswer((_) async {});
      when(service.getSizeBytes).thenAnswer((_) async => 0);

      await notifier.clear();

      verify(service.clear).called(1);
      verify(service.getSizeBytes).called(1);
      expect(notifier.state.sizeBytes, 0);
      expect(notifier.state.loading, false);
    });

    test('clear sets loading during the operation', () async {
      var cleared = false;
      when(service.clear).thenAnswer((_) async {
        cleared = true;
      });
      when(service.getSizeBytes).thenAnswer((_) async => 0);

      final future = notifier.clear();
      expect(notifier.state.loading, true);
      await future;
      expect(cleared, true);
      expect(notifier.state.loading, false);
    });

    test('provider resolves with the registered service', () {
      final container = ProviderContainer(
        overrides: [
          cacheManagementProvider.overrideWith(
            (ref) => CacheManagementNotifier(service),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(cacheManagementProvider).sizeBytes, isNull);
    });
  });
}
