import type { Failure, HttpDiagnostics } from '../model/failures';

export interface ErrorReportInput {
  communityLabel: string;
  postId: string;
  url: string;
  title?: string | null;
  failure: Failure;
  stage?: string;
  appVersion?: string | null;
  now?: Date;
}

const pad = (value: number) => String(value).padStart(2, '0');

/** `YYYY-MM-DDTHH:MM:SS` in the time of the device: the report is read by a person. */
function localTimestamp(date: Date): string {
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

/**
 * A plain-text error report meant to be copied to the clipboard and pasted
 * back for tracking.
 */
export function formatErrorReport(input: ErrorReportInput): string {
  const { failure } = input;
  const lines = [
    '[KeekNews 오류 리포트]',
    `커뮤니티: ${input.communityLabel}`,
    `게시글ID: ${input.postId}`,
    `URL: ${input.url}`,
    `타이틀: ${input.title ?? '(알 수 없음)'}`,
    `오류유형: ${failure.kind}`,
    `메시지: ${failure.message}`,
    ...(failure.http ? diagnosticLines(failure.http) : []),
    `단계: ${input.stage ?? 'detail_fetch'}`,
    `시간: ${localTimestamp(input.now ?? new Date())}`,
    ...(input.appVersion ? [`앱버전: ${input.appVersion}`] : []),
  ];
  return lines.join('\n');
}

function diagnosticLines(diagnostics: HttpDiagnostics): string[] {
  const headers = diagnostics.headers;
  return [
    '진단:',
    ...(diagnostics.requestPath ? [`  요청: ${diagnostics.requestPath}`] : []),
    ...(diagnostics.statusCode !== undefined ? [`  상태코드: ${diagnostics.statusCode}`] : []),
    ...['server', 'cf-ray', 'cf-mitigated', 'retry-after'].flatMap((key) =>
      headers[key] ? [`  ${key}: ${headers[key]}`] : []
    ),
    ...(diagnostics.bodySnippet
      ? ['  본문 일부:', ...diagnostics.bodySnippet.split('\n').map((line) => `    ${line}`)]
      : []),
    '(진단 정보에는 응답 헤더 일부와 본문 500자가 포함됩니다)',
  ];
}
