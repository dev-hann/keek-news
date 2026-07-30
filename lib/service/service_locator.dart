import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/repository/apk_install/apk_install_impl.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/repository/bookmark/bookmark_impl.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_impl.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/repository/update/update_impl.dart';
import 'package:keek_news/service/apk_download_data_source.dart';
import 'package:keek_news/service/apk_download_data_source_impl.dart';
import 'package:keek_news/service/apk_installer_service.dart';
import 'package:keek_news/service/apk_installer_service_impl.dart';
import 'package:keek_news/service/bookmark_local_data_source.dart';
import 'package:keek_news/service/community_adapter.dart';
import 'package:keek_news/service/dogdrip_adapter_impl.dart';
import 'package:keek_news/service/github_remote_ds.dart';
import 'package:keek_news/service/github_remote_ds_impl.dart';
import 'package:keek_news/service/html_client_impl.dart';
import 'package:keek_news/service/humoruniv_adapter_impl.dart';
import 'package:keek_news/service/humoruniv_remote_ds.dart';
import 'package:keek_news/service/humoruniv_remote_ds_impl.dart';
import 'package:keek_news/service/image_cache_service.dart';
import 'package:keek_news/service/image_cache_service_impl.dart';
import 'package:keek_news/service/ppomppu_adapter_impl.dart';
import 'package:keek_news/service/todayhumor_adapter_impl.dart';
import 'package:keek_news/use_case/add_bookmark_use_case.dart';
import 'package:keek_news/use_case/check_for_update_use_case.dart';
import 'package:keek_news/use_case/get_bookmarks_use_case.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';
import 'package:keek_news/use_case/is_bookmarked_use_case.dart';
import 'package:keek_news/use_case/remove_bookmark_use_case.dart';
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

  sl.registerLazySingleton<MergedFeedRepo>(
    () => MergedFeedImpl(
      adapters: {
        CommunityId.humoruniv: sl<CommunityAdapter>(),
        CommunityId.todayhumor: sl<TodayhumorAdapterImpl>(),
        CommunityId.ppomppu: sl<PpomppuAdapterImpl>(),
        CommunityId.dogdrip: sl<DogdripAdapterImpl>(),
      },
    ),
  );

  sl.registerLazySingleton(
    () => GetMergedFeedUseCase(repository: sl<MergedFeedRepo>()),
  );

  sl.registerLazySingleton<GitHubRemoteDs>(GitHubRemoteDsImpl.new);

  sl.registerLazySingleton<UpdateRepo>(
    () => UpdateImpl(remoteDs: sl<GitHubRemoteDs>()),
  );

  final packageInfo = await PackageInfo.fromPlatform();
  sl.registerLazySingleton(
    () => CheckForUpdateUseCase(
      repository: sl<UpdateRepo>(),
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
  sl.registerLazySingleton<ApkInstallRepo>(
    () => ApkInstallImpl(
      downloadDataSource: sl<ApkDownloadDataSource>(),
      installerService: sl<ApkInstallerService>(),
    ),
  );

  sl.registerLazySingleton<BookmarkLocalDataSource>(
    () => BookmarkLocalDataSourceImpl(sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<BookmarkRepo>(
    () => BookmarkImpl(sl<BookmarkLocalDataSource>()),
  );

  sl.registerLazySingleton(
    () => GetBookmarksUseCase(repository: sl<BookmarkRepo>()),
  );
  sl.registerLazySingleton(
    () => IsBookmarkedUseCase(repository: sl<BookmarkRepo>()),
  );
  sl.registerLazySingleton(
    () => AddBookmarkUseCase(repository: sl<BookmarkRepo>()),
  );
  sl.registerLazySingleton(
    () => RemoveBookmarkUseCase(repository: sl<BookmarkRepo>()),
  );
}
