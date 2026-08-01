import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/utils/error_report.dart';

void main() {
  group('formatErrorReport', () {
    test(
      'contains community label, id, url, title, failure type and message',
      () {
        final report = formatErrorReport(
          communityLabel: '개드립',
          postId: '716784390',
          url: 'https://www.dogdrip.net/716784390',
          title: '싱글벙글',
          failure: const NetworkFailure('connection timed out'),
          now: DateTime(2026, 8, 1, 14, 23),
        );

        expect(report, contains('커뮤니티: 개드립'));
        expect(report, contains('게시글ID: 716784390'));
        expect(report, contains('URL: https://www.dogdrip.net/716784390'));
        expect(report, contains('타이틀: 싱글벙글'));
        expect(report, contains('오류유형: NetworkFailure'));
        expect(report, contains('메시지: connection timed out'));
        expect(report, contains('단계: detail_fetch'));
        expect(report, contains('시간: 2026-08-01T14:23:00'));
      },
    );

    test('substitutes placeholder when title is null', () {
      final report = formatErrorReport(
        communityLabel: '오늘의유머',
        postId: '1',
        url: 'u',
        title: null,
        failure: const ParseFailure('본문 없음'),
      );

      expect(report, contains('타이틀: (알 수 없음)'));
      expect(report, contains('오류유형: ParseFailure'));
    });

    test('includes app version when provided', () {
      final report = formatErrorReport(
        communityLabel: '웃긴대학',
        postId: '1',
        url: 'u',
        title: 't',
        failure: const ServerFailure('x'),
        appVersion: '1.2.3',
      );

      expect(report, contains('앱버전: 1.2.3'));
    });

    test('omits app version line when not provided', () {
      final report = formatErrorReport(
        communityLabel: '웃긴대학',
        postId: '1',
        url: 'u',
        title: 't',
        failure: const ServerFailure('x'),
      );

      expect(report, isNot(contains('앱버전')));
    });
  });

  group('formatErrorReport CommunityId displayName sanity', () {
    // Sanity: ensure every community has a displayName usable as a label.
    test('every community exposes a non-empty displayName', () {
      for (final c in communities) {
        expect(c.displayName, isNotEmpty);
      }
    });
  });
}
