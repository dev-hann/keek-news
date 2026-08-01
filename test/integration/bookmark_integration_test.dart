import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/provider/bookmark_provider.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/repository/bookmark/bookmark_impl.dart';
import 'package:keek_news/service/bookmark_local_service.dart';
import 'package:keek_news/service/prefs_bookmark_local_service.dart';
import 'package:keek_news/use_case/bookmark_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late BookmarkLocalService dataSource;
  late BookmarkRepo repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dataSource = PrefsBookmarkLocalService(prefs);
    repository = BookmarkImpl(dataSource);
  });

  Bookmark bookmark({
    CommunityId community = CommunityId.humoruniv,
    String id = '1',
    String title = '제목',
  }) {
    return Bookmark(
      community: community,
      id: id,
      title: title,
      url: '/url-$id',
      author: 'writer',
      savedAt: DateTime(2026, 7, 30, 10),
    );
  }

  ProviderContainer containerWith(BookmarkRepo repo) => ProviderContainer(
    overrides: [
      bookmarkProvider.overrideWith(
        (ref) => BookmarkNotifier(BookmarkUseCase(repo)),
      ),
    ],
  );

  group('Bookmark integration', () {
    test('save bookmark persists across repository instances', () async {
      final bm = bookmark(id: '100');
      await repository.add(bm);

      final freshRepo = BookmarkImpl(PrefsBookmarkLocalService(prefs));
      final all = await freshRepo.getAll();

      expect(all.length, 1);
      expect(all.first.id, '100');
      expect(all.first.title, '제목');
    });

    test(
      'toggle add then remove via notifier updates state and storage',
      () async {
        final container = containerWith(repository);
        addTearDown(container.dispose);

        await container.read(bookmarkProvider.notifier).load();
        expect(container.read(bookmarkProvider), isEmpty);

        final bm = bookmark();
        final added = await container
            .read(bookmarkProvider.notifier)
            .toggle(bm);
        expect(added, isTrue);
        expect(container.read(bookmarkProvider).length, 1);

        final removed = await container
            .read(bookmarkProvider.notifier)
            .toggle(bm);
        expect(removed, isFalse);
        expect(container.read(bookmarkProvider), isEmpty);

        final freshContainer = containerWith(repository);
        addTearDown(freshContainer.dispose);
        await freshContainer.read(bookmarkProvider.notifier).load();
        expect(freshContainer.read(bookmarkProvider), isEmpty);
      },
    );

    test('multiple bookmarks keep most-recent-saved-first order', () async {
      final container = containerWith(repository);
      addTearDown(container.dispose);

      await container.read(bookmarkProvider.notifier).load();
      await container.read(bookmarkProvider.notifier).toggle(bookmark());
      await container.read(bookmarkProvider.notifier).toggle(bookmark(id: '2'));
      await container.read(bookmarkProvider.notifier).toggle(bookmark(id: '3'));

      final state = container.read(bookmarkProvider);
      expect(state.map((b) => b.id), ['3', '2', '1']);
    });

    test('isBookmarked reflects state after toggle operations', () async {
      final container = containerWith(repository);
      addTearDown(container.dispose);
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.load();

      expect(notifier.isBookmarked(CommunityId.humoruniv, '7'), isFalse);

      await notifier.toggle(bookmark(id: '7'));

      expect(notifier.isBookmarked(CommunityId.humoruniv, '7'), isTrue);
    });

    test('remove by key deletes only the matching bookmark', () async {
      final container = containerWith(repository);
      addTearDown(container.dispose);
      final notifier = container.read(bookmarkProvider.notifier);
      await notifier.load();

      await notifier.toggle(bookmark());
      await notifier.toggle(bookmark(id: '2'));
      await notifier.remove(CommunityId.humoruniv, '1');

      expect(container.read(bookmarkProvider).length, 1);
      expect(container.read(bookmarkProvider).first.id, '2');
    });
  });
}
