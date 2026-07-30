import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/app.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/pages/home_view.dart';
import 'package:keek_news/provider/shared_preferences_provider.dart';
import 'package:keek_news/repository/merged_feed/merged_feed_repo.dart';
import 'package:keek_news/repository/update/update_repo.dart';
import 'package:keek_news/service/service_locator.dart' as di;
import 'package:keek_news/use_case/check_for_update_use_case.dart';
import 'package:keek_news/use_case/get_merged_feed_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/merged_feed_helper.dart';
import 'helpers/package_info_helper.dart';

class MockUpdateRepository extends Mock implements UpdateRepo {}

void main() {
  late MockUpdateRepository mockUpdateRepo;
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
    mockMergedRepo = MockMergedFeedRepository();
    setupMergedFeedMocks(mockMergedRepo);
    await di.configureDependencies();
    if (di.sl.isRegistered<UpdateRepo>()) {
      di.sl.unregister<UpdateRepo>();
    }
    if (di.sl.isRegistered<CheckForUpdateUseCase>()) {
      di.sl.unregister<CheckForUpdateUseCase>();
    }
    if (di.sl.isRegistered<MergedFeedRepo>()) {
      di.sl.unregister<MergedFeedRepo>();
    }
    if (di.sl.isRegistered<GetMergedFeedUseCase>()) {
      di.sl.unregister<GetMergedFeedUseCase>();
    }
    di.sl.registerLazySingleton<UpdateRepo>(() => mockUpdateRepo);
    di.sl.registerLazySingleton(
      () => CheckForUpdateUseCase(
        repository: mockUpdateRepo,
        currentVersion: '1.1.0',
      ),
    );
    di.sl.registerLazySingleton<MergedFeedRepo>(() => mockMergedRepo);
    di.sl.registerLazySingleton(
      () => GetMergedFeedUseCase(repository: mockMergedRepo),
    );
  });

  tearDown(di.sl.reset);

  testWidgets('should render merged feed title', (WidgetTester tester) async {
    when(() => mockUpdateRepo.getLatestRelease()).thenAnswer(
      (_) async => const Right(
        AppRelease(version: '1.1.0', htmlUrl: 'https://example.com'),
      ),
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
