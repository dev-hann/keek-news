import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_impl.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/repository/update/update_impl.dart';
import 'package:keek_news/service/community_adapter.dart';
import 'package:keek_news/service/github_remote_ds.dart';
import 'package:keek_news/service/html_client_impl.dart';
import 'package:keek_news/service/humoruniv_adapter_impl.dart';
import 'package:keek_news/service/humoruniv_remote_ds.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/check_for_update_use_case.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/package_info_helper.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await setupPackageInfoMock();
  });

  tearDown(di.sl.reset);

  group('configureDependencies', () {
    test('should register HtmlClientImpl', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<HtmlClientImpl>(), isTrue);
    });

    test('should register HumorunivRemoteDs', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<HumorunivRemoteDs>(), isTrue);
    });

    test('should register CommunityAdapter', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<CommunityAdapter>(), isTrue);
    });

    test('CommunityAdapter should be HumorunivAdapterImpl', () async {
      await di.configureDependencies();
      expect(di.sl<CommunityAdapter>(), isA<HumorunivAdapterImpl>());
    });

    test('should register MergedFeedRepo', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<MergedFeedRepo>(), isTrue);
    });

    test('MergedFeedRepo should be MergedFeedImpl', () async {
      await di.configureDependencies();
      expect(di.sl<MergedFeedRepo>(), isA<MergedFeedImpl>());
    });

    test('should register GetMergedFeedUseCase use case', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<GetMergedFeedUseCase>(), isTrue);
    });

    test('should resolve all dependencies without throwing', () async {
      await di.configureDependencies();
      expect(() => di.sl<HtmlClientImpl>(), returnsNormally);
      expect(() => di.sl<HumorunivRemoteDs>(), returnsNormally);
      expect(() => di.sl<CommunityAdapter>(), returnsNormally);
      expect(() => di.sl<MergedFeedRepo>(), returnsNormally);
      expect(() => di.sl<GetMergedFeedUseCase>(), returnsNormally);
      expect(() => di.sl<GitHubRemoteDs>(), returnsNormally);
      expect(() => di.sl<UpdateRepo>(), returnsNormally);
      expect(() => di.sl<CheckForUpdateUseCase>(), returnsNormally);
    });

    test('UpdateRepo should be UpdateImpl', () async {
      await di.configureDependencies();
      expect(di.sl<UpdateRepo>(), isA<UpdateImpl>());
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
