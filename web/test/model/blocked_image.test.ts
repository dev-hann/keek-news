import { describe, expect, it } from 'vitest';
import {
  type BlockedImage,
  blockedImageFromJson,
  blockedImageToJson,
} from '../../src/model/blocked_image';

describe('BlockedImage', () => {
  it('should round-trip through JSON', () => {
    const image: BlockedImage = {
      url: 'https://example.com/a.jpg',
      blockedAt: new Date(1722324000000),
      hash: '0123456789abcdef',
    };

    const decoded = blockedImageFromJson(blockedImageToJson(image));

    expect(decoded.url).toBe(image.url);
    expect(decoded.blockedAt).toEqual(image.blockedAt);
    expect(decoded.hash).toBe('0123456789abcdef');
  });

  it('should decode legacy entries without a hash', () => {
    const decoded = blockedImageFromJson({
      url: 'https://example.com/a.jpg',
      blockedAtMillis: 1722324000000,
    });

    expect(decoded.hash).toBeUndefined();
  });

  it('should use url in equality', () => {
    const blockedAt = new Date(1722324000000);
    // A plain object has no ==: equal fields is what equality comes to.
    expect({ url: 'https://x/a.jpg', blockedAt }).toEqual({ url: 'https://x/a.jpg', blockedAt });
    expect({ url: 'https://x/a.jpg', blockedAt }).not.toEqual({
      url: 'https://x/b.jpg',
      blockedAt,
    });
  });
});

describe('BlockedImage.toJson', () => {
  // The Flutter app moves what readers blocked into this app, so what is stored
  // must stay what `jsonEncode(image.toJson())` wrote there. Both texts below
  // are that function's output for these images.
  it('should store the JSON the Flutter app stored', () => {
    const blockedAt = new Date(1722324000000);

    expect(
      JSON.stringify(
        blockedImageToJson({
          url: 'https://example.com/a.jpg',
          blockedAt,
          hash: '0123456789abcdef',
        })
      )
    ).toBe(
      '{"url":"https://example.com/a.jpg","blockedAtMillis":1722324000000,"hash":"0123456789abcdef"}'
    );
    expect(
      JSON.stringify(blockedImageToJson({ url: 'https://example.com/a.jpg', blockedAt }))
    ).toBe('{"url":"https://example.com/a.jpg","blockedAtMillis":1722324000000}');
  });
});
