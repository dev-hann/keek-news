import { describe, expect, it } from 'vitest';
import {
  PULL_MAX,
  PULL_TRIGGER,
  pullDistance,
  pullReleases,
} from '../../src/utils/pull_to_refresh';

describe('pullDistance', () => {
  it('ignores the first few pixels, so a tap or a small drag is not a pull', () => {
    expect(pullDistance(0)).toBe(0);
    expect(pullDistance(5)).toBe(0);
  });

  it('follows the finger at half its speed', () => {
    expect(pullDistance(12)).toBe(0);
    expect(pullDistance(32)).toBe(10);
    expect(pullDistance(72)).toBe(30);
  });

  it('stops at a maximum, so there is always room left to pull', () => {
    expect(pullDistance(1000)).toBe(PULL_MAX);
  });
});

describe('pullReleases', () => {
  it('refreshes only once the indicator has come far enough', () => {
    expect(pullReleases(100)).toBe(false);
    expect(pullReleases(12 + PULL_TRIGGER * 2)).toBe(true);
    expect(pullReleases(-10)).toBe(false);
  });
});
