import { describe, expect, it } from 'vitest';
import { communityIds } from '../../src/model/community';
import { desktopUserAgent, mobileUserAgent } from '../../src/service/community_headers';
import { htmlClientOptions } from '../../src/service/service_locator';

describe('htmlClientOptions', () => {
  it('names a client for every community', () => {
    expect(Object.keys(htmlClientOptions).sort()).toEqual([...communityIds].sort());
  });

  it('gives every client the browser headers with the user agent and Referer of its site', () => {
    for (const options of Object.values(htmlClientOptions)) {
      const url = new URL(options.baseUrl);
      expect(options.headers.Referer.startsWith(options.baseUrl), options.baseUrl).toBe(true);
      expect(options.headers['User-Agent']).toMatch(/Chrome\/138/);
      expect(options.headers.Accept).toContain('text/html');
      expect(url.pathname).toBe('/');
    }
  });

  it('reads humoruniv as a phone and the rest as a desktop browser', () => {
    expect(htmlClientOptions.humoruniv.headers['User-Agent']).toBe(mobileUserAgent);
    for (const [id, options] of Object.entries(htmlClientOptions)) {
      if (id !== 'humoruniv') expect(options.headers['User-Agent']).toBe(desktopUserAgent);
    }
  });

  it('decodes only ppomppu as EUC-KR', () => {
    for (const [id, options] of Object.entries(htmlClientOptions)) {
      expect(options.encoding, id).toBe(id === 'ppomppu' ? 'euc-kr' : 'utf-8');
    }
  });

  it('keeps a cookie jar only for the sites the Flutter app kept one for', () => {
    // dogdrip answered detail pages with a 503 until its session cookie was kept (Flutter commit 1c3cb2e).
    // bobaedream, ruliweb and natepann never got one: bobaedream sets sort cookies the app never sent.
    const withJar = Object.entries(htmlClientOptions)
      .filter(([, options]) => options.jar !== undefined)
      .map(([id]) => id);
    expect(withJar.sort()).toEqual(['dogdrip', 'fmkorea', 'humoruniv', 'ppomppu', 'todayhumor']);
  });
});
