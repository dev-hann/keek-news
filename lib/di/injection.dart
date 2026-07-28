import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:humoruniv/core/network/html_client_impl.dart';
import 'package:humoruniv/data/datasources/apk_download_data_source.dart';
import 'package:humoruniv/data/datasources/apk_download_data_source_impl.dart';
import 'package:humoruniv/data/datasources/apk_installer_service.dart';
import 'package:humoruniv/data/datasources/apk_installer_service_impl.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/github_remote_ds.dart';
import 'package:humoruniv/data/datasources/github_remote_ds_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds_impl.dart';
import 'package:humoruniv/data/datasources/todayhumor_adapter_impl.dart';
import 'package:humoruniv/data/datasources/image_cache_service.dart';
import 'package:humoruniv/data/datasources/image_cache_service_impl.dart';
import 'package:humoruniv/data/repositories/apk_install_repository_impl.dart';
import 'package:humoruniv/data/repositories/merged_feed_repository_impl.dart';
import 'package:humoruniv/data/repositories/post_repository_impl.dart';
import 'package:humoruniv/data/repositories/update_repository_impl.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/repositories/apk_install_repository.dart';
import 'package:humoruniv/domain/repositories/merged_feed_repository.dart';
import 'package:humoruniv/domain/repositories/post_repository.dart';
import 'package:humoruniv/domain/repositories/update_repository.dart';
import 'package:humoruniv/domain/usecases/check_for_update.dart';
import 'package:humoruniv/domain/usecases/get_best_posts.dart';
import 'package:humoruniv/domain/usecases/get_board_posts.dart';
import 'package:humoruniv/domain/usecases/get_merged_feed.dart';
import 'package:humoruniv/domain/usecases/get_post_detail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl.registerLazySingleton<HtmlClientImpl>(HtmlClientImpl.new);

  sl.registerLazySingleton<HumorunivRemoteDs>(
    () => HumorunivRemoteDsImpl(htmlClient: sl<HtmlClientImpl>()),
  );

  sl.registerLazySingleton<CommunityAdapter>(
    () => HumorunivAdapterImpl(remoteDs: sl<HumorunivRemoteDs>()),
  );

  sl.registerLazySingleton<HtmlClientImpl>(
    () => HtmlClientImpl(
      baseUrl: 'https://www.todayhumor.co.kr',
      encoding: 'utf-8',
    ),
    instanceName: 'todayhumorHtmlClient',
  );

  sl.registerLazySingleton<TodayhumorAdapterImpl>(
    () => TodayhumorAdapterImpl(
      htmlClient: sl<HtmlClientImpl>(instanceName: 'todayhumorHtmlClient'),
    ),
  );

  sl.registerLazySingleton<MergedFeedRepository>(
    () => MergedFeedRepositoryImpl(
      adapters: {
        CommunityId.humoruniv: sl<CommunityAdapter>(),
        CommunityId.todayhumor: sl<TodayhumorAdapterImpl>(),
      },
    ),
  );

  sl.registerLazySingleton(
    () => GetMergedFeed(repository: sl<MergedFeedRepository>()),
  );

  sl.registerLazySingleton<PostRepository>(
    () => PostRepositoryImpl(remoteDs: sl<HumorunivRemoteDs>()),
  );

  sl.registerLazySingleton(
    () => GetBestPosts(repository: sl<PostRepository>()),
  );
  sl.registerLazySingleton(
    () => GetPostDetail(repository: sl<PostRepository>()),
  );
  sl.registerLazySingleton(
    () => GetBoardPosts(repository: sl<PostRepository>()),
  );

  sl.registerLazySingleton<GitHubRemoteDs>(GitHubRemoteDsImpl.new);

  sl.registerLazySingleton<UpdateRepository>(
    () => UpdateRepositoryImpl(remoteDs: sl<GitHubRemoteDs>()),
  );

  final packageInfo = await PackageInfo.fromPlatform();
  sl.registerLazySingleton(
    () => CheckForUpdate(
      repository: sl<UpdateRepository>(),
      currentVersion: packageInfo.version,
    ),
  );

  sl.registerLazySingleton<ApkDownloadDataSource>(
    () => ApkDownloadDataSourceImpl(
      dio: Dio(),
      resolveSavePath: () async {
        final dir = await getExternalStorageDirectory();
        return '${dir?.path ?? ''}/updates/app-update.apk';
      },
    ),
  );
  sl.registerLazySingleton<ApkInstallerService>(ApkInstallerServiceImpl.new);
  sl.registerLazySingleton<ImageCacheService>(
    () => const ImageCacheServiceImpl(),
  );
  sl.registerLazySingleton<ApkInstallRepository>(
    () => ApkInstallRepositoryImpl(
      downloadDataSource: sl<ApkDownloadDataSource>(),
      installerService: sl<ApkInstallerService>(),
    ),
  );
}
