import 'package:keek_news/model/failures.dart';

/// Builds a plain-text error report meant to be copied to the clipboard and
/// pasted back for tracking. Pure (no Flutter deps) so it is unit-testable.
String formatErrorReport({
  required String communityLabel,
  required String postId,
  required String url,
  required String? title,
  required Failure failure,
  String stage = 'detail_fetch',
  String? appVersion,
  DateTime? now,
}) {
  final ts = (now ?? DateTime.now()).toIso8601String();
  final lines = <String>[
    '[KeekNews 오류 리포트]',
    '커뮤니티: $communityLabel',
    '게시글ID: $postId',
    'URL: $url',
    '타이틀: ${title ?? '(알 수 없음)'}',
    '오류유형: ${failure.runtimeType}',
    '메시지: ${failure.message}',
    if (failure.http != null) ..._diagnosticLines(failure.http!),
    '단계: $stage',
    '시간: $ts',
    if (appVersion != null && appVersion.isNotEmpty) '앱버전: $appVersion',
  ];
  return lines.join('\n');
}

List<String> _diagnosticLines(HttpDiagnostics diag) {
  final h = diag.headers;
  final lines = <String>[
    '진단:',
    if (diag.requestPath != null && diag.requestPath!.isNotEmpty)
      '  요청: ${diag.requestPath}',
    if (diag.statusCode != null) '  상태코드: ${diag.statusCode}',
    for (final key in const ['server', 'cf-ray', 'cf-mitigated', 'retry-after'])
      if (h[key] != null && h[key]!.isNotEmpty) '  $key: ${h[key]}',
    if (diag.bodySnippet.isNotEmpty) ...[
      '  본문 일부:',
      ...diag.bodySnippet.split('\n').map((l) => '    $l'),
    ],
    '(진단 정보에는 응답 헤더 일부와 본문 500자가 포함됩니다)',
  ];
  return lines;
}
