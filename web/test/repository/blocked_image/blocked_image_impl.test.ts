import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  type BlockedImage,
  blockedImageFromJson,
  blockedImageToJson,
} from '../../../src/model/blocked_image';
import { BlockedImageImpl } from '../../../src/repository/blocked_image/blocked_image_impl';
import type { LocalStorageService } from '../../../src/service/local_storage_service';

const STORAGE_KEY = 'blocked_images';

/** The one element of a list, as Dart's `.single`. */
const single = <T>(items: T[]): T => {
  expect(items).toHaveLength(1);
  return items[0];
};

let getString: ReturnType<typeof vi.fn<LocalStorageService['getString']>>;
let setString: ReturnType<typeof vi.fn<LocalStorageService['setString']>>;
let repo: BlockedImageImpl;

const image = (url: string): BlockedImage => ({ url, blockedAt: new Date(1722324000000) });

const encodeAll = (all: BlockedImage[]): string => JSON.stringify(all.map(blockedImageToJson));

/** The one string written under the key, read back as the repo reads it. */
const persistedSingle = (): BlockedImage[] => {
  const writes = setString.mock.calls
    .filter(([key]) => key === STORAGE_KEY)
    .map(([, value]) => value);
  return (JSON.parse(single(writes)) as Record<string, unknown>[]).map(blockedImageFromJson);
};

beforeEach(() => {
  getString = vi.fn<LocalStorageService['getString']>();
  setString = vi.fn<LocalStorageService['setString']>();
  const storage: LocalStorageService = {
    getString,
    setString,
    getStringList: () => null,
    setStringList: () => undefined,
    containsKey: () => false,
    remove: () => undefined,
  };
  repo = new BlockedImageImpl(storage);
});

describe('BlockedImageImpl getAll', () => {
  it('should decode stored JSON into images', () => {
    getString.mockReturnValue(encodeAll([image('https://x/a.jpg')]));

    const result = repo.getAll();

    expect(getString).toHaveBeenCalledExactlyOnceWith(STORAGE_KEY);
    expect(result).toHaveLength(1);
    expect(result[0].url).toBe('https://x/a.jpg');
  });

  it('should return empty list when storage empty', () => {
    getString.mockReturnValue(null);

    const result = repo.getAll();

    expect(result).toEqual([]);
  });

  it('should skip malformed entries silently', () => {
    getString.mockReturnValue(
      JSON.stringify([
        blockedImageToJson(image('https://x/good.jpg')),
        { not: 'a blocked image' },
        'string instead of map',
      ])
    );

    const result = repo.getAll();

    expect(result).toHaveLength(1);
    expect(result[0].url).toBe('https://x/good.jpg');
  });

  // Added for the web. The Dart suite's malformed entries are a map without a
  // url and something that is not a map. These are the other entries the
  // Flutter reader skips or keeps, each as that reader did.
  it('should keep every entry the Flutter reader kept and skip the ones it threw on', () => {
    getString.mockReturnValue(
      JSON.stringify([
        { url: 5, blockedAtMillis: 1 },
        { url: 'a', blockedAtMillis: '1' },
        { url: 'a', blockedAtMillis: 1.5 },
        { url: 'a', blockedAtMillis: 9e18 },
        { url: 'a', blockedAtMillis: null },
        { url: 'neg', blockedAtMillis: -1 },
        { url: 'max', blockedAtMillis: 8640000000000000 },
        { url: 'over', blockedAtMillis: 8640000000000001 },
        { url: 'nullhash', blockedAtMillis: 0, hash: null },
        { url: 'numhash', blockedAtMillis: 0, hash: 5 },
        { url: 'emptyhash', blockedAtMillis: 0, hash: '' },
        { url: 'extra', blockedAtMillis: 25, hash: 'ABCDEF0123456789', extra: 1 },
        { url: '', blockedAtMillis: 0 },
        42,
        null,
        true,
        [],
        { url: 'nodate' },
        { blockedAtMillis: 0 },
      ])
    );

    const result = repo.getAll().map((b) => JSON.stringify(blockedImageToJson(b)));

    expect(result).toEqual([
      '{"url":"neg","blockedAtMillis":-1}',
      '{"url":"max","blockedAtMillis":8640000000000000}',
      '{"url":"nullhash","blockedAtMillis":0}',
      '{"url":"emptyhash","blockedAtMillis":0,"hash":""}',
      '{"url":"extra","blockedAtMillis":25,"hash":"ABCDEF0123456789"}',
      '{"url":"","blockedAtMillis":0}',
    ]);
  });
});

describe('BlockedImageImpl add', () => {
  it('should prepend and persist as JSON', () => {
    getString.mockReturnValue(encodeAll([image('https://x/old.jpg')]));

    repo.add(image('https://x/new.jpg'));

    const persisted = persistedSingle();
    expect(persisted[0].url).toBe('https://x/new.jpg');
    expect(persisted).toHaveLength(2);
  });

  it('should replace existing entry with same url', () => {
    getString.mockReturnValue(encodeAll([image('https://x/same.jpg')]));

    repo.add(image('https://x/same.jpg'));

    const persisted = persistedSingle();
    expect(persisted).toHaveLength(1);
  });

  it('should emit changes after persisting', () => {
    getString.mockReturnValue(null);

    let fired = 0;
    const unsubscribe = repo.changes.subscribe(() => fired++);
    repo.add(image('https://x/a.jpg'));

    expect(fired).toBe(1);
    unsubscribe();
  });

  // The Flutter app moves what readers blocked into this app, so what is written
  // must stay what `jsonEncode(images.map((b) => b.toJson()).toList())` wrote
  // there under `blocked_images`. The text below is that expression's output
  // for this list.
  it('should persist the text the Flutter app persisted', () => {
    getString.mockReturnValue(encodeAll([image('https://x/old.jpg')]));

    repo.add(image('https://x/new.jpg'));

    expect(setString).toHaveBeenCalledExactlyOnceWith(
      STORAGE_KEY,
      '[{"url":"https://x/new.jpg","blockedAtMillis":1722324000000},{"url":"https://x/old.jpg","blockedAtMillis":1722324000000}]'
    );
  });
});

describe('BlockedImageImpl hash matching', () => {
  const entry = (hash?: string): BlockedImage => ({
    url: 'https://x/a.jpg',
    blockedAt: new Date(0),
    ...(hash === undefined ? {} : { hash }),
  });

  it('should persist and reload the hash field', () => {
    getString.mockReturnValue(encodeAll([entry('0123456789abcdef')]));

    const result = repo.getAll();

    expect(single(result).hash).toBe('0123456789abcdef');
  });

  it('isHashBlocked matches within the Hamming threshold', () => {
    getString.mockReturnValue(encodeAll([entry('7e7e7e7e7e7e7e7e')]));

    // …7a is 1 bit away — inside the threshold.
    expect(repo.isHashBlocked('7e7e7e7e7e7e7e7a')).toBe(true);
    // …81 is 8 bits away — outside.
    expect(repo.isHashBlocked('7e7e7e7e7e7e7e81')).toBe(false);
  });

  it('isHashBlocked never matches degenerate fingerprints', () => {
    getString.mockReturnValue(encodeAll([entry('000000000000003f')]));

    // Sparse (near-flat picture) hashes collide too easily to trust, even
    // against themselves.
    expect(repo.isHashBlocked('000000000000003f')).toBe(false);
    expect(repo.isHashBlocked('00000000000000ff')).toBe(false);
  });

  it('isHashBlocked reads storage lazily without a prior getAll', () => {
    getString.mockReturnValue(encodeAll([entry('7e7e7e7e7e7e7e7e')]));

    expect(repo.isHashBlocked('7e7e7e7e7e7e7e7e')).toBe(true);
    // Added for the web: the blocklist is read and parsed once, however many render-time checks ask.
    repo.isHashBlocked('0000000000000000');
    expect(getString).toHaveBeenCalledTimes(1);
  });

  it('isHashBlocked skips entries without a hash', () => {
    getString.mockReturnValue(encodeAll([entry()]));

    expect(repo.isHashBlocked('7e7e7e7e7e7e7e7e')).toBe(false);
  });

  it('add stores the hash captured at block time', () => {
    getString.mockReturnValue(null);

    repo.add(entry('abcdef0123456789'));

    expect(single(persistedSingle()).hash).toBe('abcdef0123456789');
  });
});

describe('BlockedImageImpl remove', () => {
  it('should remove matching url and persist', () => {
    getString.mockReturnValue(
      encodeAll([image('https://x/keep.jpg'), image('https://x/drop.jpg')])
    );

    repo.remove('https://x/drop.jpg');

    const persisted = persistedSingle();
    expect(persisted).toHaveLength(1);
    expect(single(persisted).url).toBe('https://x/keep.jpg');
  });

  it('should emit changes after removing', () => {
    getString.mockReturnValue(encodeAll([image('https://x/drop.jpg')]));

    let fired = 0;
    const unsubscribe = repo.changes.subscribe(() => fired++);
    repo.remove('https://x/drop.jpg');

    expect(fired).toBe(1);
    unsubscribe();
  });
});
