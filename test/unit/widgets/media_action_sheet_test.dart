import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/widgets/media_action_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

typedef _SaveHandler =
    Future<Either<MediaSaveFailure, Unit>> Function(
      void Function(DownloadProgress progress)? onProgress,
    );

Future<void> _pumpSheet(
  WidgetTester tester, {
  required MediaTarget target,
  _SaveHandler? onSave,
  _SaveHandler? onShare,
  Future<void> Function()? onCopyUrl,
}) async {
  onCancelCalled = false;
  await tester.pumpWidget(
    shadAppWithMessenger(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => MediaActionSheet(
                  target: target,
                  onSave: onSave ?? (_) async => const Right(unit),
                  onShare: onShare ?? (_) async => const Right(unit),
                  onCopyUrl: onCopyUrl ?? () async {},
                  onCancelDownload: () => onCancelCalled = true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool onCancelCalled = false;

/// Advances past the sheet-pop + snackbar-entrance animations, asserts, then
/// expires the snackbar so no timer outlives the test. pumpAndSettle cannot
/// be used with a floating snackbar here: its 4s auto-dismiss timer keeps
/// the settle loop running past the test timeout.
Future<void> _pumpSnackbarCycle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('MediaActionSheet', () {
    testWidgets('renders save/share/copy rows for an image', (tester) async {
      await _pumpSheet(tester, target: MediaTarget.image('https://x/a.jpg'));

      expect(find.text('갤러리에 저장'), findsOneWidget);
      expect(find.text('공유'), findsOneWidget);
      expect(find.text('URL 복사'), findsOneWidget);
    });

    testWidgets('image target shows the imageDown save icon', (tester) async {
      await _pumpSheet(tester, target: MediaTarget.image('https://x/a.jpg'));
      expect(find.byIcon(LucideIcons.imageDown), findsOneWidget);
    });

    testWidgets('video target shows the download save icon', (tester) async {
      await _pumpSheet(
        tester,
        target: MediaTarget.video(const VideoBlock(url: 'https://x/v.mp4')),
      );
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
    });

    testWidgets('external embed hides the save row', (tester) async {
      await _pumpSheet(
        tester,
        target: MediaTarget.video(
          const VideoBlock(url: 'https://youtu.be/abc12345678'),
        ),
      );

      expect(find.text('갤러리에 저장'), findsNothing);
      expect(find.text('공유'), findsOneWidget);
      expect(find.text('URL 복사'), findsOneWidget);
    });

    testWidgets('successful save closes the sheet and shows a snackbar', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onSave: (_) async => const Right(unit),
      );

      await tester.tap(find.text('갤러리에 저장'));
      await _pumpSnackbarCycle(tester);

      expect(find.text('저장했어요'), findsOneWidget);
      expect(find.text('갤러리에 저장'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('network failure shows an inline retry state', (tester) async {
      var attempts = 0;
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onSave: (_) async {
          attempts++;
          return attempts == 1
              ? const Left(MediaSaveFailure(MediaSaveFailureType.network))
              : const Right(unit);
        },
      );

      await tester.tap(find.text('갤러리에 저장'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('저장에 실패했어요 · 탭하여 재시도'), findsOneWidget);
      expect(find.text('open'), findsOneWidget);

      await tester.tap(find.text('저장에 실패했어요 · 탭하여 재시도'));
      await _pumpSnackbarCycle(tester);

      expect(find.text('저장했어요'), findsOneWidget);
      expect(find.text('갤러리에 저장'), findsNothing);
    });

    testWidgets('permission failure closes with a settings snackbar', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onSave: (_) async =>
            const Left(MediaSaveFailure(MediaSaveFailureType.permission)),
      );

      await tester.tap(find.text('갤러리에 저장'));
      await _pumpSnackbarCycle(tester);

      expect(find.text('갤러리 접근 권한이 필요해요. 시스템 설정에서 허용해주세요'), findsOneWidget);
      expect(find.text('갤러리에 저장'), findsNothing);
    });

    testWidgets('download progress renders determinate percent and cancel', (
      tester,
    ) async {
      final completer = Completer<Either<MediaSaveFailure, Unit>>();
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onSave: (onProgress) {
          onProgress?.call(
            const DownloadProgress(receivedBytes: 5, totalBytes: 10),
          );
          return completer.future;
        },
      );

      await tester.tap(find.text('갤러리에 저장'));
      await tester.pump();

      expect(find.text('저장 중… 50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.text('저장 중… 50%'));
      await tester.pump();

      expect(onCancelCalled, isTrue);

      completer.complete(
        const Left(MediaSaveFailure(MediaSaveFailureType.canceled)),
      );
      await tester.pumpAndSettle();

      expect(find.text('갤러리에 저장'), findsOneWidget);
    });

    testWidgets('unknown-size progress shows no percent', (tester) async {
      final completer = Completer<Either<MediaSaveFailure, Unit>>();
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onSave: (onProgress) {
          onProgress?.call(
            const DownloadProgress(receivedBytes: 5, totalBytes: 0),
          );
          return completer.future;
        },
      );

      await tester.tap(find.text('갤러리에 저장'));
      await tester.pump();

      expect(find.text('저장 중…'), findsOneWidget);
      expect(find.text('저장 중… 0%'), findsNothing);

      completer.complete(const Right(unit));
      await _pumpSnackbarCycle(tester);
    });

    testWidgets('copy closes the sheet and shows a snackbar', (tester) async {
      var copied = false;
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onCopyUrl: () async => copied = true,
      );

      await tester.tap(find.text('URL 복사'));
      await _pumpSnackbarCycle(tester);

      expect(copied, isTrue);
      expect(find.text('링크를 복사했어요'), findsOneWidget);
      expect(find.text('URL 복사'), findsNothing);
    });

    testWidgets('successful share closes the sheet without a snackbar', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onShare: (_) async => const Right(unit),
      );

      await tester.tap(find.text('공유'));
      await tester.pumpAndSettle();

      expect(find.text('공유'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('share cancel returns the row to idle', (tester) async {
      final completer = Completer<Either<MediaSaveFailure, Unit>>();
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onShare: (_) => completer.future,
      );

      await tester.tap(find.text('공유'));
      await tester.pump();

      expect(find.text('준비 중…'), findsOneWidget);

      completer.complete(
        const Left(MediaSaveFailure(MediaSaveFailureType.canceled)),
      );
      await tester.pumpAndSettle();

      expect(find.text('공유'), findsOneWidget);
    });

    testWidgets('dismissing the sheet cancels an in-flight download', (
      tester,
    ) async {
      final completer = Completer<Either<MediaSaveFailure, Unit>>();
      await _pumpSheet(
        tester,
        target: MediaTarget.image('https://x/a.jpg'),
        onSave: (_) => completer.future,
      );

      await tester.tap(find.text('갤러리에 저장'));
      await tester.pump();

      await tester.tapAt(const Offset(400, 10));
      await tester.pumpAndSettle();

      expect(onCancelCalled, isTrue);
      expect(find.text('open'), findsOneWidget);

      completer.complete(
        const Left(MediaSaveFailure(MediaSaveFailureType.canceled)),
      );
      await tester.pumpAndSettle();
    });
  });
}
