import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keek_news/app.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/pages/bookmarks_view.dart';
import 'package:keek_news/pages/home_view.dart';
import 'package:keek_news/pages/settings_view.dart';
import 'package:keek_news/provider/shared_preferences_provider.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/image_cache_service.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/theme/shad_theme.dart';
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:keek_news/use_case/update_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/merged_feed_helper.dart';
import '../helpers/package_info_helper.dart';
import '../helpers/path_provider_helper.dart';

class MockUpdateRepository extends Mock implements UpdateRepo {}

class MockApkInstallRepository extends Mock implements ApkInstallRepo {}

class FakeImageCacheService extends Mock implements ImageCacheService {}

class FakeBookmarkRepository extends Mock implements BookmarkRepo {}

void main() {
  late MockUpdateRepository mockUpdateRepo;
  late MockApkInstallRepository mockApkRepo;
  late FakeImageCacheService fakeCacheService;
  late FakeBookmarkRepository fakeBookmarkRepo;
  late MockMergedFeedUseCase mockMergedUseCase;
  late SharedPreferences prefs;

  setUpAll(() async {
    await setupPackageInfoMock();
    setupPathProviderMock();
    registerMergedFeedFallbacks();
    registerFallbackValue(CommunityId.humoruniv);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockUpdateRepo = MockUpdateRepository();
    mockApkRepo = MockApkInstallRepository();
    fakeCacheService = FakeImageCacheService();
    fakeBookmarkRepo = FakeBookmarkRepository();
    mockMergedUseCase = MockMergedFeedUseCase();
    setupMergedFeedMocks(mockMergedUseCase);
    when(() => fakeCacheService.getSizeBytes()).thenAnswer((_) async => 0);
    when(() => fakeBookmarkRepo.getAll()).thenAnswer((_) async => const []);
    when(
      () => mockMergedUseCase.getEnabledCommunities(),
    ).thenAnswer((_) => CommunityId.values.toSet());
    when(
      () => mockMergedUseCase.canDisableCommunity(any()),
    ).thenAnswer((_) => true);
    await di.configureDependencies();
    if (di.sl.isRegistered<UpdateRepo>()) {
      di.sl.unregister<UpdateRepo>();
    }
    if (di.sl.isRegistered<UpdateUseCase>()) {
      di.sl.unregister<UpdateUseCase>();
    }
    if (di.sl.isRegistered<ApkInstallRepo>()) {
      di.sl.unregister<ApkInstallRepo>();
    }
    if (di.sl.isRegistered<ImageCacheService>()) {
      di.sl.unregister<ImageCacheService>();
    }
    if (di.sl.isRegistered<BookmarkRepo>()) {
      di.sl.unregister<BookmarkRepo>();
    }
    if (di.sl.isRegistered<FeedUseCase>()) {
      di.sl.unregister<FeedUseCase>();
    }
    di.sl.registerLazySingleton<UpdateRepo>(() => mockUpdateRepo);
    di.sl.registerLazySingleton(
      () => UpdateUseCase(
        updateRepo: mockUpdateRepo,
        apkRepo: mockApkRepo,
        currentVersion: '1.0.0',
      ),
    );
    di.sl.registerLazySingleton<ApkInstallRepo>(() => mockApkRepo);
    di.sl.registerLazySingleton<ImageCacheService>(() => fakeCacheService);
    di.sl.registerLazySingleton<BookmarkRepo>(() => fakeBookmarkRepo);
    di.sl.registerLazySingleton<FeedUseCase>(() => mockMergedUseCase);
  });

  tearDown(di.sl.reset);

  List<Override> testOverrides() => [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];

  group('appRouter', () {
    testWidgets('route / should render HomeView', (tester) async {
      when(() => mockUpdateRepo.getLatestRelease()).thenAnswer(
        (_) async =>
            const AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(),
          child: ShadApp.router(
            themeMode: ThemeMode.dark,
            darkTheme: AppShadTheme.dark(),
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeView), findsOneWidget);
    });

    testWidgets('route /settings should render SettingsView', (tester) async {
      when(() => mockUpdateRepo.getLatestRelease()).thenAnswer(
        (_) async =>
            const AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
      );

      final settingsRouter = GoRouter(
        initialLocation: '/settings',
        routes: appRouter.configuration.routes,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(),
          child: ShadApp.router(
            themeMode: ThemeMode.dark,
            darkTheme: AppShadTheme.dark(),
            routerConfig: settingsRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsView), findsOneWidget);
    });

    testWidgets('route /bookmarks should render BookmarksView', (tester) async {
      when(() => mockUpdateRepo.getLatestRelease()).thenAnswer(
        (_) async =>
            const AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
      );

      final bookmarksRouter = GoRouter(
        initialLocation: '/bookmarks',
        routes: appRouter.configuration.routes,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(),
          child: ShadApp.router(
            themeMode: ThemeMode.dark,
            darkTheme: AppShadTheme.dark(),
            routerConfig: bookmarksRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BookmarksView), findsOneWidget);
    });
  });
}
