/** The kinds of stretch a pull can be in. */
export const PULL_START_SLOP = 12;
export const PULL_TRIGGER = 72;
export const PULL_MAX = 96;

/**
 * How far the indicator follows a finger that moved `delta` past the top of
 * the page. It yields as the pull grows, so there is always room left to pull.
 */
export function pullDistance(delta: number): number {
  if (delta <= PULL_START_SLOP) return 0;
  return Math.min((delta - PULL_START_SLOP) * 0.5, PULL_MAX);
}

export function pullReleases(delta: number): boolean {
  return pullDistance(delta) >= PULL_TRIGGER;
}
