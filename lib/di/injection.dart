import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:happy_news/core/network/html_client_impl.dart';
import 'package:happy_news/data/datasources/apk_download_data_source.dart';
import 'package:happy_news/data/datasources/apk_download_data_source_impl.dart';
import 'package:happy_news/data/datasources/apk_installer_service.dart';
import 'package:happy_news/data/datasources/apk_installer_service_impl.dart';
import 'package:happy_news/data/datasources/bookmark_local_data_source.dart';
import 'package:happy_news/data/datasources/community_adapter.dart';
import 'package:happy_news/data/datasources/dogdrip_adapter_impl.dart';
import 'package:happy_news/data/datasources/github_remote_ds.dart';
import 'package:happy_news/data/datasources/github_remote_ds_impl.dart';
import 'package:happy_news/data/datasources/humoruniv_adapter_impl.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds_impl.dart';
import 'package:happy_news/data/datasources/image_cache_service.dart';
import 'package:happy_news/data/datasources/image_cache_service_impl.dart';
import 'package:happy_news/data/datasources/ppomppu_adapter_impl.dart';
import 'package:happy_news/data/datasources/todayhumor_adapter_impl.dart';
import 'package:happy_news/data/repositories/apk_install_repository_impl.dart';
import 'package:happy_news/data/repositories/bookmark_repository_impl.dart';
import 'package:happy_news/data/repositories/merged_feed_repository_impl.dart';
import 'package:happy_news/data/repositories/update_repository_impl.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/repositories/apk_install_repository.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';
import 'package:happy_news/domain/repositories/merged_feed_repository.dart';
import 'package:happy_news/domain/repositories/update_repository.dart';
import 'package:happy_news/domain/usecases/add_bookmark.dart';
import 'package:happy_news/domain/usecases/check_for_update.dart';
import 'package:happy_news/domain/usecases/get_bookmarks.dart';
import 'package:happy_news/domain/usecases/get_merged_feed.dart';
import 'package:happy_news/domain/usecases/is_bookmarked.dart';
import 'package:happy_news/domain/usecases/remove_bookmark.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

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
      desktop: true,
    ),
    instanceName: 'todayhumorHtmlClient',
  );

  sl.registerLazySingleton<TodayhumorAdapterImpl>(
    () => TodayhumorAdapterImpl(
      htmlClient: sl<HtmlClientImpl>(instanceName: 'todayhumorHtmlClient'),
    ),
  );

  sl.registerLazySingleton<HtmlClientImpl>(
    () => HtmlClientImpl(baseUrl: 'https://www.ppomppu.co.kr', desktop: true),
    instanceName: 'ppomppuHtmlClient',
  );

  sl.registerLazySingleton<PpomppuAdapterImpl>(
    () => PpomppuAdapterImpl(
      htmlClient: sl<HtmlClientImpl>(instanceName: 'ppomppuHtmlClient'),
    ),
  );

  sl.registerLazySingleton<HtmlClientImpl>(
    () => HtmlClientImpl(
      baseUrl: 'https://www.dogdrip.net',
      encoding: 'utf-8',
      desktop: true,
    ),
    instanceName: 'dogdripHtmlClient',
  );

  sl.registerLazySingleton<DogdripAdapterImpl>(
    () => DogdripAdapterImpl(
      htmlClient: sl<HtmlClientImpl>(instanceName: 'dogdripHtmlClient'),
    ),
  );

  sl.registerLazySingleton<MergedFeedRepository>(
    () => MergedFeedRepositoryImpl(
      adapters: {
        CommunityId.humoruniv: sl<CommunityAdapter>(),
        CommunityId.todayhumor: sl<TodayhumorAdapterImpl>(),
        CommunityId.ppomppu: sl<PpomppuAdapterImpl>(),
        CommunityId.dogdrip: sl<DogdripAdapterImpl>(),
      },
    ),
  );

  sl.registerLazySingleton(
    () => GetMergedFeed(repository: sl<MergedFeedRepository>()),
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

  sl.registerLazySingleton<BookmarkLocalDataSource>(
    () => BookmarkLocalDataSourceImpl(sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<BookmarkRepository>(
    () => BookmarkRepositoryImpl(sl<BookmarkLocalDataSource>()),
  );

  sl.registerLazySingleton(
    () => GetBookmarks(repository: sl<BookmarkRepository>()),
  );
  sl.registerLazySingleton(
    () => IsBookmarked(repository: sl<BookmarkRepository>()),
  );
  sl.registerLazySingleton(
    () => AddBookmark(repository: sl<BookmarkRepository>()),
  );
  sl.registerLazySingleton(
    () => RemoveBookmark(repository: sl<BookmarkRepository>()),
  );
}
