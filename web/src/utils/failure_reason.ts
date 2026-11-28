import type { Failure } from '../model/failures';

/** Why a page fetch failed, in the words of a reader. */
export function failureReason(failure: Failure): string {
  switch (failure.kind) {
    case 'NetworkFailure':
      return '네트워크 오류';
    case 'ServerFailure':
      return '서버 오류';
    case 'ParseFailure':
      return '차단 또는 구조 변경 가능성';
    default:
      return failure.message;
  }
}

/** The site answered that the post is not there any more: deleted, or made private. */
export function isPostGone(failure: Failure): boolean {
  const status = failure.http?.statusCode;
  return failure.kind === 'ServerFailure' && (status === 404 || status === 410);
}
