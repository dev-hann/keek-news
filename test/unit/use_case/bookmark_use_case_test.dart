import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/use_case/bookmark_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockBookmarkRepository extends Mock implements BookmarkRepo {}

Bookmark _bookmark({
  CommunityId community = CommunityId.humoruniv,
  String id = '1',
}) {
  return Bookmark(
    community: community,
    id: id,
    title: 't',
    url: 'u',
    savedAt: DateTime.fromMillisecondsSinceEpoch(1722324000000),
  );
}

void main() {
  late MockBookmarkRepository repo;

  setUp(() {
    repo = MockBookmarkRepository();
  });

  group('BookmarkUseCase', () {
    test('getAll delegates to repository.getAll', () async {
      final bookmarks = [_bookmark(), _bookmark(id: '2')];
      when(() => repo.getAll()).thenAnswer((_) async => bookmarks);
      final useCase = BookmarkUseCase(repo);

      final result = await useCase.getAll();

      expect(result, equals(bookmarks));
      verify(() => repo.getAll()).called(1);
    });

    test('isBookmarked delegates to repository.isBookmarked', () async {
      when(
        () => repo.isBookmarked(CommunityId.humoruniv, '1'),
      ).thenAnswer((_) async => true);
      final useCase = BookmarkUseCase(repo);

      final result = await useCase.isBookmarked(CommunityId.humoruniv, '1');

      expect(result, isTrue);
      verify(() => repo.isBookmarked(CommunityId.humoruniv, '1')).called(1);
    });

    test('add delegates to repository.add', () async {
      final bookmark = _bookmark(id: '7');
      when(() => repo.add(bookmark)).thenAnswer((_) async {});
      final useCase = BookmarkUseCase(repo);

      await useCase.add(bookmark);

      verify(() => repo.add(bookmark)).called(1);
    });

    test('remove delegates to repository.remove', () async {
      when(
        () => repo.remove(CommunityId.humoruniv, '7'),
      ).thenAnswer((_) async {});
      final useCase = BookmarkUseCase(repo);

      await useCase.remove(CommunityId.humoruniv, '7');

      verify(() => repo.remove(CommunityId.humoruniv, '7')).called(1);
    });
  });
}
