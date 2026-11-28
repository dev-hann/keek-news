import type { Media, SaveRequest, SaveResult, ShareResult } from '@gyo-community/media';
import type { MediaSaveResult } from '../../model/media_save_failure';
import { isDownloadable, type MediaTarget } from '../../model/media_target';
import type { MediaSaveRepo } from './media_save_repo';

/** The part of the media plugin a save or a share needs. Tests pass a fake. */
type MediaClient = Pick<Media, 'saveToGallery' | 'share'>;

const toMessage = (error: unknown) => (error instanceof Error ? error.message : String(error));

/**
 * What asks the plugin for the file at `url`. The user agent is the page's
 * own: sites block unknown clients, the community CDNs among them. Where
 * there is none the plugin falls back to its own.
 */
function downloadRequest(url: string): SaveRequest {
  const userAgent = typeof navigator === 'undefined' ? undefined : navigator.userAgent;
  return { url, ...(userAgent !== undefined ? { userAgent } : {}) };
}

/**
 * The plugin's answer as the result of the repo. A failure comes back from it
 * as a value that names its kind; the kinds the app has no type for are
 * unexpected, and keep what the plugin said about them.
 */
function toResult(result: SaveResult | ShareResult): MediaSaveResult {
  if (result.status !== 'failed') return { ok: true };
  const { kind, message } = result.error;
  switch (kind) {
    case 'network':
      return { ok: false, failure: { type: 'network', detail: message } };
    case 'permission':
      return { ok: false, failure: { type: 'permission' } };
    case 'canceled':
      return { ok: false, failure: { type: 'canceled' } };
    case 'unsupported':
    case 'storage':
      return { ok: false, failure: { type: 'unexpected', detail: message } };
  }
}

export class MediaSaveImpl implements MediaSaveRepo {
  private readonly media: MediaClient;
  private readonly inFlight = new Map<string, Promise<MediaSaveResult>>();

  constructor(media: MediaClient) {
    this.media = media;
  }

  saveImage(url: string): Promise<MediaSaveResult> {
    return this.guarded(url, async () =>
      toResult(await this.media.saveToGallery(downloadRequest(url)))
    );
  }

  saveVideo(url: string): Promise<MediaSaveResult> {
    return this.guarded(url, async () =>
      toResult(await this.media.saveToGallery(downloadRequest(url)))
    );
  }

  share(target: MediaTarget): Promise<MediaSaveResult> {
    if (!isDownloadable(target)) {
      return this.guard(async () => toResult(await this.media.share({ text: target.url })));
    }
    return this.guarded(target.url, async () => {
      const offered = await this.media.share(downloadRequest(target.url));
      if (offered.status === 'failed' && offered.error.kind !== 'canceled') {
        // Download failed (e.g. hotlink protection): sharing the URL is
        // better than a dead-end, so degrade to a text share.
        return toResult(await this.media.share({ text: target.url }));
      }
      return toResult(offered);
    });
  }

  /**
   * Runs `action` keyed by `url` so the same media is never downloaded
   * twice concurrently; a second caller gets an inProgress failure.
   */
  private async guarded(
    url: string,
    action: () => Promise<MediaSaveResult>
  ): Promise<MediaSaveResult> {
    if (this.inFlight.has(url)) {
      return { ok: false, failure: { type: 'inProgress' } };
    }
    const future = this.guard(action);
    this.inFlight.set(url, future);
    try {
      return await future;
    } finally {
      this.inFlight.delete(url);
    }
  }

  /**
   * A failure of the request is a value; only a fault of the bridge itself
   * rejects (no native side, a timeout), and that is unexpected.
   */
  private async guard(action: () => Promise<MediaSaveResult>): Promise<MediaSaveResult> {
    try {
      return await action();
    } catch (error) {
      return { ok: false, failure: { type: 'unexpected', detail: toMessage(error) } };
    }
  }
}
