import { describe, expect, it } from 'vitest';
import { communities } from '../../src/model/community';
import { NetworkFailure, ParseFailure, ServerFailure } from '../../src/model/failures';
import { formatErrorReport } from '../../src/utils/error_report';

describe('formatErrorReport', () => {
  it('contains the community label, id, url, title, failure type and message', () => {
    const report = formatErrorReport({
      communityLabel: '개드립',
      postId: '716784390',
      url: 'https://www.dogdrip.net/716784390',
      title: '싱글벙글',
      failure: new NetworkFailure('connection timed out'),
      now: new Date(2026, 7, 1, 14, 23),
    });

    expect(report).toContain('커뮤니티: 개드립');
    expect(report).toContain('게시글ID: 716784390');
    expect(report).toContain('URL: https://www.dogdrip.net/716784390');
    expect(report).toContain('타이틀: 싱글벙글');
    expect(report).toContain('오류유형: NetworkFailure');
    expect(report).toContain('메시지: connection timed out');
    expect(report).toContain('단계: detail_fetch');
    expect(report).toContain('시간: 2026-08-01T14:23:00');
  });

  it('puts a placeholder where the title is missing', () => {
    const report = formatErrorReport({
      communityLabel: '오늘의유머',
      postId: '1',
      url: 'u',
      title: null,
      failure: new ParseFailure('본문 없음'),
    });

    expect(report).toContain('타이틀: (알 수 없음)');
    expect(report).toContain('오류유형: ParseFailure');
  });

  it('names the app version when there is one', () => {
    const report = formatErrorReport({
      communityLabel: '웃긴대학',
      postId: '1',
      url: 'u',
      title: 't',
      failure: new ServerFailure('x'),
      appVersion: '1.2.3',
    });

    expect(report).toContain('앱버전: 1.2.3');
  });

  it('leaves the app version out when there is none', () => {
    const report = formatErrorReport({
      communityLabel: '웃긴대학',
      postId: '1',
      url: 'u',
      title: 't',
      failure: new ServerFailure('x'),
    });

    expect(report).not.toContain('앱버전');
  });

  it('leaves the diagnostics out when the failure carries none', () => {
    const report = formatErrorReport({
      communityLabel: '개드립',
      postId: '1',
      url: 'u',
      title: 't',
      failure: new ServerFailure('x'),
    });

    expect(report).not.toContain('진단');
    expect(report).not.toContain('cf-ray');
  });

  it('describes what the server answered when the failure carries it', () => {
    const report = formatErrorReport({
      communityLabel: '개드립',
      postId: '716882815',
      url: 'https://www.dogdrip.net/716882815',
      title: 't',
      failure: new ServerFailure('503 boom', {
        statusCode: 503,
        headers: {
          server: 'cloudflare',
          'cf-ray': 'abc-ICN',
          'cf-mitigated': 'challenge',
          'retry-after': '120',
        },
        bodySnippet: '<html>just a moment</html>',
        requestPath: '/716882815',
      }),
    });

    expect(report).toContain('진단:');
    expect(report).toContain('요청: /716882815');
    expect(report).toContain('상태코드: 503');
    expect(report).toContain('server: cloudflare');
    expect(report).toContain('cf-ray: abc-ICN');
    expect(report).toContain('cf-mitigated: challenge');
    expect(report).toContain('retry-after: 120');
    expect(report).toContain('본문 일부:');
    expect(report).toContain('<html>just a moment</html>');
    expect(report).toContain('진단 정보에는');
  });

  it('leaves out the header lines that are absent', () => {
    const report = formatErrorReport({
      communityLabel: '개드립',
      postId: '1',
      url: 'u',
      title: 't',
      failure: new ServerFailure('x', { statusCode: 500, headers: {}, bodySnippet: '' }),
    });

    expect(report).toContain('상태코드: 500');
    expect(report).not.toContain('cf-ray');
    expect(report).not.toContain('server:');
  });
});

describe('community labels', () => {
  it('every community has a name to label an error with', () => {
    for (const community of Object.values(communities)) {
      expect(community.displayName.length).toBeGreaterThan(0);
    }
  });
});
