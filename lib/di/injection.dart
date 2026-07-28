import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:humoruniv/core/network/html_client_impl.dart';
import 'package:humoruniv/data/datasources/apk_download_data_source.dart';
import 'package:humoruniv/data/datasources/apk_download_data_source_impl.dart';
import 'package:humoruniv/data/datasources/apk_installer_service.dart';
import 'package:humoruniv/data/datasources/apk_installer_service_impl.dart';
import 'package:humoruniv/data/datasources/cloudflare_cookie_store.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/dogdrip_adapter_impl.dart';
import 'package:humoruniv/data/datasources/fmkorea_adapter_impl.dart';
import 'package:humoruniv/data/datasources/github_remote_ds.dart';
import 'package:humoruniv/data/datasources/github_remote_ds_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds_impl.dart';
import 'package:humoruniv/data/datasources/ppomppu_adapter_impl.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  final fmkoreaCookieStore = CloudflareCookieStore(prefs, 'fmkorea.com');
  sl.registerSingleton<CloudflareCookieStore>(
    fmkoreaCookieStore,
    instanceName: 'fmkoreaCookies',
  );

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
    () => HtmlClientImpl(
      baseUrl: 'https://www.ppomppu.co.kr',
      encoding: 'euc-kr',
      desktop: true,
    ),
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

  sl.registerLazySingleton<HtmlClientImpl>(
    () => HtmlClientImpl(
      baseUrl: 'https://www.fmkorea.com',
      encoding: 'utf-8',
      desktop: true,
      cookieProvider: () => sl<CloudflareCookieStore>(
        instanceName: 'fmkoreaCookies',
      ).getCookieHeader(),
    ),
    instanceName: 'fmkoreaHtmlClient',
  );

  sl.registerLazySingleton<FmkoreaAdapterImpl>(
    () => FmkoreaAdapterImpl(
      htmlClient: sl<HtmlClientImpl>(instanceName: 'fmkoreaHtmlClient'),
    ),
  );

  sl.registerLazySingleton<MergedFeedRepository>(
    () => MergedFeedRepositoryImpl(
      adapters: {
        CommunityId.humoruniv: sl<CommunityAdapter>(),
        CommunityId.todayhumor: sl<TodayhumorAdapterImpl>(),
        CommunityId.ppomppu: sl<PpomppuAdapterImpl>(),
        CommunityId.dogdrip: sl<DogdripAdapterImpl>(),
        CommunityId.fmkorea: sl<FmkoreaAdapterImpl>(),
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
