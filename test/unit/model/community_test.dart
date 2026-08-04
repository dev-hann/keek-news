import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';

void main() {
  group('Community', () {
    test('should expose 8 communities in the const list', () {
      expect(communities, hasLength(8));
      final ids = communities.map((c) => c.id).toSet();
      expect(ids, containsAll(CommunityId.values));
    });

    test(
      'visibleCommunities excludes hidden ids (fmkorea disabled, not removed)',
      () {
        expect(hiddenCommunityIds, contains(CommunityId.fmkorea));
        final visibleIds = visibleCommunities.map((c) => c.id).toSet();
        expect(visibleIds, isNot(contains(CommunityId.fmkorea)));
        // Every non-hidden community remains visible.
        for (final id in CommunityId.values) {
          if (hiddenCommunityIds.contains(id)) continue;
          expect(visibleIds, contains(id));
        }
      },
    );

    test('should have non-empty shortName and displayName for each', () {
      for (final c in communities) {
        expect(c.shortName, isNotEmpty);
        expect(c.displayName, isNotEmpty);
      }
    });

    test('should have a non-empty https baseUrl for each community', () {
      for (final c in communities) {
        expect(c.baseUrl, isNotEmpty);
        expect(c.baseUrl, startsWith('https://'));
      }
    });

    test('should map each CommunityId to the expected base URL', () {
      expect(
        Community.findById(CommunityId.humoruniv)!.baseUrl,
        'https://m.humoruniv.com',
      );
      expect(
        Community.findById(CommunityId.todayhumor)!.baseUrl,
        'https://www.todayhumor.co.kr',
      );
      expect(
        Community.findById(CommunityId.ppomppu)!.baseUrl,
        'https://www.ppomppu.co.kr',
      );
      expect(
        Community.findById(CommunityId.dogdrip)!.baseUrl,
        'https://www.dogdrip.net',
      );
    });

    test('should support equality by id', () {
      const a = Community(
        id: CommunityId.humoruniv,
        shortName: 'A',
        displayName: 'A',
        brandColorArgb: 0,
        iconAsset: 'a',
        baseUrl: 'https://example.com',
      );
      const b = Community(
        id: CommunityId.humoruniv,
        shortName: 'B',
        displayName: 'B',
        brandColorArgb: 1,
        iconAsset: 'b',
        baseUrl: 'https://other.com',
      );
      expect(a, equals(b));
    });

    test('should be different when ids differ', () {
      const a = Community(
        id: CommunityId.humoruniv,
        shortName: 'A',
        displayName: 'A',
        brandColorArgb: 0,
        iconAsset: 'a',
        baseUrl: 'https://example.com',
      );
      const b = Community(
        id: CommunityId.todayhumor,
        shortName: 'A',
        displayName: 'A',
        brandColorArgb: 0,
        iconAsset: 'a',
        baseUrl: 'https://example.com',
      );
      expect(a, isNot(equals(b)));
    });

    test('findById should return matching community', () {
      final found = Community.findById(CommunityId.dogdrip);
      expect(found, isNotNull);
      expect(found!.id, CommunityId.dogdrip);
    });
  });
}
