import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/apk_install/apk_install_impl.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/repository/bookmark/bookmark_impl.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/repository/cache/image_cache_impl.dart';
import 'package:keek_news/repository/cache/image_cache_repo.dart';
import 'package:keek_news/repository/community/community_repo.dart';
import 'package:keek_news/repository/community/dogdrip/dogdrip_impl.dart';
import 'package:keek_news/repository/community/humoruniv/humoruniv_impl.dart';
import 'package:keek_news/repository/community/ppomppu/ppomppu_impl.dart';
import 'package:keek_news/repository/community/todayhumor/todayhumor_impl.dart';
import 'package:keek_news/repository/update/update_impl.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/apk_download_service.dart';
import 'package:keek_news/service/apk_installer_service.dart';
import 'package:keek_news/service/bookmark_local_service.dart';
import 'package:keek_news/service/default_image_cache_service.dart';
import 'package:keek_news/service/dio_apk_download_service.dart';
import 'package:keek_news/service/dio_github_remote_service.dart';
import 'package:keek_news/service/dio_html_service.dart';
import 'package:keek_news/service/github_remote_service.dart';
import 'package:keek_news/service/image_cache_service.dart';
import 'package:keek_news/service/method_channel_apk_installer_service.dart';
import 'package:keek_news/service/prefs_bookmark_local_service.dart';
import 'package:keek_news/use_case/bookmark_use_case.dart';
import 'package:keek_news/use_case/cache_use_case.dart';
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:keek_news/use_case/update_use_case.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mobileUA =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/138.0.0.0 Mobile Safari/537.36';

const _desktopUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36';

const _browserHeaders = <String, String>{
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,'
      'image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
  'Sec-Fetch-Dest': 'document',
  'Sec-Fetch-Mode': 'navigate',
  'Sec-Fetch-Site': 'same-origin',
  'Sec-Fetch-User': '?1',
  'Upgrade-Insecure-Requests': '1',
};

Dio _dio({
  required String baseUrl,
  String ua = _mobileUA,
  Map<String, String> extraHeaders = const {},
}) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    headers: {'User-Agent': ua, ...extraHeaders},
    responseType: ResponseType.bytes,
  ),
);

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  final humorunivHtml = DioHtmlService(
    dio: _dio(
      baseUrl: 'https://m.humoruniv.com',
      extraHeaders: {
        ..._browserHeaders,
        'Referer': 'https://m.humoruniv.com/board/pds/',
      },
    ),
    encoding: 'euc-kr',
  );
  final todayhumorHtml = DioHtmlService(
    dio: _dio(
      baseUrl: 'https://www.todayhumor.co.kr',
      ua: _desktopUA,
      extraHeaders: {
        ..._browserHeaders,
        'Referer': 'https://www.todayhumor.co.kr/board/humorbest.php',
      },
    ),
    encoding: 'utf-8',
  );
  final ppomppuHtml = DioHtmlService(
    dio: _dio(
      baseUrl: 'https://www.ppomppu.co.kr',
      ua: _desktopUA,
      extraHeaders: {
        ..._browserHeaders,
        'Referer': 'https://www.ppomppu.co.kr/zboard/zboard.php?id=humor',
      },
    ),
    encoding: 'euc-kr',
  );
  final dogdripHtml = DioHtmlService(
    dio: _dio(
      baseUrl: 'https://www.dogdrip.net',
      ua: _desktopUA,
      extraHeaders: {
        ..._browserHeaders,
        'Referer': 'https://www.dogdrip.net/index.php?mid=dogdrip',
      },
    ),
    encoding: 'utf-8',
  );

  final repos = <CommunityId, CommunityRepo>{
    CommunityId.humoruniv: HumorunivImpl(htmlClient: humorunivHtml),
    CommunityId.todayhumor: TodayhumorImpl(htmlClient: todayhumorHtml),
    CommunityId.ppomppu: PpomppuImpl(htmlClient: ppomppuHtml),
    CommunityId.dogdrip: DogdripImpl(htmlClient: dogdripHtml),
  };

  sl.registerLazySingleton<Map<CommunityId, CommunityRepo>>(() => repos);

  sl.registerLazySingleton(
    () => FeedUseCase(repos: sl<Map<CommunityId, CommunityRepo>>()),
  );

  sl.registerLazySingleton<GitHubRemoteService>(DioGitHubRemoteService.new);

  sl.registerLazySingleton<UpdateRepo>(
    () => UpdateImpl(remoteDs: sl<GitHubRemoteService>()),
  );

  final packageInfo = await PackageInfo.fromPlatform();

  sl.registerLazySingleton<ApkDownloadService>(
    () => DioApkDownloadService(
      dio: Dio(),
      resolveSavePath: () async {
        final dir = await getExternalStorageDirectory();
        return '${dir?.path ?? ''}/updates/app-update.apk';
      },
    ),
  );
  sl.registerLazySingleton<ApkInstallerService>(
    MethodChannelApkInstallerService.new,
  );
  sl.registerLazySingleton<ImageCacheService>(
    () => const DefaultImageCacheService(),
  );
  sl.registerLazySingleton<ImageCacheRepo>(
    () => ImageCacheImpl(sl<ImageCacheService>()),
  );
  sl.registerLazySingleton<ApkInstallRepo>(
    () => ApkInstallImpl(
      downloadDataSource: sl<ApkDownloadService>(),
      installerService: sl<ApkInstallerService>(),
    ),
  );
  sl.registerLazySingleton(
    () => UpdateUseCase(
      updateRepo: sl<UpdateRepo>(),
      apkRepo: sl<ApkInstallRepo>(),
      currentVersion: packageInfo.version,
    ),
  );

  sl.registerLazySingleton<BookmarkLocalService>(
    () => PrefsBookmarkLocalService(sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<BookmarkRepo>(
    () => BookmarkImpl(sl<BookmarkLocalService>()),
  );

  sl.registerLazySingleton<BookmarkUseCase>(
    () => BookmarkUseCase(sl<BookmarkRepo>()),
  );
  sl.registerLazySingleton<CacheUseCase>(
    () => CacheUseCase(sl<ImageCacheRepo>()),
  );
}
