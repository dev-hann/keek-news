/**
 * An image the user blocked from the long-press media action sheet.
 *
 * Identity is the canonical URL the parsers produce (post-rewrite) plus, when
 * available, a 64-bit dHash fingerprint that survives reposts under new URLs.
 * URL matching is exact; fingerprint matching allows a small Hamming
 * distance.
 */
export interface BlockedImage {
  url: string;
  blockedAt: Date;
  /** 16-char hex dHash, or absent when the bytes were unavailable at block time (entry then matches by URL only). */
  hash?: string;
}

/**
 * A blocked image as stored: one entry of the JSON list under `blocked_images`,
 * in the shape the Flutter app wrote. A type rather than an interface so that
 * it stands for a record, which reading it back needs.
 */
export type BlockedImageJson = {
  url: string;
  blockedAtMillis: number;
  hash?: string;
};

/** Whole milliseconds since the epoch: Dart's DateTime and the web's Date stop at the same ±100,000,000 days. */
const isMillis = (value: unknown): value is number =>
  typeof value === 'number' && Number.isInteger(value) && Math.abs(value) <= 8.64e15;

function malformed(json: unknown): never {
  throw new TypeError(`Not a blocked image: ${JSON.stringify(json)}`);
}

/**
 * Reads a stored entry. Throws on a malformed one, as the field casts in Dart
 * do, so that a reader can skip it and keep the rest of the list.
 */
export function blockedImageFromJson(json: Record<string, unknown>): BlockedImage {
  const { url, blockedAtMillis, hash } = json;
  if (typeof url !== 'string' || !isMillis(blockedAtMillis)) malformed(json);
  // Dart read the hash with `as String?`: a missing or a null one is no hash.
  if (hash != null && typeof hash !== 'string') malformed(json);
  return { url, blockedAt: new Date(blockedAtMillis), ...(hash != null ? { hash } : {}) };
}

export function blockedImageToJson(image: BlockedImage): BlockedImageJson {
  const { url, blockedAt, hash } = image;
  return { url, blockedAtMillis: blockedAt.getTime(), ...(hash != null ? { hash } : {}) };
}
