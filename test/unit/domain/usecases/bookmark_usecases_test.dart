import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';
import 'package:happy_news/domain/usecases/add_bookmark.dart';
import 'package:happy_news/domain/usecases/get_bookmarks.dart';
import 'package:happy_news/domain/usecases/is_bookmarked.dart';
import 'package:happy_news/domain/usecases/remove_bookmark.dart';
import 'package:mocktail/mocktail.dart';

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

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

  group('GetBookmarks', () {
    test('should delegate to repository.getAll', () async {
      final bookmarks = [_bookmark(id: '1'), _bookmark(id: '2')];
      when(() => repo.getAll()).thenAnswer((_) async => bookmarks);
      final useCase = GetBookmarks(repository: repo);

      final result = await useCase();

      expect(result, equals(bookmarks));
      verify(() => repo.getAll()).called(1);
    });

    test('should return empty list when repository has no bookmarks', () async {
      when(() => repo.getAll()).thenAnswer((_) async => const []);
      final useCase = GetBookmarks(repository: repo);

      final result = await useCase();

      expect(result, isEmpty);
    });
  });

  group('IsBookmarked', () {
    test('should delegate to repository.isBookmarked', () async {
      when(
        () => repo.isBookmarked(CommunityId.humoruniv, '1'),
      ).thenAnswer((_) async => true);
      final useCase = IsBookmarked(repository: repo);

      final result = await useCase(CommunityId.humoruniv, '1');

      expect(result, isTrue);
      verify(() => repo.isBookmarked(CommunityId.humoruniv, '1')).called(1);
    });

    test('should return false when not bookmarked', () async {
      when(
        () => repo.isBookmarked(CommunityId.dogdrip, '42'),
      ).thenAnswer((_) async => false);
      final useCase = IsBookmarked(repository: repo);

      final result = await useCase(CommunityId.dogdrip, '42');

      expect(result, isFalse);
    });
  });

  group('AddBookmark', () {
    test('should delegate to repository.add', () async {
      final bookmark = _bookmark(id: '7');
      when(() => repo.add(bookmark)).thenAnswer((_) async {});
      final useCase = AddBookmark(repository: repo);

      await useCase(bookmark);

      verify(() => repo.add(bookmark)).called(1);
    });
  });

  group('RemoveBookmark', () {
    test('should delegate to repository.remove', () async {
      when(
        () => repo.remove(CommunityId.humoruniv, '7'),
      ).thenAnswer((_) async {});
      final useCase = RemoveBookmark(repository: repo);

      await useCase(CommunityId.humoruniv, '7');

      verify(() => repo.remove(CommunityId.humoruniv, '7')).called(1);
    });
  });
}
