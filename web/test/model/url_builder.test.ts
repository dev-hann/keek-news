import { describe, expect, it } from 'vitest';
import { resolveAbsolute } from '../../src/model/url_builder';

describe('UrlBuilder.resolveAbsolute', () => {
  it('should resolve humoruniv relative path to full m.humoruniv.com URL', () => {
    const result = resolveAbsolute('humoruniv', '/board/read.html?table=pds&number=100');

    expect(result).toBe('https://m.humoruniv.com/board/read.html?table=pds&number=100');
  });

  it('should resolve todayhumor relative path to full URL', () => {
    const result = resolveAbsolute('todayhumor', '/board/view.php?table=humorbest&no=12345');

    expect(result).toBe('https://www.todayhumor.co.kr/board/view.php?table=humorbest&no=12345');
  });

  it('should resolve ppomppu relative path to full URL', () => {
    const result = resolveAbsolute('ppomppu', '/zboard/view.php?id=humor&no=99');

    expect(result).toBe('https://www.ppomppu.co.kr/zboard/view.php?id=humor&no=99');
  });

  it('should resolve dogdrip relative path to full URL', () => {
    const result = resolveAbsolute('dogdrip', '/index.php?document_srl=716302509');

    expect(result).toBe('https://www.dogdrip.net/index.php?document_srl=716302509');
  });

  it('should return input unchanged when already absolute http URL', () => {
    const full = 'https://example.com/some/path';
    const result = resolveAbsolute('humoruniv', full);

    expect(result).toBe(full);
  });

  it('should return input unchanged when already absolute https URL', () => {
    const full = 'https://m.humoruniv.com/board/read.html?table=pds&number=1';
    const result = resolveAbsolute('humoruniv', full);

    expect(result).toBe(full);
  });

  it('should preserve query parameters when resolving', () => {
    const result = resolveAbsolute('humoruniv', '/board/read.html?table=pds&number=5&foo=bar');

    expect(result).toBe('https://m.humoruniv.com/board/read.html?table=pds&number=5&foo=bar');
  });

  it('should resolve relative path without leading slash', () => {
    const result = resolveAbsolute('humoruniv', 'board/read.html?table=pds&number=1');

    expect(result).toBe('https://m.humoruniv.com/board/read.html?table=pds&number=1');
  });
});
