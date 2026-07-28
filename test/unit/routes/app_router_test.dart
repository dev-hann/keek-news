import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:humoruniv/data/datasources/image_cache_service.dart';
import 'package:humoruniv/di/injection.dart' as di;
import 'package:humoruniv/domain/entities/app_release.dart';
import 'package:humoruniv/domain/repositories/apk_install_repository.dart';
import 'package:humoruniv/domain/repositories/merged_feed_repository.dart';
import 'package:humoruniv/domain/repositories/update_repository.dart';
import 'package:humoruniv/domain/usecases/check_for_update.dart';
import 'package:humoruniv/domain/usecases/get_merged_feed.dart';
import 'package:humoruniv/presentation/providers/shared_preferences_provider.dart';
import 'package:humoruniv/presentation/screens/home_screen.dart';
import 'package:humoruniv/presentation/screens/settings_screen.dart';
import 'package:humoruniv/routes/app_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/merged_feed_helper.dart';
import '../../helpers/package_info_helper.dart';

class MockUpdateRepository extends Mock implements UpdateRepository {}

class MockApkInstallRepository extends Mock implements ApkInstallRepository {}

class FakeImageCacheService extends Mock implements ImageCacheService {}

void main() {
  late MockUpdateRepository mockUpdateRepo;
  late MockApkInstallRepository mockApkRepo;
  late FakeImageCacheService fakeCacheService;
  late MockMergedFeedRepository mockMergedRepo;
  late SharedPreferences prefs;

  setUpAll(() async {
    await setupPackageInfoMock();
    registerMergedFeedFallbacks();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockUpdateRepo = MockUpdateRepository();
    mockApkRepo = MockApkInstallRepository();
    fakeCacheService = FakeImageCacheService();
    mockMergedRepo = MockMergedFeedRepository();
    setupMergedFeedMocks(mockMergedRepo);
    when(() => fakeCacheService.getSizeBytes()).thenAnswer((_) async => 0);
    await di.configureDependencies();
    if (di.sl.isRegistered<UpdateRepository>()) {
      di.sl.unregister<UpdateRepository>();
    }
    if (di.sl.isRegistered<CheckForUpdate>()) {
      di.sl.unregister<CheckForUpdate>();
    }
    if (di.sl.isRegistered<ApkInstallRepository>()) {
      di.sl.unregister<ApkInstallRepository>();
    }
    if (di.sl.isRegistered<ImageCacheService>()) {
      di.sl.unregister<ImageCacheService>();
    }
    if (di.sl.isRegistered<MergedFeedRepository>()) {
      di.sl.unregister<MergedFeedRepository>();
    }
    if (di.sl.isRegistered<GetMergedFeed>()) {
      di.sl.unregister<GetMergedFeed>();
    }
    di.sl.registerLazySingleton<UpdateRepository>(() => mockUpdateRepo);
    di.sl.registerLazySingleton(
      () => CheckForUpdate(repository: mockUpdateRepo, currentVersion: '1.0.0'),
    );
    di.sl.registerLazySingleton<ApkInstallRepository>(() => mockApkRepo);
    di.sl.registerLazySingleton<ImageCacheService>(() => fakeCacheService);
    di.sl.registerLazySingleton<MergedFeedRepository>(() => mockMergedRepo);
    di.sl.registerLazySingleton(
      () => GetMergedFeed(repository: mockMergedRepo),
    );
  });

  tearDown(di.sl.reset);

  List<Override> testOverrides() => [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];

  group('appRouter', () {
    testWidgets('route / should render HomeScreen', (tester) async {
      when(() => mockUpdateRepo.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(),
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('route /settings should render SettingsScreen', (tester) async {
      when(() => mockUpdateRepo.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      final settingsRouter = GoRouter(
        initialLocation: '/settings',
        routes: appRouter.configuration.routes,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(),
          child: MaterialApp.router(routerConfig: settingsRouter),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
