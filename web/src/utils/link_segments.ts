/** A stretch of text: plain, or a URL the reader can open. */
export interface LinkSegment {
  text: string;
  /** Where the stretch leads when it is a link; undefined for plain text. */
  url?: string;
}

const URL_PATTERN = /(?:(?:https?):\/\/|www\.)[^\s<>"']+/gi;
const CLOSING_PUNCTUATION = '.,;:!?)]}\'"';

/**
 * Splits text into plain stretches and URLs. Matches addresses that start
 * with `http(s)://` or `www.`. Punctuation at the end stays outside the link,
 * so a URL that ends a sentence still reads naturally.
 */
export function parseLinkSegments(text: string): LinkSegment[] {
  if (text.length === 0) return [];
  const segments: LinkSegment[] = [];
  let last = 0;

  for (const match of text.matchAll(URL_PATTERN)) {
    const start = match.index;
    let raw = match[0];
    let end = start + raw.length;
    while (end > start && CLOSING_PUNCTUATION.includes(raw[raw.length - 1])) {
      raw = raw.slice(0, -1);
      end--;
    }
    if (raw.length === 0) continue;
    if (start > last) segments.push({ text: text.slice(last, start) });
    segments.push(
      /^https?:\/\//i.test(raw) ? { text: raw, url: raw } : { text: raw, url: `https://${raw}` }
    );
    last = end;
  }
  if (last < text.length) segments.push({ text: text.slice(last) });
  return segments;
}
