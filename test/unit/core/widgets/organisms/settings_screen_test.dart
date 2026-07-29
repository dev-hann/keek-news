import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/core/widgets/molecules/dark_mode_selector.dart';
import 'package:happy_news/data/datasources/image_cache_service.dart';
import 'package:happy_news/di/injection.dart' as di;
import 'package:happy_news/domain/entities/app_release.dart';
import 'package:happy_news/domain/repositories/apk_install_repository.dart';
import 'package:happy_news/domain/repositories/update_repository.dart';
import 'package:happy_news/domain/usecases/check_for_update.dart';
import 'package:happy_news/presentation/providers/shared_preferences_provider.dart';
import 'package:happy_news/presentation/providers/update_provider.dart';
import 'package:happy_news/presentation/screens/settings_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockUpdateRepository extends Mock implements UpdateRepository {}

class MockApkInstallRepository extends Mock implements ApkInstallRepository {}

class FakeImageCacheService extends Mock implements ImageCacheService {}

class FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  bool canLaunchResult = true;
  bool launchResult = true;

  @override
  Future<bool> canLaunch(String url) async => canLaunchResult;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async => launchResult;

  @override
  LinkDelegate? get linkDelegate => null;
}

void main() {
  late MockUpdateRepository mockRepository;
  late MockApkInstallRepository mockApkRepo;
  late FakeImageCacheService fakeCacheService;
  late SharedPreferences prefs;
  late FakeUrlLauncherPlatform fakeLauncher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    PackageInfo.setMockInitialValues(
      appName: '웃긴대학',
      packageName: 'com.example.humoruniv',
      version: '1.5.0',
      buildNumber: '7',
      buildSignature: '',
      installerStore: null,
    );
    fakeLauncher = FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeLauncher;
    mockRepository = MockUpdateRepository();
    mockApkRepo = MockApkInstallRepository();
    fakeCacheService = FakeImageCacheService();
    registerFallbackValue(Uri.parse('https://example.com'));
    when(() => fakeCacheService.getSizeBytes()).thenAnswer((_) async => 4096);
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
    di.sl.registerLazySingleton<UpdateRepository>(() => mockRepository);
    di.sl.registerLazySingleton(
      () => CheckForUpdate(repository: mockRepository, currentVersion: '1.0.0'),
    );
    di.sl.registerLazySingleton<ApkInstallRepository>(() => mockApkRepo);
    di.sl.registerLazySingleton<ImageCacheService>(() => fakeCacheService);
  });

  tearDown(di.sl.reset);

  Widget buildApp() => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MaterialApp(home: SettingsScreen()),
  );

  group('SettingsScreen', () {
    testWidgets('should display all section titles', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());

      expect(find.text('화면'), findsOneWidget);
      expect(find.text('미디어 & 데이터'), findsOneWidget);
      expect(find.text('정보'), findsOneWidget);
    });

    testWidgets('should display AppBar with 설정 title', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final title = (appBar.title! as Text).data;
      expect(title, '설정');
    });

    testWidgets('should display dark mode selector', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());

      expect(find.byType(DarkModeSelector), findsOneWidget);
    });

    testWidgets('should display version info', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());

      expect(find.text('버전'), findsOneWidget);
    });

    testWidgets('should show real app version after load, not stale fallback', (
      tester,
    ) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('v1.5.0'), findsOneWidget);
      expect(find.text('v1.1.0'), findsNothing);
    });

    testWidgets('renders the new About tiles (licenses, source)', (
      tester,
    ) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('오픈소스 라이선스'), findsOneWidget);
      expect(find.text('소스 코드'), findsOneWidget);
      expect(find.text('피드백'), findsNothing);
    });

    testWidgets('renders the image cache tile showing the cache size', (
      tester,
    ) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('이미지 캐시'), findsOneWidget);
      expect(find.textContaining('KB'), findsWidgets);
    });

    testWidgets('should display update banner in idle state', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());

      expect(find.text('업데이트 확인'), findsOneWidget);
    });

    testWidgets('should trigger checkForUpdate when check button tapped', (
      tester,
    ) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());

      await tester.tap(find.text('업데이트 확인'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.getLatestRelease()).called(greaterThan(0));
    });

    testWidgets('should show update available state', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(
            version: '1.2.0',
            htmlUrl: 'https://example.com',
            downloadUrl: 'https://example.com/app.apk',
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      container.read(updateProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      expect(find.text('v1.2.0 사용 가능'), findsOneWidget);
      expect(find.text('업데이트'), findsOneWidget);
    });

    testWidgets('should show up to date state', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      container.read(updateProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      expect(find.text('최신 버전입니다'), findsOneWidget);
    });

    testWidgets('should show error state with retry', (tester) async {
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => const Left(UpdateFailure('Network error')));

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      container.read(updateProvider.notifier).checkForUpdate();
      await tester.pumpAndSettle();

      expect(find.text('확인 실패'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('should show checking state', (tester) async {
      final completer = Completer<Either<Failure, AppRelease>>();
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) => completer.future);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      container.read(updateProvider.notifier).checkForUpdate();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets(
      'should show feedback when browser fallback URL cannot be opened',
      (tester) async {
        // Release WITHOUT an apk asset -> banner shows "브라우저에서 열기" which
        // falls back to url_launcher. If that launch fails, show a SnackBar.
        when(() => mockRepository.getLatestRelease()).thenAnswer(
          (_) async => const Right(
            AppRelease(
              version: '1.2.0',
              htmlUrl: 'https://example.com/release',
            ),
          ),
        );
        fakeLauncher.canLaunchResult = false;

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );

        container.read(updateProvider.notifier).checkForUpdate();
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('브라우저에서 열기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('브라우저에서 열기'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('업데이트 페이지를 열 수 없습니다.'), findsOneWidget);
      },
    );
  });
}
