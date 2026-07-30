import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';
import 'package:happy_news/presentation/providers/bookmark_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

Bookmark _bookmark({
  CommunityId community = CommunityId.humoruniv,
  String id = '1',
  DateTime? savedAt,
}) {
  return Bookmark(
    community: community,
    id: id,
    title: 'title-$id',
    url: 'url-$id',
    savedAt: savedAt ?? DateTime(2026, 7, 30, 10),
  );
}

void main() {
  late MockBookmarkRepository repo;

  setUp(() {
    repo = MockBookmarkRepository();
    when(() => repo.getAll()).thenAnswer((_) async => const []);
    registerFallbackValue(
      Bookmark(
        community: CommunityId.humoruniv,
        id: 'fallback',
        title: '',
        url: '',
        savedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [bookmarkRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('BookmarkNotifier', () {
    test('initial state should be empty list', () {
      final notifier = BookmarkNotifier(repo);

      expect(notifier.state, isEmpty);
    });

    test('load should populate state from repository', () async {
      final bookmarks = [_bookmark(id: '1'), _bookmark(id: '2')];
      when(() => repo.getAll()).thenAnswer((_) async => bookmarks);
      final notifier = BookmarkNotifier(repo);

      await notifier.load();

      expect(notifier.state.length, 2);
      expect(notifier.state[0].id, '1');
      expect(notifier.state[1].id, '2');
    });

    test('isBookmarked should return true when bookmark in state', () async {
      when(() => repo.getAll()).thenAnswer((_) async => [_bookmark(id: '7')]);
      final notifier = BookmarkNotifier(repo);
      await notifier.load();

      expect(notifier.isBookmarked(CommunityId.humoruniv, '7'), isTrue);
    });

    test('isBookmarked should return false when bookmark not in state', () {
      final notifier = BookmarkNotifier(repo);

      expect(notifier.isBookmarked(CommunityId.humoruniv, '99'), isFalse);
    });

    test(
      'toggle should add bookmark when not present and return true',
      () async {
        when(() => repo.add(any())).thenAnswer((_) async {});
        when(() => repo.getAll()).thenAnswer((_) async => const []);
        final notifier = BookmarkNotifier(repo);
        await notifier.load();

        final result = await notifier.toggle(_bookmark(id: '1'));

        expect(result, isTrue);
        verify(() => repo.add(any())).called(1);
      },
    );

    test(
      'toggle should remove bookmark when present and return false',
      () async {
        final existing = _bookmark(id: '1');
        when(() => repo.getAll()).thenAnswer((_) async => [existing]);
        when(
          () => repo.remove(CommunityId.humoruniv, '1'),
        ).thenAnswer((_) async {});
        final notifier = BookmarkNotifier(repo);
        await notifier.load();

        final result = await notifier.toggle(existing);

        expect(result, isFalse);
        verify(() => repo.remove(CommunityId.humoruniv, '1')).called(1);
      },
    );

    test('toggle add should update state with new bookmark at front', () async {
      when(() => repo.getAll()).thenAnswer((_) async => [_bookmark(id: '1')]);
      when(() => repo.add(any())).thenAnswer((_) async {});
      final notifier = BookmarkNotifier(repo);
      await notifier.load();

      await notifier.toggle(_bookmark(id: '2'));

      expect(notifier.state.first.id, '2');
      expect(notifier.state.length, 2);
    });

    test(
      'toggle remove should update state without removed bookmark',
      () async {
        final first = _bookmark(id: '1');
        final second = _bookmark(id: '2');
        when(() => repo.getAll()).thenAnswer((_) async => [first, second]);
        when(
          () => repo.remove(CommunityId.humoruniv, '2'),
        ).thenAnswer((_) async {});
        final notifier = BookmarkNotifier(repo);
        await notifier.load();

        await notifier.toggle(second);

        expect(notifier.state.length, 1);
        expect(notifier.state.first.id, '1');
      },
    );

    test('remove should delete bookmark from state by key', () async {
      final first = _bookmark(id: '1');
      final second = _bookmark(id: '2');
      when(() => repo.getAll()).thenAnswer((_) async => [first, second]);
      when(
        () => repo.remove(CommunityId.humoruniv, '1'),
      ).thenAnswer((_) async {});
      final notifier = BookmarkNotifier(repo);
      await notifier.load();

      await notifier.remove(CommunityId.humoruniv, '1');

      expect(notifier.state.length, 1);
      expect(notifier.state.first.id, '2');
    });
  });

  group('bookmarkProvider', () {
    test(
      'should expose BookmarkNotifier wired to repository override',
      () async {
        when(() => repo.getAll()).thenAnswer((_) async => [_bookmark(id: '5')]);
        final container = makeContainer();

        await container.read(bookmarkProvider.notifier).load();

        expect(container.read(bookmarkProvider).length, 1);
        expect(container.read(bookmarkProvider).first.id, '5');
      },
    );
  });
}
