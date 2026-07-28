import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/core/errors/failures.dart';
import 'package:humoruniv/domain/entities/app_release.dart';
import 'package:humoruniv/domain/entities/merged_feed.dart';
import 'package:humoruniv/domain/repositories/update_repository.dart';
import 'package:humoruniv/domain/usecases/check_for_update.dart';
import 'package:humoruniv/di/injection.dart' as di;
import 'package:humoruniv/main.dart';
import 'package:humoruniv/presentation/providers/merged_feed_provider.dart';
import 'package:humoruniv/presentation/providers/shared_preferences_provider.dart';
import 'package:humoruniv/presentation/screens/home_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/package_info_helper.dart';

class MockUpdateRepository extends Mock implements UpdateRepository {}

void main() {
  late MockUpdateRepository mockUpdateRepo;
  late SharedPreferences prefs;

  setUpAll(() async {
    await setupPackageInfoMock();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockUpdateRepo = MockUpdateRepository();
    await di.configureDependencies();
    if (di.sl.isRegistered<UpdateRepository>()) {
      di.sl.unregister<UpdateRepository>();
    }
    if (di.sl.isRegistered<CheckForUpdate>()) {
      di.sl.unregister<CheckForUpdate>();
    }
    di.sl.registerLazySingleton<UpdateRepository>(() => mockUpdateRepo);
    di.sl.registerLazySingleton(
      () => CheckForUpdate(repository: mockUpdateRepo, currentVersion: '1.1.0'),
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
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mergedFeedProvider.overrideWith(
            (ref) async => const Right(MergedPage(items: [])),
          ),
        ],
        child: const HumorUnivApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('통합 유머 피드'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
