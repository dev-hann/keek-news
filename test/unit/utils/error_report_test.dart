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

    test('omits diagnostics block when failure.http is null', () {
      final report = formatErrorReport(
        communityLabel: '개드립',
        postId: '1',
        url: 'u',
        title: 't',
        failure: const ServerFailure('x'),
      );

      expect(report, isNot(contains('진단')));
      expect(report, isNot(contains('cf-ray')));
    });

    test('includes diagnostics block when failure.http is present', () {
      final report = formatErrorReport(
        communityLabel: '개드립',
        postId: '716882815',
        url: 'https://www.dogdrip.net/716882815',
        title: 't',
        failure: const ServerFailure(
          '503 boom',
          http: HttpDiagnostics(
            statusCode: 503,
            headers: {
              'server': 'cloudflare',
              'cf-ray': 'abc-ICN',
              'cf-mitigated': 'challenge',
              'retry-after': '120',
            },
            bodySnippet: '<html>just a moment</html>',
            requestPath: '/716882815',
          ),
        ),
      );

      expect(report, contains('진단:'));
      expect(report, contains('요청: /716882815'));
      expect(report, contains('상태코드: 503'));
      expect(report, contains('server: cloudflare'));
      expect(report, contains('cf-ray: abc-ICN'));
      expect(report, contains('cf-mitigated: challenge'));
      expect(report, contains('retry-after: 120'));
      expect(report, contains('본문 일부:'));
      expect(report, contains('<html>just a moment</html>'));
      expect(report, contains('진단 정보에는'));
    });

    test('omits header lines that are absent', () {
      final report = formatErrorReport(
        communityLabel: '개드립',
        postId: '1',
        url: 'u',
        title: 't',
        failure: const ServerFailure(
          'x',
          http: HttpDiagnostics(statusCode: 500),
        ),
      );

      expect(report, contains('상태코드: 500'));
      expect(report, isNot(contains('cf-ray')));
      expect(report, isNot(contains('server:')));
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
