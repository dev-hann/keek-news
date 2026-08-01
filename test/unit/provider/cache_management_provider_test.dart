import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/provider/cache_management_provider.dart';
import 'package:keek_news/use_case/manage_cache_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockManageCacheUseCase extends Mock implements ManageCacheUseCase {}

void main() {
  late MockManageCacheUseCase useCase;
  late CacheManagementNotifier notifier;

  setUp(() {
    useCase = MockManageCacheUseCase();
    notifier = CacheManagementNotifier(useCase);
  });

  tearDown(() => notifier.dispose());

  group('CacheManagementNotifier', () {
    test('initial state has null size and not loading', () {
      expect(notifier.state.sizeBytes, isNull);
      expect(notifier.state.loading, false);
    });

    test('loadSize stores the reported cache size', () async {
      when(useCase.getSizeBytes).thenAnswer((_) async => 4096);

      await notifier.loadSize();

      expect(notifier.state.sizeBytes, 4096);
      expect(notifier.state.loading, false);
    });

    test('clear empties the cache and refreshes the size', () async {
      when(useCase.clear).thenAnswer((_) async {});
      when(useCase.getSizeBytes).thenAnswer((_) async => 0);

      await notifier.clear();

      verify(useCase.clear).called(1);
      verify(useCase.getSizeBytes).called(1);
      expect(notifier.state.sizeBytes, 0);
      expect(notifier.state.loading, false);
    });

    test('clear sets loading during the operation', () async {
      var cleared = false;
      when(useCase.clear).thenAnswer((_) async {
        cleared = true;
      });
      when(useCase.getSizeBytes).thenAnswer((_) async => 0);

      final future = notifier.clear();
      expect(notifier.state.loading, true);
      await future;
      expect(cleared, true);
      expect(notifier.state.loading, false);
    });

    test('provider resolves with the registered use case', () {
      final container = ProviderContainer(
        overrides: [
          cacheManagementProvider.overrideWith(
            (ref) => CacheManagementNotifier(useCase),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(cacheManagementProvider).sizeBytes, isNull);
    });
  });
}
