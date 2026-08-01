import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/community/community_repo.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:keek_news/use_case/update_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/package_info_helper.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await setupPackageInfoMock();
  });

  tearDown(di.sl.reset);

  group('configureDependencies', () {
    test('should register CommunityRepo map with 4 communities', () async {
      await di.configureDependencies();
      final repos = di.sl<Map<CommunityId, CommunityRepo>>();
      expect(repos.length, 4);
      expect(repos.keys, contains(CommunityId.humoruniv));
      expect(repos.keys, contains(CommunityId.dogdrip));
    });

    test('should register FeedUseCase use case', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<FeedUseCase>(), isTrue);
    });

    test('should register FeedUseCase use case', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<FeedUseCase>(), isTrue);
    });

    test('should resolve all dependencies without throwing', () async {
      await di.configureDependencies();
      expect(di.sl<Map<CommunityId, CommunityRepo>>(), isNotNull);
      expect(di.sl<FeedUseCase>(), isNotNull);
      expect(di.sl<FeedUseCase>(), isNotNull);
      expect(di.sl<UpdateUseCase>(), isNotNull);
    });

    test('UpdateUseCase should read version from PackageInfo', () async {
      await di.configureDependencies();
      final useCase = di.sl<UpdateUseCase>();
      expect(useCase.currentVersion, isNotEmpty);
      expect(useCase.currentVersion, equals('1.1.0'));
    });
  });
}
