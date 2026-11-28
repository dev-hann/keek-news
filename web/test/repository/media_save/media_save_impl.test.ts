import type {
  FailedResult,
  Media,
  MediaFailureKind,
  SaveResult,
  ShareResult,
} from '@gyo-community/media';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { imageTarget, videoTarget } from '../../../src/model/media_target';
import { MediaSaveImpl } from '../../../src/repository/media_save/media_save_impl';

const PAGE_USER_AGENT = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36';

const saved: SaveResult = {
  status: 'saved',
  uri: 'content://media/external/images/media/1',
  mimeType: 'image/jpeg',
};
const shared: ShareResult = { status: 'shared' };

const failed = (kind: MediaFailureKind, message: string): FailedResult => ({
  status: 'failed',
  error: { kind, message },
});

/** The plugin as a fake: it stands for the download, gallery and share services the Flutter app had. */
const fakeMedia = () => ({
  saveToGallery: vi.fn<Media['saveToGallery']>(),
  share: vi.fn<Media['share']>(),
});

/** A save in flight: it hangs until released. */
function pendingSave() {
  let release: (result: SaveResult) => void = () => undefined;
  const promise = new Promise<SaveResult>((resolve) => {
    release = resolve;
  });
  return { promise, release };
}

let media: ReturnType<typeof fakeMedia>;
let repo: MediaSaveImpl;

beforeEach(() => {
  vi.stubGlobal('navigator', { userAgent: PAGE_USER_AGENT });
  media = fakeMedia();
  media.saveToGallery.mockResolvedValue(saved);
  media.share.mockResolvedValue(shared);
  repo = new MediaSaveImpl(media);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('MediaSaveImpl.saveImage', () => {
  it('downloads and saves through gallery service', async () => {
    const result = await repo.saveImage('https://x/a.jpg');

    expect(result).toStrictEqual({ ok: true });
    expect(media.saveToGallery).toHaveBeenCalledExactlyOnceWith({
      url: 'https://x/a.jpg',
      userAgent: PAGE_USER_AGENT,
    });
    expect(media.share).not.toHaveBeenCalled();
  });

  it('network failure maps to Left(network)', async () => {
    media.saveToGallery.mockResolvedValue(
      failed('network', 'The server answered 403 to https://x/a.jpg.')
    );

    const result = await repo.saveImage('https://x/a.jpg');

    expect(result).toStrictEqual({
      ok: false,
      failure: { type: 'network', detail: 'The server answered 403 to https://x/a.jpg.' },
    });
  });

  it('permission failure maps to Left(permission)', async () => {
    media.saveToGallery.mockResolvedValue(
      failed('permission', 'Saving needs android.permission.WRITE_EXTERNAL_STORAGE.')
    );

    const result = await repo.saveImage('https://x/a.jpg');

    expect(result).toStrictEqual({ ok: false, failure: { type: 'permission' } });
  });

  it('non-permission gallery failure maps to Left(unexpected)', async () => {
    media.saveToGallery.mockResolvedValue(
      failed('storage', 'The media store took no entry for Pictures.')
    );

    const result = await repo.saveImage('https://x/a.jpg');

    expect(result).toStrictEqual({
      ok: false,
      failure: { type: 'unexpected', detail: 'The media store took no entry for Pictures.' },
    });
  });

  it('unsupported failure maps to Left(unexpected) with what the plugin said', async () => {
    media.saveToGallery.mockResolvedValue(
      failed('unsupported', 'The server sent a web page for https://x/a.jpg, not a file.')
    );

    const result = await repo.saveImage('https://x/a.jpg');

    expect(result).toStrictEqual({
      ok: false,
      failure: {
        type: 'unexpected',
        detail: 'The server sent a web page for https://x/a.jpg, not a file.',
      },
    });
  });

  it('a fault of the bridge maps to Left(unexpected) with what was thrown', async () => {
    media.saveToGallery.mockRejectedValue(new Error('No native bridge found.'));

    const result = await repo.saveImage('https://x/a.jpg');

    expect(result).toStrictEqual({
      ok: false,
      failure: { type: 'unexpected', detail: 'No native bridge found.' },
    });
  });

  it("sends the page's own user agent with every download", async () => {
    await repo.saveImage('https://x/a.jpg');
    await repo.saveVideo('https://x/clip');
    await repo.share(imageTarget('https://x/b.jpg'));

    expect(media.saveToGallery.mock.calls.map(([request]) => request.userAgent)).toEqual([
      PAGE_USER_AGENT,
      PAGE_USER_AGENT,
    ]);
    expect(media.share).toHaveBeenCalledExactlyOnceWith({
      url: 'https://x/b.jpg',
      userAgent: PAGE_USER_AGENT,
    });
  });

  it('sends no user agent where there is no navigator', async () => {
    vi.stubGlobal('navigator', undefined);

    await repo.saveImage('https://x/a.jpg');

    expect(media.saveToGallery.mock.calls).toStrictEqual([[{ url: 'https://x/a.jpg' }]]);
  });
});

describe('MediaSaveImpl.saveVideo', () => {
  it('downloads with mp4 fallback and saves through gallery', async () => {
    // No fallback extension here: the plugin names the type from what the server says.
    const result = await repo.saveVideo('https://x/clip');

    expect(result).toStrictEqual({ ok: true });
    expect(media.saveToGallery).toHaveBeenCalledExactlyOnceWith({
      url: 'https://x/clip',
      userAgent: PAGE_USER_AGENT,
    });
  });
});

describe('MediaSaveImpl.cancel + dedupe', () => {
  it('cancel mid-download maps to Left(canceled)', async () => {
    // The web has no cancel of its own: one arrives as the plugin's answer.
    media.saveToGallery.mockResolvedValue(failed('canceled', 'The user backed out.'));

    const result = await repo.saveImage('https://x/a.jpg');

    expect(result).toStrictEqual({ ok: false, failure: { type: 'canceled' } });
  });

  it('second save for the same url while in flight gets inProgress', async () => {
    const download = pendingSave();
    media.saveToGallery.mockReturnValue(download.promise);

    const first = repo.saveImage('https://x/a.jpg');
    const second = await repo.saveImage('https://x/a.jpg');
    download.release(saved);
    const firstResult = await first;

    expect(firstResult).toStrictEqual({ ok: true });
    expect(second).toStrictEqual({ ok: false, failure: { type: 'inProgress' } });
    expect(media.saveToGallery).toHaveBeenCalledTimes(1);
  });

  it('in-flight entry is cleared after completion so retry works', async () => {
    const download = pendingSave();
    media.saveToGallery.mockReturnValue(download.promise);

    const first = repo.saveImage('https://x/a.jpg');
    download.release(saved);
    await first;
    const second = await repo.saveImage('https://x/a.jpg');

    expect(second).toStrictEqual({ ok: true });
    expect(media.saveToGallery).toHaveBeenCalledTimes(2);
  });
});

describe('MediaSaveImpl.share', () => {
  it('external target shares the url as text without downloading', async () => {
    const result = await repo.share(
      videoTarget({ type: 'video', url: 'https://youtu.be/abc12345678' })
    );

    expect(result).toStrictEqual({ ok: true });
    expect(media.share).toHaveBeenCalledExactlyOnceWith({ text: 'https://youtu.be/abc12345678' });
    expect(media.saveToGallery).not.toHaveBeenCalled();
  });

  it('image target downloads then shares the file', async () => {
    const result = await repo.share(imageTarget('https://x/a.jpg'));

    expect(result).toStrictEqual({ ok: true });
    expect(media.share).toHaveBeenCalledExactlyOnceWith({
      url: 'https://x/a.jpg',
      userAgent: PAGE_USER_AGENT,
    });
  });

  it('download failure falls back to sharing the url as text', async () => {
    media.share
      .mockResolvedValueOnce(failed('network', 'Could not download https://x/a.jpg.'))
      .mockResolvedValueOnce(shared);

    const result = await repo.share(imageTarget('https://x/a.jpg'));

    expect(result).toStrictEqual({ ok: true });
    expect(media.share.mock.calls).toStrictEqual([
      [{ url: 'https://x/a.jpg', userAgent: PAGE_USER_AGENT }],
      [{ text: 'https://x/a.jpg' }],
    ]);
  });

  it.each(['unsupported', 'storage'] as const)(
    'a failure of the file (%s) falls back to sharing the url as text',
    async (kind) => {
      media.share.mockResolvedValueOnce(failed(kind, 'Not a file.')).mockResolvedValueOnce(shared);

      const result = await repo.share(imageTarget('https://x/a.jpg'));

      expect(result).toStrictEqual({ ok: true });
      expect(media.share.mock.calls).toStrictEqual([
        [{ url: 'https://x/a.jpg', userAgent: PAGE_USER_AGENT }],
        [{ text: 'https://x/a.jpg' }],
      ]);
    }
  );

  it('user cancel does not fall back to a text share', async () => {
    media.share.mockResolvedValue(failed('canceled', 'The user backed out.'));

    const result = await repo.share(imageTarget('https://x/a.jpg'));

    expect(result).toStrictEqual({ ok: false, failure: { type: 'canceled' } });
    // Asked for the file once, and never for the address as a text.
    expect(media.share.mock.calls).toStrictEqual([
      [{ url: 'https://x/a.jpg', userAgent: PAGE_USER_AGENT }],
    ]);
    expect(media.saveToGallery).not.toHaveBeenCalled();
  });

  it('a failed text share of the fallback is the failure answered', async () => {
    media.share
      .mockResolvedValueOnce(failed('network', 'Could not download https://x/a.jpg.'))
      .mockResolvedValueOnce(failed('unsupported', 'No app on this device takes a text.'));

    const result = await repo.share(imageTarget('https://x/a.jpg'));

    expect(result).toStrictEqual({
      ok: false,
      failure: { type: 'unexpected', detail: 'No app on this device takes a text.' },
    });
  });
});
