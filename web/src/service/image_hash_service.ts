import { base64ToBytes, type Http } from '@gyo-community/http';

/** The part of the HTTP relay an image fetch needs. Tests pass a fake. */
type Relay = Pick<Http, 'request'>;

/**
 * Computes 64-bit dHash (difference hash) fingerprints for image URLs.
 *
 * The fingerprint survives re-encoding, format conversion (jpg ↔ webp) and
 * rescaling, so the same picture reposted under a new URL still matches.
 */
export interface ImageHashService {
  /**
   * Returns the 16-char hex fingerprint for `url`, or null when the bytes
   * cannot be fetched or decoded. Results are memoized per URL.
   */
  hashFor(url: string): Promise<string | null>;
}

/** RGBA pixels, as a canvas or a buffer hands them over. */
type Pixels = Uint8ClampedArray | Uint8Array;

/** The picture is read at this size: a pixel next to its right neighbour, 8 per row, gives the 64 bits. */
const targetWidth = 9;
const targetHeight = 8;

/**
 * The 64 bits Dart's `int.tryParse(hex, radix: 16)` reads: a sign and hex
 * digits that fit its signed int, whitespace around ignored. Null for
 * anything else.
 */
function parseHex(hex: string): bigint | null {
  const match = /^([+-]?)([0-9a-f]+)$/i.exec(hex.trim());
  if (match === null) return null;
  const negative = match[1] === '-';
  const magnitude = BigInt(`0x${match[2]}`);
  // A positive int stops one below 2^63; the size of a negative one reaches it.
  if (magnitude > (negative ? 1n << 63n : (1n << 63n) - 1n)) return null;
  return negative ? (1n << 64n) - magnitude : magnitude;
}

function setBits(value: bigint): number {
  let rest = value;
  let count = 0;
  while (rest !== 0n) {
    rest &= rest - 1n;
    count++;
  }
  return count;
}

function luma(pixels: Pixels, x: number, y: number): number {
  const i = (y * targetWidth + x) * 4;
  // Flutter reads premultiplied channels and getImageData straight ones, so the alpha goes back in.
  const alpha = pixels[i + 3] / 255;
  const r = Math.round(pixels[i] * alpha);
  const g = Math.round(pixels[i + 1] * alpha);
  const b = Math.round(pixels[i + 2] * alpha);
  return Math.round(0.299 * r + 0.587 * g + 0.114 * b);
}

export class FlutterImageHashService implements ImageHashService {
  private static readonly maxMemoized = 1024;
  private static readonly memo = new Map<string, string | null>();

  private readonly relay: Relay;

  constructor(relay: Relay) {
    this.relay = relay;
  }

  async hashFor(url: string): Promise<string | null> {
    const { memo } = FlutterImageHashService;
    if (memo.has(url)) return memo.get(url) ?? null;
    const hash = await hashForUrl(this.relay, url);
    if (memo.size >= FlutterImageHashService.maxMemoized) memo.clear();
    memo.set(url, hash);
    return hash;
  }

  /** Hamming distance between two hex fingerprints; 64 when unparseable. */
  static distance(a: string, b: string): number {
    const x = parseHex(a);
    const y = parseHex(b);
    if (x === null || y === null) return 64;
    return setBits(x ^ y);
  }

  /** Fingerprints within this Hamming distance count as the same picture. */
  static readonly matchDistance = 6;

  /**
   * Hashes with fewer set bits describe nearly featureless pictures whose
   * gradients are dominated by letterboxing or compression noise; they
   * collide too easily for cross-URL matching, so `matches` rejects them.
   */
  static readonly minReliableBits = 8;

  /** Whether two fingerprints describe the same picture: dense hashes within `matchDistance` bits. Unparseable or too-flat fingerprints never match. */
  static matches(a: string, b: string): boolean {
    if (
      FlutterImageHashService.popCount(a) < FlutterImageHashService.minReliableBits ||
      FlutterImageHashService.popCount(b) < FlutterImageHashService.minReliableBits
    ) {
      return false;
    }
    return FlutterImageHashService.distance(a, b) <= FlutterImageHashService.matchDistance;
  }

  /** Number of set bits in a hex fingerprint; 0 when unparseable. */
  static popCount(hex: string): number {
    const value = parseHex(hex);
    if (value === null) return 0;
    return setBits(value);
  }

  /**
   * Packs the horizontal gradient of 9×8 RGBA pixels into a 64-bit dHash.
   * Null for pixels that do not hold a 9×8 picture.
   */
  static dHashFromPixels(pixels: Pixels): string | null {
    if (pixels.length < targetWidth * targetHeight * 4) return null;

    let hash = 0n;
    for (let y = 0; y < targetHeight; y++) {
      for (let x = 0; x < targetWidth - 1; x++) {
        if (luma(pixels, x, y) > luma(pixels, x + 1, y)) {
          hash |= 1n << BigInt(y * (targetWidth - 1) + x);
        }
      }
    }
    // Dart's int is signed: a hash with its top bit set prints as a minus and
    // its size. The Flutter app stored it so, so the same picture keeps the same fingerprint here.
    return BigInt.asIntN(64, hash).toString(16).padStart(16, '0');
  }

  /** Decodes `bytes` to 9×8 grayscale and packs the horizontal gradient into a 64-bit dHash. Returns null for undecodable input. */
  static async dHashFromBytes(bytes: Uint8Array): Promise<string | null> {
    const pixels = await decodeToPixels(bytes);
    return pixels === null ? null : FlutterImageHashService.dHashFromPixels(pixels);
  }
}

/** Whether the first bytes of `bytes` spell `signature`, read as text. */
const hasSignature = (bytes: Uint8Array, signature: string): boolean =>
  [...signature].every((char, i) => char.charCodeAt(0) === bytes[i]);

/** The fraction of its size libjpeg decodes a JPEG at for `scale`: of its eighths, the first from the top that `scale` reaches. */
function jpegFraction(scale: number): number {
  for (let eighths = 8; eighths > 1; eighths--) {
    if (scale >= (2 * eighths - 1) / 16) return eighths / 8;
  }
  return 1 / 8;
}

/**
 * What the picture is reduced to before the last linear scale, as Flutter's
 * `instantiateImageCodec(targetWidth: 9, targetHeight: 8)` gets it from the
 * codec: a JPEG decoded by libjpeg at eighths of its size, a WebP by libwebp
 * and a GIF by a sampled read, each at the size the target asks of the larger
 * ratio. A PNG is decoded whole, so it comes back as it is.
 */
function decodedByCodec(bitmap: ImageBitmap, bytes: Uint8Array): CanvasImageSource {
  const scale = Math.max(targetWidth / bitmap.width, targetHeight / bitmap.height);
  const jpeg = hasSignature(bytes, '\xff\xd8\xff');
  const gif = hasSignature(bytes, 'GIF8');
  const webp = hasSignature(bytes, 'RIFF') && hasSignature(bytes.subarray(8), 'WEBP');
  if (!jpeg && !gif && !webp) return bitmap;

  // No codec decodes a picture up.
  const fraction = jpeg ? jpegFraction(scale) : Math.min(scale, 1);
  if (fraction === 1) return bitmap;

  const decoded = document.createElement('canvas');
  const size = (pixels: number): number =>
    Math.max(1, jpeg ? Math.floor(pixels * fraction) : Math.round(pixels * fraction));
  decoded.width = size(bitmap.width);
  decoded.height = size(bitmap.height);
  const context = decoded.getContext('2d');
  if (context === null) return bitmap;
  // A codec's own reduced read averages a block of pixels; the sampled one takes single pixels.
  if (gif) context.imageSmoothingEnabled = false;
  else context.imageSmoothingQuality = 'high';
  context.drawImage(bitmap, 0, 0, decoded.width, decoded.height);
  return decoded;
}

/**
 * The 9×8 RGBA pixels the browser decodes `bytes` to, reduced the way Flutter
 * reduces to `targetWidth`/`targetHeight`: what the format's codec decodes
 * at, then a linear scale, which is a canvas's own. Null when the browser
 * cannot decode them.
 *
 * jsdom has neither a decoder nor a canvas, so the tests stub the browser to
 * check the steps; what a real browser makes of the pixels is not under test.
 */
export async function decodeToPixels(bytes: Uint8Array): Promise<Uint8ClampedArray | null> {
  try {
    // Typed arrays over any buffer decode fine; only the lib.dom types insist on an ArrayBuffer.
    const blob = new Blob([bytes as Uint8Array<ArrayBuffer>]);
    const bitmap = await createImageBitmap(blob);
    try {
      const canvas = document.createElement('canvas');
      canvas.width = targetWidth;
      canvas.height = targetHeight;
      const context = canvas.getContext('2d');
      if (context === null) return null;
      context.drawImage(decodedByCodec(bitmap, bytes), 0, 0, targetWidth, targetHeight);
      return context.getImageData(0, 0, targetWidth, targetHeight).data;
    } finally {
      bitmap.close();
    }
  } catch {
    return null;
  }
}

async function hashForUrl(relay: Relay, url: string): Promise<string | null> {
  try {
    const response = await relay.request({ url });
    // The Flutter fetch (flutter_cache_manager) keeps a 200 or a 202 only; the relay answers with any status.
    if (response.status !== 200 && response.status !== 202) return null;
    return await FlutterImageHashService.dHashFromBytes(base64ToBytes(response.bodyBase64));
  } catch {
    return null;
  }
}
