import type { AppRelease } from '../model/app_update';
import { ParseFailure } from '../model/failures';
import type { HtmlClient } from './html_client';
import { versionOfTag } from '../utils/app_version';

/** The newest release of the repository that is neither a draft nor a pre-release. */
export const LATEST_RELEASE_PATH = '/repos/dev-hann/keek-news/releases/latest';

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const text = (value: unknown): string | null => (typeof value === 'string' ? value : null);

/** The release in the answer of the API, or a ParseFailure when the answer is not one. */
function parseRelease(json: unknown): AppRelease {
  if (!isRecord(json)) throw new ParseFailure('GitHub가 릴리즈를 보내지 않았습니다');
  const tag = text(json.tag_name);
  const pageUrl = text(json.html_url);
  const version = tag === null ? null : versionOfTag(tag);
  if (tag === null || pageUrl === null || version === null) {
    throw new ParseFailure('릴리즈에 버전이 없습니다');
  }
  const assets = Array.isArray(json.assets) ? json.assets : [];
  const apkUrl = assets
    .filter(isRecord)
    .map((asset) => [text(asset.name), text(asset.browser_download_url)] as const)
    .find(([name]) => name !== null && name.endsWith('.apk'))?.[1];
  if (apkUrl === null || apkUrl === undefined) {
    throw new ParseFailure('릴리즈에 APK가 없습니다');
  }
  return { tag, version, pageUrl, apkUrl };
}

/** Reads the releases of the app on GitHub. The page cannot: the API answers another origin. */
export class GitHubRemoteService {
  private readonly client: Pick<HtmlClient, 'get'>;

  constructor(client: Pick<HtmlClient, 'get'>) {
    this.client = client;
  }

  async getLatestRelease(): Promise<AppRelease> {
    const body = await this.client.get(LATEST_RELEASE_PATH);
    let json: unknown;
    try {
      json = JSON.parse(body);
    } catch {
      throw new ParseFailure('GitHub가 릴리즈를 보내지 않았습니다');
    }
    return parseRelease(json);
  }
}
