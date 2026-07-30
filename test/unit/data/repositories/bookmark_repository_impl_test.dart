import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/datasources/bookmark_local_data_source.dart';
import 'package:happy_news/data/models/bookmark_dto.dart';
import 'package:happy_news/data/repositories/bookmark_repository_impl.dart';
import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:mocktail/mocktail.dart';

class MockBookmarkLocalDataSource extends Mock
    implements BookmarkLocalDataSource {}

void main() {
  late MockBookmarkLocalDataSource ds;
  late BookmarkRepositoryImpl repo;

  Bookmark bookmark({
    CommunityId community = CommunityId.humoruniv,
    String id = '1',
    String title = 't',
    String url = 'u',
  }) {
    return Bookmark(
      community: community,
      id: id,
      title: title,
      url: url,
      savedAt: DateTime.fromMillisecondsSinceEpoch(1722324000000),
    );
  }

  setUp(() {
    ds = MockBookmarkLocalDataSource();
    repo = BookmarkRepositoryImpl(ds);
    registerFallbackValue(
      BookmarkDto(
        community: CommunityId.humoruniv,
        id: 'fallback',
        title: '',
        url: '',
        savedAtMillis: 0,
      ),
    );
  });

  group('BookmarkRepositoryImpl getAll', () {
    test('should return entities mapped from datasource DTOs', () async {
      when(() => ds.getAll()).thenAnswer(
        (_) async => [
          BookmarkDto(
            community: CommunityId.humoruniv,
            id: '1',
            title: 'first',
            url: 'u1',
            savedAtMillis: 1000,
          ),
          BookmarkDto(
            community: CommunityId.dogdrip,
            id: '2',
            title: 'second',
            url: 'u2',
            savedAtMillis: 2000,
          ),
        ],
      );

      final result = await repo.getAll();

      expect(result.length, 2);
      expect(result[0].id, '1');
      expect(result[0].title, 'first');
      expect(result[0].community, CommunityId.humoruniv);
      expect(result[1].id, '2');
      expect(result[1].community, CommunityId.dogdrip);
    });

    test('should return empty list when datasource empty', () async {
      when(() => ds.getAll()).thenAnswer((_) async => const []);

      final result = await repo.getAll();

      expect(result, isEmpty);
    });
  });

  group('BookmarkRepositoryImpl isBookmarked', () {
    test('should return true when datasource reports key exists', () async {
      when(() => ds.exists('humoruniv:1')).thenAnswer((_) async => true);

      final result = await repo.isBookmarked(CommunityId.humoruniv, '1');

      expect(result, isTrue);
    });

    test('should return false when datasource reports key absent', () async {
      when(() => ds.exists('humoruniv:99')).thenAnswer((_) async => false);

      final result = await repo.isBookmarked(CommunityId.humoruniv, '99');

      expect(result, isFalse);
    });

    test('should build composite key from community and id', () async {
      when(() => ds.exists('dogdrip:42')).thenAnswer((_) async => true);

      await repo.isBookmarked(CommunityId.dogdrip, '42');

      verify(() => ds.exists('dogdrip:42')).called(1);
    });
  });

  group('BookmarkRepositoryImpl add', () {
    test('should convert entity to DTO and call datasource.upsert', () async {
      final b = bookmark(id: '1', title: '제목');
      when(() => ds.upsert(any())).thenAnswer((_) async {});

      await repo.add(b);

      final captured =
          verify(() => ds.upsert(captureAny())).captured.single as BookmarkDto;
      expect(captured.id, '1');
      expect(captured.title, '제목');
      expect(captured.savedAtMillis, 1722324000000);
    });
  });

  group('BookmarkRepositoryImpl remove', () {
    test('should call datasource.remove with composite key', () async {
      when(() => ds.remove('humoruniv:7')).thenAnswer((_) async {});

      await repo.remove(CommunityId.humoruniv, '7');

      verify(() => ds.remove('humoruniv:7')).called(1);
    });
  });
}
