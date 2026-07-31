import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/pages/bookmarks_view.dart';
import 'package:keek_news/pages/settings_view.dart';
import 'package:keek_news/provider/shared_preferences_provider.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/image_cache_service.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/check_for_update_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockUpdateRepository extends Mock implements UpdateRepo {}

class MockApkInstallRepository extends Mock implements ApkInstallRepo {}

class FakeImageCacheService extends Mock implements ImageCacheService {}

class FakeBookmarkRepository extends Mock implements BookmarkRepo {}

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
  late FakeBookmarkRepository fakeBookmarkRepo;
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
    );
    fakeLauncher = FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeLauncher;
    mockRepository = MockUpdateRepository();
    mockApkRepo = MockApkInstallRepository();
    fakeCacheService = FakeImageCacheService();
    fakeBookmarkRepo = FakeBookmarkRepository();
    when(() => fakeBookmarkRepo.getAll()).thenAnswer((_) async => const []);
    registerFallbackValue(Uri.parse('https://example.com'));
    when(() => fakeCacheService.getSizeBytes()).thenAnswer((_) async => 4096);
    if (di.sl.isRegistered<UpdateRepo>()) {
      di.sl.unregister<UpdateRepo>();
    }
    if (di.sl.isRegistered<CheckForUpdateUseCase>()) {
      di.sl.unregister<CheckForUpdateUseCase>();
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
    di.sl.registerLazySingleton<UpdateRepo>(() => mockRepository);
    di.sl.registerLazySingleton(
      () => CheckForUpdateUseCase(
        repository: mockRepository,
        currentVersion: '1.0.0',
      ),
    );
    di.sl.registerLazySingleton<ApkInstallRepo>(() => mockApkRepo);
    di.sl.registerLazySingleton<ImageCacheService>(() => fakeCacheService);
    di.sl.registerLazySingleton<BookmarkRepo>(() => fakeBookmarkRepo);
  });

  tearDown(di.sl.reset);

  Widget buildApp() => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MaterialApp(home: SettingsView()),
  );

  group('SettingsView', () {
    testWidgets('should display all section titles', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());

      expect(find.text('저장함'), findsOneWidget);
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

      expect(find.textContaining('v1.5.0'), findsOneWidget);
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

    testWidgets('renders the bookmarks tile in the 저장함 group', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('저장한 게시물'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
    });

    testWidgets('navigates to BookmarksView when bookmark tile tapped', (
      tester,
    ) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('저장한 게시물'));
      await tester.pumpAndSettle();

      expect(find.byType(BookmarksView), findsOneWidget);
    });

    testWidgets('auto-checks for update on entry', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());
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

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('v1.2.0 사용 가능'), findsOneWidget);
      expect(find.text('업데이트'), findsOneWidget);
    });

    testWidgets('should show up to date state', (tester) async {
      when(() => mockRepository.getLatestRelease()).thenAnswer(
        (_) async => const Right(
          AppRelease(version: '1.0.0', htmlUrl: 'https://example.com'),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('최신 버전'), findsOneWidget);
    });

    testWidgets('should show error state with retry', (tester) async {
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) async => const Left(UpdateFailure('Network error')));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('확인 실패'), findsOneWidget);
      expect(find.text('다시'), findsOneWidget);
    });

    testWidgets('should show checking state', (tester) async {
      final completer = Completer<Either<Failure, AppRelease>>();
      when(
        () => mockRepository.getLatestRelease(),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildApp());
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
        when(() => mockRepository.getLatestRelease()).thenAnswer(
          (_) async => const Right(
            AppRelease(
              version: '1.2.0',
              htmlUrl: 'https://example.com/release',
            ),
          ),
        );
        fakeLauncher.canLaunchResult = false;

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('업데이트'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('업데이트'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('업데이트 페이지를 열 수 없습니다.'), findsOneWidget);
      },
    );
  });
}
