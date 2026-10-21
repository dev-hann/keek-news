import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/pages/blocked_images_view.dart';
import 'package:keek_news/provider/blocked_images_provider.dart';
import 'package:keek_news/use_case/block_image_use_case.dart';
import 'package:keek_news/widgets/blocked_image_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/media_action_fakes.dart';
import '../../helpers/shad_harness.dart';

class _FailingRemoveRepo extends StubBlockedImageRepo {
  @override
  Future<void> remove(String url) async {
    throw Exception('boom');
  }
}

void main() {
  ProviderContainer makeContainer(StubBlockedImageRepo repo) {
    final container = ProviderContainer(
      overrides: [
        blockImageUseCaseProvider.overrideWithValue(BlockImageUseCase(repo)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: shadApp(
          home: const ScaffoldMessenger(child: BlockedImagesView()),
        ),
      ),
    );
    // The provider's initial load is a pure-microtask chain; pumps flush it.
    await tester.pump();
    await tester.pump();
  }

  /// Expires the 4s undo snackbar timer so no timer outlives the test.
  Future<void> expireSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> seedBlock(StubBlockedImageRepo repo, String url) =>
      repo.add(BlockedImage(url: url, blockedAt: DateTime.now()));

  group('BlockedImagesView', () {
    testWidgets('shows the empty state when nothing is blocked', (
      tester,
    ) async {
      await pumpScreen(tester, makeContainer(StubBlockedImageRepo()));

      expect(find.text('차단된 이미지'), findsOneWidget);
      expect(find.text('차단된 이미지가 없어요'), findsOneWidget);
    });

    testWidgets('renders a row per blocked image', (tester) async {
      final repo = StubBlockedImageRepo();
      await seedBlock(repo, 'https://example.com/a.jpg');
      await seedBlock(repo, 'https://example.com/b.jpg');
      await pumpScreen(tester, makeContainer(repo));

      expect(find.byType(BlockedImageTile), findsNWidgets(2));
      expect(
        find.text('https://example.com/a.jpg'),
        findsOneWidget,
        reason: 'newest block renders first',
      );
    });

    testWidgets('unblock removes the row and shows a snackbar', (tester) async {
      final repo = StubBlockedImageRepo();
      await seedBlock(repo, 'https://example.com/a.jpg');
      await pumpScreen(tester, makeContainer(repo));

      await tester.tap(find.byIcon(LucideIcons.rotateCcw));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(BlockedImageTile), findsNothing);
      expect(find.text('차단을 해제했어요'), findsOneWidget);
      expect(repo.removedUrls, ['https://example.com/a.jpg']);
      expect(find.text('차단된 이미지가 없어요'), findsOneWidget);

      await expireSnackbar(tester);
    });

    testWidgets('failed unblock shows an error snackbar', (tester) async {
      final repo = _FailingRemoveRepo();
      await seedBlock(repo, 'https://example.com/a.jpg');
      await pumpScreen(tester, makeContainer(repo));

      await tester.tap(find.byIcon(LucideIcons.rotateCcw));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('차단 해제에 실패했어요'), findsOneWidget);
      expect(find.byType(BlockedImageTile), findsOneWidget);

      await expireSnackbar(tester);
    });
  });
}
