import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/domain/entities/community.dart';

void main() {
  group('Community', () {
    test('should expose 4 communities in the const list', () {
      expect(communities, hasLength(4));
      final ids = communities.map((c) => c.id).toSet();
      expect(ids, containsAll(CommunityId.values));
    });

    test('should have non-empty shortName and displayName for each', () {
      for (final c in communities) {
        expect(c.shortName, isNotEmpty);
        expect(c.displayName, isNotEmpty);
      }
    });

    test('should support equality by id', () {
      const a = Community(
        id: CommunityId.humoruniv,
        shortName: 'A',
        displayName: 'A',
        brandColorArgb: 0,
        iconAsset: 'a',
      );
      const b = Community(
        id: CommunityId.humoruniv,
        shortName: 'B',
        displayName: 'B',
        brandColorArgb: 1,
        iconAsset: 'b',
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
      );
      const b = Community(
        id: CommunityId.todayhumor,
        shortName: 'A',
        displayName: 'A',
        brandColorArgb: 0,
        iconAsset: 'a',
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
