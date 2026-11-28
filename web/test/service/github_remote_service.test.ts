import { describe, expect, it, vi } from 'vitest';
import { ParseFailure } from '../../src/model/failures';
import { GitHubRemoteService, LATEST_RELEASE_PATH } from '../../src/service/github_remote_service';

const releaseJson = (extra: Record<string, unknown> = {}) =>
  JSON.stringify({
    tag_name: 'v4.1.0',
    name: 'v4.1.0',
    html_url: 'https://github.com/dev-hann/keek-news/releases/tag/v4.1.0',
    prerelease: false,
    draft: false,
    assets: [
      {
        name: 'keek-news-v4.1.0.apk',
        browser_download_url:
          'https://github.com/dev-hann/keek-news/releases/download/v4.1.0/keek-news-v4.1.0.apk',
      },
      { name: 'notes.txt', browser_download_url: 'https://example.com/notes.txt' },
    ],
    ...extra,
  });

function client(answer: string) {
  return { get: vi.fn(async () => answer) };
}

describe('GitHubRemoteService', () => {
  it('asks the releases API for the latest release of the repository', async () => {
    const http = client(releaseJson());
    new GitHubRemoteService(http).getLatestRelease();
    expect(http.get).toHaveBeenCalledWith(LATEST_RELEASE_PATH);
    expect(LATEST_RELEASE_PATH).toBe('/repos/dev-hann/keek-news/releases/latest');
  });

  it('is the release: its tag, the version the tag names, its page and where its APK is', async () => {
    const release = await new GitHubRemoteService(client(releaseJson())).getLatestRelease();

    expect(release).toEqual({
      tag: 'v4.1.0',
      version: '4.1.0',
      pageUrl: 'https://github.com/dev-hann/keek-news/releases/tag/v4.1.0',
      apkUrl: 'https://github.com/dev-hann/keek-news/releases/download/v4.1.0/keek-news-v4.1.0.apk',
    });
  });

  it('takes the first asset whose name ends in .apk, and no other', async () => {
    const release = await new GitHubRemoteService(
      client(
        releaseJson({
          assets: [
            { name: 'keek-news-v4.1.0.apk.sha256', browser_download_url: 'https://e.com/a.sha256' },
            { name: 'Source.zip', browser_download_url: 'https://e.com/s.zip' },
            { name: 'keek-news.apk', browser_download_url: 'https://e.com/keek-news.apk' },
            { name: 'other.apk', browser_download_url: 'https://e.com/other.apk' },
          ],
        })
      )
    ).getLatestRelease();

    expect(release.apkUrl).toBe('https://e.com/keek-news.apk');
  });

  it('fails to read a release that is not one: no tag, no page, no APK, or not JSON', async () => {
    const notJson = client('<html>Sign in</html>');
    const noTag = client(releaseJson({ tag_name: undefined }));
    const tagIsNotAVersion = client(releaseJson({ tag_name: 'continuous' }));
    const noPage = client(releaseJson({ html_url: undefined }));
    const noApk = client(releaseJson({ assets: [] }));

    for (const http of [notJson, noTag, tagIsNotAVersion, noPage, noApk]) {
      await expect(new GitHubRemoteService(http).getLatestRelease()).rejects.toBeInstanceOf(
        ParseFailure
      );
    }
  });

  it('lets a failed request through as it came: the client says why', async () => {
    const failure = new Error('HTTP 403');
    const http = { get: vi.fn(async () => Promise.reject(failure)) };

    await expect(new GitHubRemoteService(http).getLatestRelease()).rejects.toBe(failure);
  });
});
