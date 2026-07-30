import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/widgets/molecules/update_banner.dart';
import 'package:happy_news/domain/entities/download_progress.dart';
import 'package:happy_news/presentation/providers/update_provider.dart';

void main() {
  group('UpdateBanner', () {
    testWidgets('should show check button when idle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UpdateBanner(status: UpdateCheckStatus.idle)),
        ),
      );

      expect(find.text('업데이트 확인'), findsOneWidget);
    });

    testWidgets('should show loading indicator when checking', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateBanner(status: UpdateCheckStatus.checking),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show up to date text when up to date', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateBanner(status: UpdateCheckStatus.upToDate),
          ),
        ),
      );

      expect(find.text('최신 버전입니다'), findsOneWidget);
    });

    testWidgets('should show update button when available', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.available,
              newVersion: '1.2.0',
            ),
          ),
        ),
      );

      expect(find.text('v1.2.0 사용 가능'), findsOneWidget);
      expect(find.text('업데이트'), findsOneWidget);
    });

    testWidgets('should show error text when error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UpdateBanner(status: UpdateCheckStatus.error)),
        ),
      );

      expect(find.text('확인 실패'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('should show error_outline icon when error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UpdateBanner(status: UpdateCheckStatus.error)),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('should show check_circle icon when up to date', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateBanner(status: UpdateCheckStatus.upToDate),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should call onCheck when error state tapped', (tester) async {
      var checked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.error,
              onCheck: () => checked = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      expect(checked, true);
    });

    testWidgets('error retry touch target should be at least 44pt tall', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UpdateBanner(status: UpdateCheckStatus.error)),
        ),
      );

      final size = tester.getSize(find.byType(InkWell));
      expect(size.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
    });

    testWidgets('should call onCheck when check button tapped', (tester) async {
      var checked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.idle,
              onCheck: () => checked = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('업데이트 확인'));
      expect(checked, true);
    });

    testWidgets('should call onUpdate when update button tapped', (
      tester,
    ) async {
      var updated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.available,
              newVersion: '1.2.0',
              onUpdate: () => updated = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('업데이트'));
      expect(updated, true);
    });
  });

  group('UpdateBanner in-app update states', () {
    testWidgets('downloading shows progress percent and cancel affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.downloading,
              downloadProgress: DownloadProgress(
                receivedBytes: 40,
                totalBytes: 100,
              ),
            ),
          ),
        ),
      );

      expect(find.text('다운로드 중 40%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
    });

    testWidgets('downloading cancel tap calls onCancelDownload', (
      tester,
    ) async {
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.downloading,
              downloadProgress: const DownloadProgress(
                receivedBytes: 10,
                totalBytes: 100,
              ),
              onCancelDownload: () => cancelled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('취소'));
      expect(cancelled, true);
    });

    testWidgets('downloadError shows label and retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.downloadError,
              onRetryDownload: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('다운로드 실패'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      expect(retried, true);
    });

    testWidgets('readyToInstall shows complete label and install button', (
      tester,
    ) async {
      var installed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.readyToInstall,
              onInstall: () => installed = true,
            ),
          ),
        ),
      );

      expect(find.text('다운로드 완료'), findsOneWidget);
      expect(find.text('설치'), findsOneWidget);
      await tester.tap(find.text('설치'));
      expect(installed, true);
    });

    testWidgets('installPermissionRequired shows settings button', (
      tester,
    ) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.installPermissionRequired,
              onOpenPermissionSettings: () => opened = true,
            ),
          ),
        ),
      );

      expect(find.text('설치 권한 필요'), findsOneWidget);
      expect(find.text('설정 열기'), findsOneWidget);
      await tester.tap(find.text('설정 열기'));
      expect(opened, true);
    });

    testWidgets(
      'available with no APK download url shows browser-open button',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UpdateBanner(
                status: UpdateCheckStatus.available,
                newVersion: '1.2.0',
                hasApkDownloadUrl: false,
              ),
            ),
          ),
        );

        expect(find.text('브라우저에서 열기'), findsOneWidget);
        expect(find.text('업데이트'), findsNothing);
      },
    );

    testWidgets('download cancel touch target is at least 44pt tall', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateBanner(
              status: UpdateCheckStatus.downloading,
              downloadProgress: DownloadProgress(
                receivedBytes: 10,
                totalBytes: 100,
              ),
            ),
          ),
        ),
      );

      final cancelFinder = find.text('취소');
      final size = tester.getSize(cancelFinder);
      // The chip wrapping the text enforces the 44pt minimum height.
      final chipSize = tester.getSize(
        find.ancestor(of: cancelFinder, matching: find.byType(ConstrainedBox)),
      );
      expect(chipSize.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
      expect(size, isNotNull);
    });
  });
}
