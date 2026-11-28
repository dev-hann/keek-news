import { describe, expect, it } from 'vitest';
import { parseLinkSegments } from '../../src/utils/link_segments';

describe('parseLinkSegments', () => {
  it('plain text without URLs yields a single text segment', () => {
    const segments = parseLinkSegments('그냥 본문 텍스트입니다.');

    expect(segments).toHaveLength(1);
    expect(segments[0]).toEqual({ text: '그냥 본문 텍스트입니다.' });
  });

  it('http and https URLs become link segments', () => {
    const segments = parseLinkSegments('보세요 https://example.com/a?x=1 감사');

    expect(segments).toEqual([
      { text: '보세요 ' },
      { text: 'https://example.com/a?x=1', url: 'https://example.com/a?x=1' },
      { text: ' 감사' },
    ]);
  });

  it('www. URLs get an https scheme in url but keep display text', () => {
    const segments = parseLinkSegments('www.example.com/page');

    expect(segments).toEqual([
      { text: 'www.example.com/page', url: 'https://www.example.com/page' },
    ]);
  });

  it('trailing punctuation stays out of the link', () => {
    const segments = parseLinkSegments('링크 https://example.com/a.).');

    expect(segments[1]).toEqual({ text: 'https://example.com/a', url: 'https://example.com/a' });
    expect(segments.at(-1)).toEqual({ text: '.).' });
  });

  it('multiple URLs split into separate segments', () => {
    const segments = parseLinkSegments('https://a.com/1 그리고 www.b.com/2');
    const links = segments.filter((segment) => segment.url !== undefined);

    expect(links.map((link) => link.url)).toEqual(['https://a.com/1', 'https://www.b.com/2']);
  });

  it('an uppercase scheme is a link too', () => {
    const segments = parseLinkSegments('HTTPS://example.com/A');

    expect(segments).toEqual([{ text: 'HTTPS://example.com/A', url: 'HTTPS://example.com/A' }]);
  });

  it('empty string yields no segments', () => {
    expect(parseLinkSegments('')).toEqual([]);
  });
});
