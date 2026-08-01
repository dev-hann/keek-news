import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/app.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/pages/home_view.dart';
import 'package:keek_news/provider/shared_preferences_provider.dart';
import 'package:keek_news/repository/apk_install/apk_install_repo.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:keek_news/use_case/update_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/merged_feed_helper.dart';
import 'helpers/package_info_helper.dart';

class MockUpdateRepository extends Mock implements UpdateRepo {}

class MockApkInstallRepo extends Mock implements ApkInstallRepo {}

void main() {
  late MockUpdateRepository mockUpdateRepo;
  late MockApkInstallRepo mockApkRepo;
  late MockMergedFeedUseCase mockMergedUseCase;
  late SharedPreferences prefs;

  setUpAll(() async {
    await setupPackageInfoMock();
    registerMergedFeedFallbacks();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockUpdateRepo = MockUpdateRepository();
    mockApkRepo = MockApkInstallRepo();
    mockMergedUseCase = MockMergedFeedUseCase();
    setupMergedFeedMocks(mockMergedUseCase);
    await di.configureDependencies();
    if (di.sl.isRegistered<UpdateRepo>()) {
      di.sl.unregister<UpdateRepo>();
    }
    if (di.sl.isRegistered<UpdateUseCase>()) {
      di.sl.unregister<UpdateUseCase>();
    }
    if (di.sl.isRegistered<FeedUseCase>()) {
      di.sl.unregister<FeedUseCase>();
    }
    if (di.sl.isRegistered<ApkInstallRepo>()) {
      di.sl.unregister<ApkInstallRepo>();
    }
    di.sl.registerLazySingleton<UpdateRepo>(() => mockUpdateRepo);
    di.sl.registerLazySingleton<ApkInstallRepo>(() => mockApkRepo);
    di.sl.registerLazySingleton(
      () => UpdateUseCase(
        updateRepo: mockUpdateRepo,
        apkRepo: mockApkRepo,
        currentVersion: '1.1.0',
      ),
    );
    di.sl.registerLazySingleton<FeedUseCase>(() => mockMergedUseCase);
  });

  tearDown(di.sl.reset);

  testWidgets('should render merged feed title', (WidgetTester tester) async {
    when(() => mockUpdateRepo.getLatestRelease()).thenAnswer(
      (_) async =>
          const AppRelease(version: '1.1.0', htmlUrl: 'https://example.com'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const KeekNewsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('웃긴대학'), findsOneWidget);
    expect(find.byType(HomeView), findsOneWidget);
  });
}
