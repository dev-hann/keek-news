import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/feed/feed_impl.dart';
import 'package:keek_news/service/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

const _storageKey = 'enabled_communities';

void main() {
  late MockLocalStorageService storage;
  late FeedImpl repo;

  setUp(() {
    storage = MockLocalStorageService();
    repo = FeedImpl(storage);
  });

  group('FeedImpl getEnabledCommunities', () {
    test('returns all visible communities when storage is null', () {
      when(() => storage.getStringList(_storageKey)).thenReturn(null);

      final result = repo.getEnabledCommunities();

      expect(result, CommunityId.values.toSet().difference(hiddenCommunityIds));
    });

    test('returns all visible communities when storage is empty', () {
      when(() => storage.getStringList(_storageKey)).thenReturn(<String>[]);

      final result = repo.getEnabledCommunities();

      expect(result, CommunityId.values.toSet().difference(hiddenCommunityIds));
    });

    test('decodes stored names into CommunityId set', () {
      when(
        () => storage.getStringList(_storageKey),
      ).thenReturn(['dogdrip', 'ppomppu']);

      final result = repo.getEnabledCommunities();

      expect(result, {CommunityId.dogdrip, CommunityId.ppomppu});
    });

    test(
      'hidden communities are never returned even if persisted as enabled',
      () {
        // Regression: an older install may have toggled fmkorea on before it
        // was hidden. The persisted name must not resurrect it in the feed.
        when(
          () => storage.getStringList(_storageKey),
        ).thenReturn(['dogdrip', 'fmkorea']);

        final result = repo.getEnabledCommunities();

        expect(result, {CommunityId.dogdrip});
        expect(result, isNot(contains(CommunityId.fmkorea)));
      },
    );
  });

  group('FeedImpl canDisable', () {
    test('returns true when more than 1 community enabled', () {
      when(
        () => storage.getStringList(_storageKey),
      ).thenReturn(['dogdrip', 'ppomppu', 'humoruniv']);

      expect(repo.canDisable(CommunityId.dogdrip), isTrue);
    });

    test('returns false when only 1 community enabled', () {
      when(() => storage.getStringList(_storageKey)).thenReturn(['dogdrip']);

      expect(repo.canDisable(CommunityId.dogdrip), isFalse);
    });

    test('returns true for a disabled community even when only 1 is enabled '
        'regression: re-enabling locked out by old length>1 check', () {
      when(() => storage.getStringList(_storageKey)).thenReturn(['dogdrip']);

      expect(repo.canDisable(CommunityId.ppomppu), isTrue);
      expect(repo.canDisable(CommunityId.humoruniv), isTrue);
    });

    test('returns true for every disabled community when all-but-one off', () {
      when(() => storage.getStringList(_storageKey)).thenReturn(['dogdrip']);

      for (final id in CommunityId.values) {
        if (id == CommunityId.dogdrip) continue;
        expect(repo.canDisable(id), isTrue, reason: '$id should be toggleable');
      }
    });
  });

  group('FeedImpl toggleCommunity', () {
    test('removes community and persists when more than 1 enabled', () async {
      when(
        () => storage.getStringList(_storageKey),
      ).thenReturn(['dogdrip', 'ppomppu', 'humoruniv']);
      when(
        () => storage.setStringList(_storageKey, any()),
      ).thenAnswer((_) async {});

      repo.toggleCommunity(CommunityId.dogdrip);

      final captured =
          verify(
                () => storage.setStringList(_storageKey, captureAny()),
              ).captured.single
              as List<String>;
      expect(captured, isNot(contains('dogdrip')));
      expect(captured, containsAll(['ppomppu', 'humoruniv']));
      expect(captured.length, 2);
    });

    test('adds community back and persists when absent', () async {
      when(
        () => storage.getStringList(_storageKey),
      ).thenReturn(['ppomppu', 'humoruniv']);
      when(
        () => storage.setStringList(_storageKey, any()),
      ).thenAnswer((_) async {});

      repo.toggleCommunity(CommunityId.dogdrip);

      final captured =
          verify(
                () => storage.setStringList(_storageKey, captureAny()),
              ).captured.single
              as List<String>;
      expect(captured, contains('dogdrip'));
      expect(captured.length, 3);
    });

    test(
      'is a no-op when only 1 community enabled (min-1 guarantee)',
      () async {
        when(() => storage.getStringList(_storageKey)).thenReturn(['dogdrip']);
        when(
          () => storage.setStringList(_storageKey, any()),
        ).thenAnswer((_) async {});

        repo.toggleCommunity(CommunityId.dogdrip);

        verifyNever(() => storage.setStringList(_storageKey, any()));
      },
    );
  });

  group('FeedImpl round-trip', () {
    test('saved set reloads identically', () async {
      final initial = {CommunityId.dogdrip, CommunityId.ppomppu};
      List<String>? persisted;

      when(
        () => storage.getStringList(_storageKey),
      ).thenReturn(initial.map((e) => e.name).toList());
      when(() => storage.setStringList(_storageKey, any())).thenAnswer((
        inv,
      ) async {
        persisted = inv.positionalArguments[1] as List<String>;
      });

      repo.toggleCommunity(CommunityId.humoruniv);

      reset(storage);
      when(() => storage.getStringList(_storageKey)).thenReturn(persisted);

      final reloaded = repo.getEnabledCommunities();

      expect(reloaded, {
        CommunityId.dogdrip,
        CommunityId.ppomppu,
        CommunityId.humoruniv,
      });
    });
  });
}
