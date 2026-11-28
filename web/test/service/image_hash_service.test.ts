import type { HttpResponse } from '@gyo-community/http';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { decodeToPixels, FlutterImageHashService } from '../../src/service/image_hash_service';

/**
 * Renders a horizontal gradient into RGBA pixels at [width]×[height], where
 * the Dart test rendered it into PNG bytes.
 */
function _gradientPixels(width: number, height: number, inverted = false): Uint8ClampedArray {
  const pixels = new Uint8ClampedArray(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      // The gradient runs from (0, 0) to (width, 0); a pixel takes the colour at its centre.
      const shade = Math.round((255 * (x + 0.5)) / width);
      const value = inverted ? 255 - shade : shade;
      pixels.set([value, value, value, 255], (y * width + x) * 4);
    }
  }
  return pixels;
}

/**
 * What a decoder's downscale to 9×8 makes of [pixels]: every pixel of the
 * result is the mean of its share of the picture.
 */
function _reducedTo9x8(
  pixels: Uint8ClampedArray,
  width: number,
  height: number
): Uint8ClampedArray {
  const result = new Uint8ClampedArray(9 * 8 * 4);
  for (let y = 0; y < 8; y++) {
    const top = Math.floor((y * height) / 8);
    const bottom = Math.floor(((y + 1) * height) / 8);
    for (let x = 0; x < 9; x++) {
      const left = Math.floor((x * width) / 9);
      const right = Math.floor(((x + 1) * width) / 9);
      const sum = [0, 0, 0, 0];
      for (let sy = top; sy < bottom; sy++) {
        for (let sx = left; sx < right; sx++) {
          const i = (sy * width + sx) * 4;
          for (let c = 0; c < 4; c++) sum[c] += pixels[i + c];
        }
      }
      const count = (bottom - top) * (right - left);
      result.set(
        sum.map((total) => Math.round(total / count)),
        (y * 9 + x) * 4
      );
    }
  }
  return result;
}

describe('FlutterImageHashService.distance', () => {
  it('identical fingerprints have distance 0', () => {
    expect(FlutterImageHashService.distance('0000000000000000', '0000000000000000')).toBe(0);
  });

  it('counts differing bits', () => {
    // 0x3f flips the low 6 bits.
    expect(FlutterImageHashService.distance('0000000000000000', '3f')).toBe(6);
  });

  it('unparseable fingerprints never match', () => {
    expect(FlutterImageHashService.distance('zzz', '0000000000000000')).toBe(64);
  });
});

describe('FlutterImageHashService.popCount', () => {
  it('counts set bits', () => {
    expect(FlutterImageHashService.popCount('0000000000000000')).toBe(0);
    expect(FlutterImageHashService.popCount('7e7e7e7e7e7e7e7e')).toBe(48);
    expect(FlutterImageHashService.popCount('7e7e7e7e7e7e7e7a')).toBe(47);
  });

  it('returns 0 for unparseable input', () => {
    expect(FlutterImageHashService.popCount('zzz')).toBe(0);
  });
});

describe('FlutterImageHashService.matches', () => {
  it('dense fingerprints within the threshold match', () => {
    expect(FlutterImageHashService.matches('7e7e7e7e7e7e7e7e', '7e7e7e7e7e7e7e7a')).toBe(true);
  });

  it('dense fingerprints beyond the threshold differ', () => {
    expect(FlutterImageHashService.matches('7e7e7e7e7e7e7e7e', '7e7e7e7e7e7e7e81')).toBe(false);
  });

  it('near-flat fingerprints never match, even identically', () => {
    expect(
      FlutterImageHashService.matches('000000000000003f', '000000000000003f'),
      'sparse hashes collide too easily for cross-URL matching'
    ).toBe(false);
  });

  // Added for the web: the Dart tests stand 8 bits from the threshold, not on it.
  it('tells 6 bits apart from 7, and 8 set bits from 7', () => {
    expect(FlutterImageHashService.matches('7e7e7e7e7e7e7e7e', '7e7e7e7e7e7e7e41')).toBe(true);
    expect(FlutterImageHashService.matches('7e7e7e7e7e7e7e7e', '7e7e7e7e7e7e7e01')).toBe(false);
    // A flat fingerprint is refused whichever side it is on.
    expect(FlutterImageHashService.matches('000000000000003f', '00000000000000ff')).toBe(false);
    expect(FlutterImageHashService.matches('00000000000000ff', '00000000000000ff')).toBe(true);
    expect(FlutterImageHashService.matches('000000000000007f', '000000000000007f')).toBe(false);
  });
});

// The browser decodes and scales in `decodeToPixels`, which needs the canvas
// jsdom does not have. The two gradient tests render the picture as pixels and
// take a box filter for that downscale, then hash what comes out of it.
describe('FlutterImageHashService.dHashFromBytes', () => {
  it('is stable across rescales of the same picture', () => {
    const small = _gradientPixels(36, 32);
    const large = _gradientPixels(720, 640);

    const hashSmall = FlutterImageHashService.dHashFromPixels(_reducedTo9x8(small, 36, 32));
    const hashLarge = FlutterImageHashService.dHashFromPixels(_reducedTo9x8(large, 720, 640));

    expect(hashSmall).not.toBeNull();
    expect(hashLarge).not.toBeNull();
    expect(
      FlutterImageHashService.distance(hashSmall!, hashLarge!),
      'rescaled copies of one picture must fingerprint-match'
    ).toBeLessThanOrEqual(6);
  });

  it('separates visually different pictures', () => {
    const normal = _gradientPixels(180, 160);
    const inverted = _gradientPixels(180, 160, true);

    const hashA = FlutterImageHashService.dHashFromPixels(_reducedTo9x8(normal, 180, 160));
    const hashB = FlutterImageHashService.dHashFromPixels(_reducedTo9x8(inverted, 180, 160));

    expect(
      FlutterImageHashService.distance(hashA!, hashB!),
      'opposite gradients must not fingerprint-match'
    ).toBeGreaterThan(6);
  });

  it('returns null for undecodable bytes', async () => {
    // Nothing here can decode: one that refuses the bytes stands in for the browser's decoder.
    vi.stubGlobal('createImageBitmap', () =>
      Promise.reject(new Error('The source image could not be decoded.'))
    );

    const result = await FlutterImageHashService.dHashFromBytes(new Uint8Array([1, 2, 3, 4]));

    expect(result).toBeNull();
  });
});

// Added for the web. The Dart suite never checks which way a borderline pixel
// goes; these are Flutter's readings of one 9×8 frame.
describe('FlutterImageHashService.dHashFromPixels', () => {
  /** A 9×8 frame in one shade; a test recolours pixels of it. */
  const frameOf = (shade: number): Uint8ClampedArray => {
    const pixels = new Uint8ClampedArray(9 * 8 * 4).fill(255);
    for (let p = 0; p < 72; p++) pixels.set([shade, shade, shade], p * 4);
    return pixels;
  };

  it('pads a short hash on the left, as Dart did', () => {
    const pixels = frameOf(100);
    pixels.set([200, 200, 200], 0);

    expect(FlutterImageHashService.dHashFromPixels(pixels)).toBe('0000000000000001');
  });

  it('rounds luma to the nearest, as Flutter does', () => {
    const pixels = frameOf(100);
    // 0.299·231 + 0.587·45 + 0.114·44 is a hair above 100.5: 101 rounded, 100 cut off.
    pixels.set([231, 45, 44], 0);

    expect(FlutterImageHashService.dHashFromPixels(pixels)).toBe('0000000000000001');
  });

  it('reads a transparent pixel as black, as premultiplied channels do', () => {
    const pixels = frameOf(100);
    pixels.set([200, 200, 200], 0);
    // The same colour, fully transparent, on the right: lighter left, so the bit is set.
    pixels.set([200, 200, 200, 0], 4);

    expect(FlutterImageHashService.dHashFromPixels(pixels)).toBe('0000000000000001');
  });
});

// Added for the web. The Dart suite never hashes a picture whose top bit is
// set: Dart prints such an int with a minus sign, and every entry the Flutter
// app stored keeps that text, so it has to read back to the same bits.
describe('FlutterImageHashService.signed fingerprints', () => {
  it('prints a hash with its top bit set as Dart printed it', () => {
    // Only the eighth pixel of the last row is lighter than its right neighbour.
    const pixels = new Uint8ClampedArray(9 * 8 * 4).fill(255);
    for (let p = 0; p < 72; p++) pixels.set([100, 100, 100], p * 4);
    pixels.set([200, 200, 200], (7 * 9 + 7) * 4);

    expect(FlutterImageHashService.dHashFromPixels(pixels)).toBe('-8000000000000000');
  });

  it('reads a signed, a padded and a spaced fingerprint as int.tryParse did', () => {
    expect(FlutterImageHashService.popCount('-3f')).toBe(59);
    expect(FlutterImageHashService.distance('-3f', '000000000000003f')).toBe(63);
    expect(FlutterImageHashService.distance('+3f', '3f')).toBe(0);
    expect(FlutterImageHashService.popCount(' 3f ')).toBe(6);
    expect(FlutterImageHashService.matches('-7765757c7f7f7f7c', '-7765757c7f7f7f7a')).toBe(true);
    // A positive int does not reach 2^63, and a minus inside the padding is no number.
    expect(FlutterImageHashService.popCount('8000000000000000')).toBe(0);
    expect(FlutterImageHashService.popCount('00000000000000-1')).toBe(0);
  });
});

interface Drawn {
  source: 'bitmap' | 'canvas';
  width: number;
  height: number;
  smoothing: 'off' | ImageSmoothingQuality;
}

/**
 * A browser that can neither decode nor scale: a bitmap of the given size and
 * canvases that record what is drawn on them and answer `frame`. It pins the
 * steps the decoder takes, not the pixels a real browser makes of them.
 */
function fakeBrowser(frame: Uint8ClampedArray, [width, height]: [number, number]) {
  const draws: Drawn[] = [];
  const bitmap = { width, height, close: vi.fn() };
  // Every canvas gets a context of its own, as in a browser.
  const createElement = () => {
    const context = {
      imageSmoothingEnabled: true,
      imageSmoothingQuality: 'low',
      drawImage: (source: unknown, _x: number, _y: number, w: number, h: number) => {
        draws.push({
          source: source === bitmap ? 'bitmap' : 'canvas',
          width: w,
          height: h,
          smoothing: context.imageSmoothingEnabled
            ? (context.imageSmoothingQuality as ImageSmoothingQuality)
            : 'off',
        });
      },
      getImageData: () => ({ data: frame }),
    };
    return { width: 0, height: 0, getContext: () => context };
  };
  vi.stubGlobal(
    'createImageBitmap',
    vi.fn(async () => bitmap)
  );
  vi.stubGlobal('document', { createElement });
  return { draws, bitmap };
}

// Added for the web. Flutter reduces in two steps, what the codec decodes at
// and then a linear scale, and the codec's step is what keeps a fingerprint
// close to Flutter's for the same picture.
describe('decodeToPixels', () => {
  const PNG = Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const JPEG = Uint8Array.from([0xff, 0xd8, 0xff, 0xe0]);
  const GIF = new TextEncoder().encode('GIF89a');
  const WEBP = new TextEncoder().encode('RIFF....WEBPVP8 ');
  const frame = new Uint8ClampedArray(9 * 8 * 4);

  it('draws a PNG straight to 9×8 with the linear scaling a canvas starts with', async () => {
    const { draws, bitmap } = fakeBrowser(frame, [640, 480]);

    const pixels = await decodeToPixels(PNG);

    expect(pixels).toBe(frame);
    expect(draws).toEqual([{ source: 'bitmap', width: 9, height: 8, smoothing: 'low' }]);
    expect(bitmap.close).toHaveBeenCalledOnce();
  });

  it('takes a large JPEG through the eighth libjpeg decodes it at', async () => {
    const { draws } = fakeBrowser(frame, [640, 480]);

    await decodeToPixels(JPEG);

    expect(draws).toEqual([
      { source: 'bitmap', width: 80, height: 60, smoothing: 'high' },
      { source: 'canvas', width: 9, height: 8, smoothing: 'low' },
    ]);
  });

  it('takes a small JPEG through the quarter libjpeg picks for it', async () => {
    const { draws } = fakeBrowser(frame, [40, 30]);

    await decodeToPixels(JPEG);

    expect(draws.map(({ width, height }) => [width, height])).toEqual([
      [10, 7],
      [9, 8],
    ]);
  });

  it('takes a 20×18 JPEG through the half libjpeg picks for it', async () => {
    const { draws } = fakeBrowser(frame, [20, 18]);

    await decodeToPixels(JPEG);

    expect(draws.map(({ width, height }) => [width, height])).toEqual([
      [10, 9],
      [9, 8],
    ]);
  });

  it('reduces a WebP box-like and samples a GIF at the size the target asks', async () => {
    const { draws } = fakeBrowser(frame, [640, 480]);

    await decodeToPixels(WEBP);
    await decodeToPixels(GIF);

    expect(draws).toEqual([
      { source: 'bitmap', width: 11, height: 8, smoothing: 'high' },
      { source: 'canvas', width: 9, height: 8, smoothing: 'low' },
      { source: 'bitmap', width: 11, height: 8, smoothing: 'off' },
      { source: 'canvas', width: 9, height: 8, smoothing: 'low' },
    ]);
  });
});

// Added for the web. Fetching through the relay is the web app's own step, and
// the Dart suite did not test what a URL is remembered as.
describe('FlutterImageHashService.hashFor', () => {
  const frame = new Uint8ClampedArray(9 * 8 * 4);

  /** A relay that answers every request with `status` and the given body. */
  const relayAnswering = (status: number) => {
    const response: HttpResponse = {
      status,
      url: 'https://x/a.jpg',
      headers: {},
      bodyBase64: btoa('\x01\x02\x03'),
    };
    return { request: vi.fn(async () => response) };
  };

  it('asks the relay once per URL and answers what it asked the first time', async () => {
    const relay = relayAnswering(200);
    fakeBrowser(frame, [640, 480]);
    const service = new FlutterImageHashService(relay);

    const first = await service.hashFor('https://x/memo/a.jpg');
    const second = await service.hashFor('https://x/memo/a.jpg');

    expect(first).toBe(FlutterImageHashService.dHashFromPixels(frame));
    expect(second).toBe(first);
    expect(relay.request).toHaveBeenCalledExactlyOnceWith({ url: 'https://x/memo/a.jpg' });
  });

  it('remembers a URL it could not hash, without asking again', async () => {
    const relay = relayAnswering(200);
    vi.stubGlobal('createImageBitmap', () =>
      Promise.reject(new Error('The source image could not be decoded.'))
    );
    const service = new FlutterImageHashService(relay);

    expect(await service.hashFor('https://x/memo/broken.jpg')).toBeNull();
    expect(await service.hashFor('https://x/memo/broken.jpg')).toBeNull();

    expect(relay.request).toHaveBeenCalledTimes(1);
  });

  it('answers null for a status the Flutter fetch refused, without decoding', async () => {
    const relay = relayAnswering(404);
    vi.stubGlobal('createImageBitmap', vi.fn());
    const service = new FlutterImageHashService(relay);

    expect(await service.hashFor('https://x/status/404.jpg')).toBeNull();

    expect(createImageBitmap).not.toHaveBeenCalled();
  });

  it('answers null when the relay itself fails', async () => {
    const service = new FlutterImageHashService({
      request: vi.fn(async () => {
        throw new Error('timeout');
      }),
    });

    expect(await service.hashFor('https://x/status/down.jpg')).toBeNull();
  });

  it('forgets what it remembered once 1024 URLs are in it', async () => {
    const relay = relayAnswering(200);
    fakeBrowser(frame, [640, 480]);
    const service = new FlutterImageHashService(relay);

    await service.hashFor('https://x/full/0.jpg');
    for (let i = 1; i <= 1024; i++) await service.hashFor(`https://x/full/${i}.jpg`);
    // The 1025th URL cleared all that came before, the first one included.
    await service.hashFor('https://x/full/0.jpg');

    expect(relay.request).toHaveBeenCalledTimes(1026);
  });
});

afterEach(() => {
  vi.unstubAllGlobals();
});
