// Pure DOM-to-ContentBlock scanning shared by every HTML service implementation; stateless functions, like the media classifier.
import type { ContentBlock, ImageBlock, VideoBlock } from '../model/content_block';
import type { ContentScanResult } from '../model/content_scan_result';
import { tryParseInt } from './html_service';
import { classify, extractYoutubeId, unwrapDownloadPhp } from './media_classifier';

export function scanContent(container: Element): ContentScanResult {
  const blocks: ContentBlock[] = [];
  const seenKeys = new Set<string>();
  const imageUrls: string[] = [];
  walkNodes(container.childNodes, blocks, seenKeys, imageUrls);
  return { blocks, imageUrls };
}

export function scanContentFull(doc: Document, contentEl: Element): ContentScanResult {
  const blocks: ContentBlock[] = [];
  const seenKeys = new Set<string>();
  const imageUrls: string[] = [];

  walkNodes(contentEl.childNodes, blocks, seenKeys, imageUrls);

  const commentScopes = [
    ...doc.querySelectorAll('#comment_best_wrap'),
    ...doc.querySelectorAll('li[id^="comment_li_"]'),
  ];

  const allDownloadLinks = doc.querySelectorAll('a[href*="download.php?url="]');
  for (const link of allDownloadLinks) {
    if (contentEl.contains(link) || withinAny(commentScopes, link)) continue;

    const href = link.getAttribute('href') ?? '';
    const innerUrl = href.match(downloadPhpUrlPattern)?.[1];
    if (innerUrl === undefined) continue;

    const rawUrl = normalizeUrl(innerUrl);
    if (!markSeen(seenKeys, rawUrl)) continue;

    const mediaType = classify(rawUrl);
    const thumbImg = link.querySelector('img');
    const thumbSrc = thumbImg?.getAttribute('src') ?? '';
    const thumb = thumbSrc !== '' ? normalizeUrl(thumbSrc) : null;

    switch (mediaType) {
      case 'image':
        if (isSessionThumbUrl(rawUrl)) break;
        blocks.push(imageBlock(rawUrl, usableThumb(thumb)));
        imageUrls.push(rawUrl);
        break;
      case 'video':
        blocks.push(videoBlock(rawUrl, usableThumb(thumb)));
        break;
      default:
        break;
    }
  }

  const mp4Divs = doc.querySelectorAll('[onclick*="comment_mp4_expand"]');
  for (const div of mp4Divs) {
    if (contentEl.contains(div) || withinAny(commentScopes, div)) continue;
    const onclick = div.getAttribute('onclick') ?? '';
    const url = onclick.match(commentMp4ExpandPattern)?.[1];
    if (url === undefined) continue;

    const normalized = normalizeUrl(url);
    if (markSeen(seenKeys, normalized)) blocks.push(videoBlock(normalized, null));
  }

  return { blocks, imageUrls };
}

export function scanContentCompact(container: Element): ContentBlock[] {
  const urls: UrlEntry[] = [];
  collectUrlsRecursive(container, urls);

  const blocks: ContentBlock[] = [];
  const seenKeys = new Set<string>();

  for (const entry of urls) {
    const rawUrl = normalizeUrl(entry.url);
    if (!markSeen(seenKeys, rawUrl)) continue;

    const unwrapped = unwrapDownloadPhp(rawUrl) ?? rawUrl;
    const normalized = normalizeUrl(unwrapped);
    const mediaType = classify(normalized);
    const thumb = entry.thumbUrl !== null ? normalizeUrl(entry.thumbUrl) : null;

    switch (mediaType) {
      case 'image':
        if (isSessionThumbUrl(normalized)) break;
        blocks.push(imageBlock(normalized, thumb));
        break;
      case 'video':
        blocks.push(videoBlock(normalized, usableThumb(thumb)));
        break;
      case 'youtube':
        blocks.push(youtubeBlock(normalized));
        break;
      default:
        break;
    }
  }

  return blocks;
}

const downloadPhpUrlPattern = /download\.php\?url=(https?:\/\/[^&]+)/;
const commentMp4ExpandPattern = /comment_mp4_expand\('[^']*',\s*'([^']+)'/;

/** A URL pulled from the markup, with the thumbnail and link text found beside it when there are any. */
interface UrlEntry {
  url: string;
  thumbUrl: string | null;
  text: string | null;
}

function markSeen(seenKeys: Set<string>, url: string): boolean {
  const key = dedupKey(url);
  if (seenKeys.has(key)) return false;
  seenKeys.add(key);
  return true;
}

/** A block without a thumbnail has no `thumbnailUrl` property at all rather than one holding undefined. */
const imageBlock = (url: string, thumbnailUrl: string | null): ImageBlock => ({
  type: 'image',
  url,
  ...(thumbnailUrl === null ? {} : { thumbnailUrl }),
});

const videoBlock = (url: string, thumbnailUrl: string | null): VideoBlock => ({
  type: 'video',
  url,
  ...(thumbnailUrl === null ? {} : { thumbnailUrl }),
});

/** The video block a YouTube link becomes: the watch page and the poster YouTube serves for every video. */
function youtubeBlock(url: string): VideoBlock {
  const id = extractYoutubeId(url)!;
  return {
    type: 'video',
    url: `https://www.youtube.com/watch?v=${id}`,
    thumbnailUrl: `https://img.youtube.com/vi/${id}/hqdefault.jpg`,
  };
}

/** Cookie-gated humoruniv markup re-ships comment GIFs as `comment_mp4_expand` divs inside comment items. Those belong to the comment's own media blocks, not the post-body carousel the doc-wide fallback loops feed, so both loops skip anything inside a comment scope. */
function withinAny(scopes: Element[], el: Element): boolean {
  return scopes.some((scope) => scope.contains(el));
}

/** humoruniv session-token thumbs (`thumb.php?url_enc=…`) expire with the page session; keeping them yields broken image slots and dead video posters after the token lapses. `isLoadableImage` already rejects them for list collection — this extends the same rule to content scanning so callers fall back to synthesized/static posters. */
function isSessionThumbUrl(url: string): boolean {
  return url.includes('url_enc=');
}

const usableThumb = (thumb: string | null): string | null =>
  thumb !== null && isSessionThumbUrl(thumb) ? null : thumb;

function normalizeUrl(url: string): string {
  if (url === '') return url;
  let normalized = url.trim();
  if (normalized.startsWith('//')) normalized = `https:${normalized}`;
  while (normalized.includes(':///')) normalized = normalized.replace(':///', '://');
  return normalized.replace(/(?<!:)\/{2,}/g, '/');
}

function walkNodes(
  nodes: NodeListOf<ChildNode>,
  blocks: ContentBlock[],
  seenKeys: Set<string>,
  imageUrls: string[]
): void {
  for (const node of nodes) {
    if (node.nodeType === Node.TEXT_NODE) {
      const text = (node.textContent ?? '').trim();
      if (text !== '') blocks.push({ type: 'text', text });
    } else if (node.nodeType === Node.ELEMENT_NODE) {
      scanElement(node as Element, blocks, seenKeys, imageUrls);
    }
  }
}

function scanElement(
  el: Element,
  blocks: ContentBlock[],
  seenKeys: Set<string>,
  imageUrls: string[]
): void {
  if (isNoiseElement(el)) return;

  const extracted = extractUrlsFromElement(el);
  if (extracted.length > 0) {
    for (const entry of extracted) {
      const rawUrl = normalizeUrl(entry.url);
      if (!markSeen(seenKeys, rawUrl)) continue;

      const unwrapped = unwrapDownloadPhp(rawUrl) ?? rawUrl;
      const normalized = normalizeUrl(unwrapped);
      const mediaType = classify(normalized);
      const thumb = entry.thumbUrl !== null ? normalizeUrl(entry.thumbUrl) : null;

      switch (mediaType) {
        case 'image': {
          if (isSessionThumbUrl(normalized)) break;
          blocks.push(imageBlock(normalized, thumb));
          imageUrls.push(normalized);
          break;
        }
        case 'video':
          blocks.push(videoBlock(normalized, usableThumb(thumb)));
          break;
        case 'audio':
          blocks.push({ type: 'html', html: `<a href="${normalized}">${normalized}</a>` });
          break;
        case 'youtube':
          blocks.push(youtubeBlock(normalized));
          break;
        case 'link': {
          const linkText = entry.text ?? normalized;
          blocks.push({
            type: 'html',
            html: `<a href="${normalized}" target="_blank">${linkText}</a>`,
          });
          break;
        }
        case 'unknown':
          break;
      }
    }
    walkNodes(el.childNodes, blocks, seenKeys, imageUrls);
    return;
  }

  const videoEl = el.localName === 'video' ? el : el.querySelector('video');
  if (videoEl !== null) {
    const block = parseVideoElement(videoEl);
    if (block !== null) {
      const normalized = normalizeUrl(block.url);
      if (markSeen(seenKeys, normalized)) blocks.push(block);
    }
    return;
  }

  if (el.childNodes.length === 0 || (isSimpleTextElement(el) && !hasMediaOrNoiseDescendant(el))) {
    const text = (el.textContent ?? '').trim();
    if (text !== '') blocks.push({ type: 'text', text });
    return;
  }

  if (isRichMixedContent(el) && !hasHighLinkDensity(el)) {
    const innerHtml = el.innerHTML.trim();
    if (innerHtml !== '') blocks.push({ type: 'html', html: innerHtml });
    return;
  }

  walkNodes(el.childNodes, blocks, seenKeys, imageUrls);
}

/** True when anchor text dominates the element's text — a strong signal of navigation/ad chrome rather than real mixed content. Blocks above the threshold fall through to child walking instead of a monolithic HtmlBlock, so genuine text inside still gets extracted. */
function hasHighLinkDensity(el: Element): boolean {
  const total = (el.textContent ?? '').trim().length;
  if (total === 0) return false;
  let linkText = 0;
  for (const a of el.querySelectorAll('a')) {
    linkText += (a.textContent ?? '').trim().length;
  }
  return linkText / total > 0.5;
}

/** Spacer/tracking images: explicit 0-1px dimensions or well-known placeholder file names. Verified against fixtures (e.g. ppomppu's `skin/.../t.gif width="8" height="1px"`). */
export function isNoiseImage(img: Element): boolean {
  const dimensionPattern = /^\d+/;
  for (const attr of ['width', 'height'] as const) {
    const raw = img.getAttribute(attr);
    if (raw === null) continue;
    const digits = dimensionPattern.exec(raw.trim());
    if (digits !== null && Number(digits[0]) <= 1) return true;
  }
  const src = (img.getAttribute('src') ?? '').toLowerCase();
  return src.includes('spacer') || src.includes('/blank.') || src.includes('1x1');
}

/** First usable image URL, preferring higher-quality override attributes over `src` (lazy-load placeholders live in `src` on some boards). */
export function effectiveImageUrl(img: Element): string {
  for (const attr of ['img_file_url', 'data-original', 'data-src', 'data-lazy-src']) {
    const value = img.getAttribute(attr) ?? '';
    if (value !== '' && !value.includes('/images/')) return value;
  }
  return img.getAttribute('src') ?? '';
}

function extractUrlsFromElement(el: Element): UrlEntry[] {
  const entries: UrlEntry[] = [];

  if (el.localName === 'img') {
    if (!isNoiseImage(el)) {
      const src = el.getAttribute('src') ?? '';
      const url = effectiveImageUrl(el);
      if (url !== '' && !url.includes('/images/')) {
        entries.push({ url, thumbUrl: src !== url ? src : null, text: null });
      }
    }
    return entries;
  }

  if (el.localName === 'a') {
    const href = el.getAttribute('href') ?? '';
    if (href.includes('download.php?url=')) {
      const innerUrl = href.match(downloadPhpUrlPattern)?.[1];
      if (innerUrl !== undefined) {
        const thumbImg = el.querySelector('img');
        entries.push({
          url: innerUrl,
          thumbUrl: thumbImg?.getAttribute('src') ?? null,
          text: null,
        });
      }
      return entries;
    }
    if (href.startsWith('http')) {
      const text = (el.textContent ?? '').trim();
      if (text === '' || href === text) {
        entries.push({ url: href, thumbUrl: null, text: null });
      } else {
        entries.push({ url: href, thumbUrl: null, text });
      }
    }
    return entries;
  }

  for (const img of el.querySelectorAll('img')) {
    if (isNoiseImage(img)) continue;
    const src = img.getAttribute('src') ?? '';
    const url = effectiveImageUrl(img);
    if (url === '' || url.includes('/images/')) continue;
    entries.push({ url, thumbUrl: src !== url ? src : null, text: null });
  }

  for (const link of el.querySelectorAll('a[href*="download.php?url="]')) {
    const href = link.getAttribute('href') ?? '';
    const innerUrl = href.match(downloadPhpUrlPattern)?.[1];
    if (innerUrl !== undefined) {
      const thumbImg = link.querySelector('img');
      entries.push({ url: innerUrl, thumbUrl: thumbImg?.getAttribute('src') ?? null, text: null });
    }
  }

  const onclick = el.getAttribute('onclick') ?? '';
  if (onclick.includes('comment_mp4_expand')) {
    const url = onclick.match(commentMp4ExpandPattern)?.[1];
    if (url !== undefined) entries.push({ url, thumbUrl: null, text: null });
  }

  for (const anchor of el.querySelectorAll('a.autolink, span.autolink a')) {
    const href = anchor.getAttribute('href') ?? '';
    if (href.startsWith('http')) {
      const text = (anchor.textContent ?? '').trim();
      entries.push({ url: href, thumbUrl: null, text: text !== '' ? text : null });
    }
  }

  return entries;
}

function collectUrlsRecursive(el: Element, urls: UrlEntry[]): void {
  const mp4Entry = commentMp4Entry(el);
  if (mp4Entry !== null) {
    urls.push(mp4Entry);
    return;
  }

  urls.push(...extractDirectUrls(el));

  for (const child of Array.from(el.children)) collectUrlsRecursive(child, urls);
}

function commentMp4Entry(el: Element): UrlEntry | null {
  const onclick = el.getAttribute('onclick') ?? '';
  if (!onclick.includes('comment_mp4_expand')) return null;
  const url = onclick.match(commentMp4ExpandPattern)?.[1];
  if (url === undefined) return null;

  let thumb: string | null = null;
  const thumbImg = el.querySelector('img.comment_thumb_img');
  if (thumbImg !== null) {
    thumb = thumbImg.getAttribute('src');
  } else {
    for (const img of el.querySelectorAll('img')) {
      const src = img.getAttribute('src') ?? '';
      if (src !== '' && !src.includes('/images/')) {
        thumb = src;
        break;
      }
    }
  }
  if (thumb !== null && thumb.includes('url_enc=')) thumb = null;
  return {
    url,
    thumbUrl: thumb !== null && thumb !== '' ? thumb : null,
    text: null,
  };
}

/** Direct (self-level) URL extraction only — no descendant queries. Equivalent to `extractUrlsFromElement` restricted to img/a elements. */
function extractDirectUrls(el: Element): UrlEntry[] {
  const name = el.localName;
  if (name !== 'img' && name !== 'a') return [];
  return extractUrlsFromElement(el);
}

function parseVideoElement(video: Element): VideoBlock | null {
  const source = video.querySelector('source');
  const src = source?.getAttribute('src') ?? video.getAttribute('src') ?? '';
  if (src === '' || src.startsWith("'") || src.includes('"+')) return null;

  const poster = video.getAttribute('poster') ?? '';
  const width = tryParseInt(video.getAttribute('width'));
  const height = tryParseInt(video.getAttribute('height'));

  return {
    ...videoBlock(normalizeUrl(src), poster !== '' ? normalizeUrl(poster) : null),
    ...(width === null ? {} : { width }),
    ...(height === null ? {} : { height }),
  };
}

function isNoiseElement(el: Element): boolean {
  return (
    el.classList.contains('comment_thumb_notice') ||
    el.classList.contains('comment_crop_href') ||
    el.classList.contains('comment_crop_href_mp4') ||
    el.localName === 'iframe'
  );
}

function isSimpleTextElement(el: Element): boolean {
  const name = el.localName;
  return (
    name === 'p' ||
    name === 'span' ||
    name === 'br' ||
    name === 'a' ||
    name === 'b' ||
    name === 'font' ||
    name === 'strong' ||
    name === 'em'
  );
}

function hasMediaOrNoiseDescendant(el: Element): boolean {
  return (
    el.querySelector(
      'img, video, iframe, .comment_thumb_notice, .comment_crop_href, .comment_crop_href_mp4'
    ) !== null
  );
}

function isRichMixedContent(el: Element): boolean {
  const hasFormatting = el.querySelector('b, font, strong, em, span[style], table') !== null;
  const hasLinks = el.querySelector('a') !== null;
  return hasFormatting && hasLinks;
}

/** The URL's path, lower-cased. Split off by hand, as `Uri.parse` did it for the Flutter app: a relative reference (`thumb.php?url=…`) keeps its path without a leading slash and `https://host` has no path at all, while a browser URL object turns both into `/…` and `/` and so merges what the app kept apart. */
function dedupKey(url: string): string {
  const path = url
    .replace(/^(?:[a-z][a-z0-9+.-]*:)?\/\/[^/?#]*|^[a-z][a-z0-9+.-]*:/i, '')
    .replace(/[?#][\s\S]*$/, '');
  return path.replace(/\/+/g, '/').toLowerCase();
}
