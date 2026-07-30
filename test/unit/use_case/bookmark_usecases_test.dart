import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/use_case/add_bookmark_use_case.dart';
import 'package:keek_news/use_case/get_bookmarks_use_case.dart';
import 'package:keek_news/use_case/is_bookmarked_use_case.dart';
import 'package:keek_news/use_case/remove_bookmark_use_case.dart';
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

  group('GetBookmarksUseCase', () {
    test('should delegate to repository.getAll', () async {
      final bookmarks = [_bookmark(), _bookmark(id: '2')];
      when(() => repo.getAll()).thenAnswer((_) async => bookmarks);
      final useCase = GetBookmarksUseCase(repository: repo);

      final result = await useCase();

      expect(result, equals(bookmarks));
      verify(() => repo.getAll()).called(1);
    });

    test('should return empty list when repository has no bookmarks', () async {
      when(() => repo.getAll()).thenAnswer((_) async => const []);
      final useCase = GetBookmarksUseCase(repository: repo);

      final result = await useCase();

      expect(result, isEmpty);
    });
  });

  group('IsBookmarkedUseCase', () {
    test('should delegate to repository.isBookmarked', () async {
      when(
        () => repo.isBookmarked(CommunityId.humoruniv, '1'),
      ).thenAnswer((_) async => true);
      final useCase = IsBookmarkedUseCase(repository: repo);

      final result = await useCase(CommunityId.humoruniv, '1');

      expect(result, isTrue);
      verify(() => repo.isBookmarked(CommunityId.humoruniv, '1')).called(1);
    });

    test('should return false when not bookmarked', () async {
      when(
        () => repo.isBookmarked(CommunityId.dogdrip, '42'),
      ).thenAnswer((_) async => false);
      final useCase = IsBookmarkedUseCase(repository: repo);

      final result = await useCase(CommunityId.dogdrip, '42');

      expect(result, isFalse);
    });
  });

  group('AddBookmarkUseCase', () {
    test('should delegate to repository.add', () async {
      final bookmark = _bookmark(id: '7');
      when(() => repo.add(bookmark)).thenAnswer((_) async {});
      final useCase = AddBookmarkUseCase(repository: repo);

      await useCase(bookmark);

      verify(() => repo.add(bookmark)).called(1);
    });
  });

  group('RemoveBookmarkUseCase', () {
    test('should delegate to repository.remove', () async {
      when(
        () => repo.remove(CommunityId.humoruniv, '7'),
      ).thenAnswer((_) async {});
      final useCase = RemoveBookmarkUseCase(repository: repo);

      await useCase(CommunityId.humoruniv, '7');

      verify(() => repo.remove(CommunityId.humoruniv, '7')).called(1);
    });
  });
}
