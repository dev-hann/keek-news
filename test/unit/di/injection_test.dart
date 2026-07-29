import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/network/html_client_impl.dart';
import 'package:happy_news/data/datasources/community_adapter.dart';
import 'package:happy_news/data/datasources/github_remote_ds.dart';
import 'package:happy_news/data/datasources/humoruniv_adapter_impl.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds.dart';
import 'package:happy_news/data/repositories/merged_feed_repository_impl.dart';
import 'package:happy_news/data/repositories/update_repository_impl.dart';
import 'package:happy_news/di/injection.dart' as di;
import 'package:happy_news/domain/repositories/merged_feed_repository.dart';
import 'package:happy_news/domain/repositories/update_repository.dart';
import 'package:happy_news/domain/usecases/check_for_update.dart';
import 'package:happy_news/domain/usecases/get_merged_feed.dart';
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

    test('should register MergedFeedRepository', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<MergedFeedRepository>(), isTrue);
    });

    test('MergedFeedRepository should be MergedFeedRepositoryImpl', () async {
      await di.configureDependencies();
      expect(di.sl<MergedFeedRepository>(), isA<MergedFeedRepositoryImpl>());
    });

    test('should register GetMergedFeed use case', () async {
      await di.configureDependencies();
      expect(di.sl.isRegistered<GetMergedFeed>(), isTrue);
    });

    test('should resolve all dependencies without throwing', () async {
      await di.configureDependencies();
      expect(() => di.sl<HtmlClientImpl>(), returnsNormally);
      expect(() => di.sl<HumorunivRemoteDs>(), returnsNormally);
      expect(() => di.sl<CommunityAdapter>(), returnsNormally);
      expect(() => di.sl<MergedFeedRepository>(), returnsNormally);
      expect(() => di.sl<GetMergedFeed>(), returnsNormally);
      expect(() => di.sl<GitHubRemoteDs>(), returnsNormally);
      expect(() => di.sl<UpdateRepository>(), returnsNormally);
      expect(() => di.sl<CheckForUpdate>(), returnsNormally);
    });

    test('UpdateRepository should be UpdateRepositoryImpl', () async {
      await di.configureDependencies();
      expect(di.sl<UpdateRepository>(), isA<UpdateRepositoryImpl>());
    });

    test('CheckForUpdate should read version from PackageInfo', () async {
      await di.configureDependencies();
      final useCase = di.sl<CheckForUpdate>();
      expect(useCase.currentVersion, isNotEmpty);
      expect(useCase.currentVersion, equals('1.1.0'));
    });
  });
}
