import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/community_repo.dart';
import 'package:keek_news/service/github_remote_service.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/bookmark_use_case.dart';
import 'package:keek_news/use_case/check_for_update_use_case.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';
import 'package:keek_news/use_case/get_post_detail_use_case.dart';
import 'package:keek_news/use_case/install_apk_use_case.dart';
import 'package:keek_news/use_case/manage_cache_use_case.dart';
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

    test('should register GetMergedFeedUseCase use case', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<GetMergedFeedUseCase>(), isTrue);
    });

    test('should register GetPostDetailUseCase use case', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<GetPostDetailUseCase>(), isTrue);
    });

    test('should resolve all dependencies without throwing', () async {
      await di.configureDependencies();
      expect(() => di.sl<Map<CommunityId, CommunityRepo>>(), returnsNormally);
      expect(() => di.sl<GetMergedFeedUseCase>(), returnsNormally);
      expect(() => di.sl<GetPostDetailUseCase>(), returnsNormally);
      expect(() => di.sl<GitHubRemoteService>(), returnsNormally);
      expect(() => di.sl<CheckForUpdateUseCase>(), returnsNormally);
      expect(() => di.sl<InstallApkUseCase>(), returnsNormally);
      expect(() => di.sl<BookmarkUseCase>(), returnsNormally);
      expect(() => di.sl<ManageCacheUseCase>(), returnsNormally);
    });

    test(
      'CheckForUpdateUseCase should read version from PackageInfo',
      () async {
        await di.configureDependencies();
        final useCase = di.sl<CheckForUpdateUseCase>();
        expect(useCase.currentVersion, isNotEmpty);
        expect(useCase.currentVersion, equals('1.1.0'));
      },
    );
  });
}
