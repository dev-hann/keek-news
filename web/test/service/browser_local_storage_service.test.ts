// @vitest-environment jsdom
import { beforeEach, describe, expect, it } from 'vitest';
import { BrowserLocalStorageService } from '../../src/service/browser_local_storage_service';

describe('BrowserLocalStorageService', () => {
  beforeEach(() => window.localStorage.clear());

  it('keeps text under its key and forgets it on remove', () => {
    const storage = new BrowserLocalStorageService();

    expect(storage.getString('k')).toBeNull();
    storage.setString('k', 'v');
    expect(storage.getString('k')).toBe('v');
    expect(storage.containsKey('k')).toBe(true);
    storage.remove('k');
    expect(storage.containsKey('k')).toBe(false);
  });

  it('keeps a list of names', () => {
    const storage = new BrowserLocalStorageService();

    storage.setStringList('k', ['dogdrip', 'ppomppu']);

    expect(storage.getStringList('k')).toEqual(['dogdrip', 'ppomppu']);
  });

  it('answers null for a key that holds no list', () => {
    const storage = new BrowserLocalStorageService();
    storage.setString('k', '{not json');

    expect(storage.getStringList('k')).toBeNull();
    storage.setString('k', '{"a":1}');
    expect(storage.getStringList('k')).toBeNull();
  });
});
