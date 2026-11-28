import { describe, expect, it } from 'vitest';
import { formatTimeAgo } from '../../src/utils/time_ago';

describe('formatTimeAgo', () => {
  const now = new Date(2026, 7, 15, 12, 0, 0);
  const ago = (seconds: number) => new Date(now.getTime() - seconds * 1000);
  const minute = 60;
  const hour = 60 * minute;
  const day = 24 * hour;

  it.each([
    [0, '방금 전'],
    [59, '방금 전'],
    [60, '1분 전'],
    [5 * minute + 30, '5분 전'],
    [59 * minute + 59, '59분 전'],
    [hour, '1시간 전'],
    [23 * hour, '23시간 전'],
    [day, '1일 전'],
    [6 * day, '6일 전'],
    [7 * day, '1주 전'],
    [13 * day, '1주 전'],
    [29 * day, '4주 전'],
    [30 * day, '1개월 전'],
    [364 * day, '12개월 전'],
    [365 * day, '1년 전'],
    [800 * day, '2년 전'],
  ] as const)('%i seconds ago is %s', (seconds, expected) => {
    expect(formatTimeAgo(ago(seconds), now)).toBe(expected);
  });
});
