import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_impl.dart';
import 'package:keek_news/service/bookmark_local_service.dart';
import 'package:mocktail/mocktail.dart';

class MockBookmarkLocalService extends Mock implements BookmarkLocalService {}

void main() {
  late MockBookmarkLocalService ds;
  late BookmarkImpl repo;

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
    ds = MockBookmarkLocalService();
    repo = BookmarkImpl(ds);
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

  group('BookmarkImpl getAll', () {
    test('should delegate to datasource directly', () async {
      final b = bookmark(title: 'first');
      when(() => ds.getAll()).thenAnswer((_) async => [b]);

      final result = await repo.getAll();

      expect(result.length, 1);
      expect(result[0].title, 'first');
    });

    test('should return empty list when datasource empty', () async {
      when(() => ds.getAll()).thenAnswer((_) async => const []);

      final result = await repo.getAll();

      expect(result, isEmpty);
    });
  });

  group('BookmarkImpl isBookmarked', () {
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

  group('BookmarkImpl add', () {
    test('should forward entity directly to datasource.upsert', () async {
      final b = bookmark(title: '제목');
      when(() => ds.upsert(any())).thenAnswer((_) async {});

      await repo.add(b);

      final captured =
          verify(() => ds.upsert(captureAny())).captured.single as Bookmark;
      expect(captured.id, '1');
      expect(captured.title, '제목');
      expect(captured.savedAt.millisecondsSinceEpoch, 1722324000000);
    });
  });

  group('BookmarkImpl remove', () {
    test('should call datasource.remove with composite key', () async {
      when(() => ds.remove('humoruniv:7')).thenAnswer((_) async {});

      await repo.remove(CommunityId.humoruniv, '7');

      verify(() => ds.remove('humoruniv:7')).called(1);
    });
  });
}
