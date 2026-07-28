import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/core/network/html_client_impl.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/github_remote_ds.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/repositories/post_repository_impl.dart';
import 'package:humoruniv/data/repositories/update_repository_impl.dart';
import 'package:humoruniv/di/injection.dart' as di;
import 'package:humoruniv/domain/repositories/post_repository.dart';
import 'package:humoruniv/domain/repositories/update_repository.dart';
import 'package:humoruniv/domain/usecases/check_for_update.dart';
import 'package:humoruniv/domain/usecases/get_best_posts.dart';
import 'package:humoruniv/domain/usecases/get_board_posts.dart';
import 'package:humoruniv/domain/usecases/get_post_detail.dart';

import '../../helpers/package_info_helper.dart';

void main() {
  setUpAll(() async {
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

    test('CommunityAdapter should resolve without throwing', () async {
      await di.configureDependencies();

      expect(() => di.sl<CommunityAdapter>(), returnsNormally);
    });

    test('CommunityAdapter should be HumorunivAdapterImpl', () async {
      await di.configureDependencies();

      final adapter = di.sl<CommunityAdapter>();
      expect(adapter, isA<HumorunivAdapterImpl>());
    });

    test('should register PostRepository', () async {
      await di.configureDependencies();

      expect(di.sl.isRegistered<PostRepository>(), isTrue);
    });

    test('should register GetBestPosts use case', () async {
      await di.configureDependencies();

      expect(di.sl.isRegistered<GetBestPosts>(), isTrue);
    });

    test('should register GetPostDetail use case', () async {
      await di.configureDependencies();

      expect(di.sl.isRegistered<GetPostDetail>(), isTrue);
    });

    test('should register GetBoardPosts use case', () async {
      await di.configureDependencies();

      expect(di.sl.isRegistered<GetBoardPosts>(), isTrue);
    });

    test('should resolve all dependencies without throwing', () async {
      await di.configureDependencies();

      expect(() => di.sl<HtmlClientImpl>(), returnsNormally);
      expect(() => di.sl<HumorunivRemoteDs>(), returnsNormally);
      expect(() => di.sl<PostRepository>(), returnsNormally);
      expect(() => di.sl<GetBestPosts>(), returnsNormally);
      expect(() => di.sl<GetPostDetail>(), returnsNormally);
      expect(() => di.sl<GetBoardPosts>(), returnsNormally);
      expect(() => di.sl<GitHubRemoteDs>(), returnsNormally);
      expect(() => di.sl<UpdateRepository>(), returnsNormally);
      expect(() => di.sl<CheckForUpdate>(), returnsNormally);
    });

    test('PostRepository should be PostRepositoryImpl', () async {
      await di.configureDependencies();

      final repo = di.sl<PostRepository>();
      expect(repo, isA<PostRepositoryImpl>());
    });

    test('UpdateRepository should be UpdateRepositoryImpl', () async {
      await di.configureDependencies();

      final repo = di.sl<UpdateRepository>();
      expect(repo, isA<UpdateRepositoryImpl>());
    });

    test('CheckForUpdate should read version from PackageInfo', () async {
      await di.configureDependencies();

      final useCase = di.sl<CheckForUpdate>();
      expect(useCase.currentVersion, isNotEmpty);
      expect(useCase.currentVersion, equals('1.1.0'));
    });
  });
}
