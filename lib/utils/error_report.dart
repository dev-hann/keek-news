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
    '단계: $stage',
    '시간: $ts',
    if (appVersion != null && appVersion.isNotEmpty) '앱버전: $appVersion',
  ];
  return lines.join('\n');
}
