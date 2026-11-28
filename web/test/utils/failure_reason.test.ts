import { describe, expect, it } from 'vitest';
import { NetworkFailure, ParseFailure, ServerFailure } from '../../src/model/failures';
import { isPostGone } from '../../src/utils/failure_reason';

const answered = (statusCode: number) =>
  new ServerFailure('x', { statusCode, headers: {}, bodySnippet: '' });

describe('isPostGone', () => {
  it.each([404, 410])('the site answered %s', (status) => {
    expect(isPostGone(answered(status))).toBe(true);
  });

  it.each([403, 500, 503])('the site answered %s: not gone, it may come back', (status) => {
    expect(isPostGone(answered(status))).toBe(false);
  });

  it('no answer at all', () => {
    expect(isPostGone(new NetworkFailure('x'))).toBe(false);
  });

  it('a page nothing could be read from', () => {
    expect(isPostGone(new ParseFailure('x'))).toBe(false);
  });

  it('a server failure without a status', () => {
    expect(isPostGone(new ServerFailure('x'))).toBe(false);
  });
});
