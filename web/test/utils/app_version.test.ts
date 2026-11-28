import { describe, expect, it } from 'vitest';
import { isNewerVersion, versionOfTag } from '../../src/utils/app_version';

describe('versionOfTag', () => {
  it('is the version a tag names, without the v', () => {
    expect(versionOfTag('v4.1.0')).toBe('4.1.0');
    expect(versionOfTag('V4.1.0')).toBe('4.1.0');
    expect(versionOfTag('4.1.0')).toBe('4.1.0');
  });

  it('is written with three numbers, whatever the tag pads them with', () => {
    expect(versionOfTag('v04.01.000')).toBe('4.1.0');
  });

  it('drops what follows a dash or a plus: 4.1.0-rc.1 is the version 4.1.0', () => {
    expect(versionOfTag('v4.1.0-rc.1')).toBe('4.1.0');
    expect(versionOfTag('4.1.0+build.7')).toBe('4.1.0');
  });

  it('is nothing for a tag that is not a version', () => {
    expect(versionOfTag('v4.1')).toBeNull();
    expect(versionOfTag('v4')).toBeNull();
    expect(versionOfTag('latest')).toBeNull();
    expect(versionOfTag('nightly-2026-11-28')).toBeNull();
    expect(versionOfTag('')).toBeNull();
    expect(versionOfTag('v4.1.x')).toBeNull();
  });
});

describe('isNewerVersion', () => {
  it('compares the numbers one by one, from the left', () => {
    expect(isNewerVersion('4.1.0', '4.0.0')).toBe(true);
    expect(isNewerVersion('4.0.1', '4.0.0')).toBe(true);
    expect(isNewerVersion('4.0.0', '4.1.0')).toBe(false);
    expect(isNewerVersion('4.0.0', '4.0.0')).toBe(false);
  });

  it('compares numbers, not text', () => {
    expect(isNewerVersion('4.0.10', '4.0.9')).toBe(true);
    expect(isNewerVersion('4.10.0', '4.9.0')).toBe(true);
  });

  it('takes the v of a tag and what follows a dash', () => {
    expect(isNewerVersion('v4.1.0', 'v4.0.0')).toBe(true);
    expect(isNewerVersion('4.1.0-rc.1', '4.0.9')).toBe(true);
  });

  it('is false when either is not a version', () => {
    expect(isNewerVersion('nightly', '4.0.0')).toBe(false);
    expect(isNewerVersion('4.1.0', 'unknown')).toBe(false);
  });
});
