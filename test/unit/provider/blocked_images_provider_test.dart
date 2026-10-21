import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/provider/blocked_images_provider.dart';
import 'package:keek_news/use_case/block_image_use_case.dart';

import '../../helpers/media_action_fakes.dart';

void main() {
  group('blockedImagesProvider', () {
    test('should load the blocklist on creation', () async {
      final repo = StubBlockedImageRepo();
      await repo.add(
        BlockedImage(
          url: 'https://x/a.jpg',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          blockImageUseCaseProvider.overrideWithValue(BlockImageUseCase(repo)),
        ],
      );
      addTearDown(container.dispose);

      // Reading the notifier creates the provider; its initial async load
      // settles after a microtask tick.
      container.read(blockedImagesProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(blockedImagesProvider).map((b) => b.url), [
        'https://x/a.jpg',
      ]);
    });

    test('should reload when the repo emits changes', () async {
      final repo = StubBlockedImageRepo();
      final container = ProviderContainer(
        overrides: [
          blockImageUseCaseProvider.overrideWithValue(BlockImageUseCase(repo)),
        ],
      );
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(blockedImagesProvider), isEmpty);

      await container
          .read(blockedImagesProvider.notifier)
          .block('https://x/b.jpg');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(blockedImagesProvider).map((b) => b.url), [
        'https://x/b.jpg',
      ]);
    });

    test('unblock should remove the url through the repo', () async {
      final repo = StubBlockedImageRepo();
      await repo.add(
        BlockedImage(
          url: 'https://x/a.jpg',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          blockImageUseCaseProvider.overrideWithValue(BlockImageUseCase(repo)),
        ],
      );
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(blockedImagesProvider.notifier)
          .unblock('https://x/a.jpg');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(blockedImagesProvider), isEmpty);
      expect(repo.removedUrls, ['https://x/a.jpg']);
    });
  });
}
