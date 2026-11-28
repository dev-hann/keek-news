import type { VideoBlock } from './content_block';

export type MediaKind = 'image' | 'video' | 'external';

/**
 * One media item the reader long-pressed, resolved to what the action sheet
 * can offer for it. `external` is an embed hosted outside the community CDNs
 * (YouTube, Vimeo): it cannot be downloaded, only shared as an address.
 */
export interface MediaTarget {
  url: string;
  kind: MediaKind;
}

const EXTERNAL_EMBED_HOSTS = ['youtube.com', 'youtu.be', 'vimeo.com'];

function isExternalEmbed(url: string): boolean {
  let host: string;
  try {
    host = new URL(url).host.toLowerCase();
  } catch {
    return false;
  }
  // By host, not by the end of the name: "notyoutube.com" is not YouTube.
  return EXTERNAL_EMBED_HOSTS.some(
    (external) => host === external || host.endsWith(`.${external}`)
  );
}

export function imageTarget(url: string): MediaTarget {
  return { url, kind: 'image' };
}

export function videoTarget(block: VideoBlock): MediaTarget {
  return { url: block.url, kind: isExternalEmbed(block.url) ? 'external' : 'video' };
}

export function isDownloadable(target: MediaTarget): boolean {
  return target.kind !== 'external';
}
