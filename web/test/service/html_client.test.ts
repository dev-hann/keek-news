import type { HttpRequest, HttpResponse } from '@gyo-community/http';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { NetworkFailure, ServerFailure } from '../../src/model/failures';
import { HtmlClient } from '../../src/service/html_client';

const utf8 = (text: string) => Buffer.from(text, 'utf8').toString('base64');

function response(overrides: Partial<HttpResponse> = {}): HttpResponse {
  return {
    status: 200,
    url: 'https://example.com/board',
    headers: { 'content-type': 'text/html' },
    bodyBase64: '',
    ...overrides,
  };
}

const relay = () => ({ request: vi.fn<(request: HttpRequest) => Promise<HttpResponse>>() });

function client(http: ReturnType<typeof relay>, encoding = 'utf-8', jar?: string) {
  return new HtmlClient(http, {
    baseUrl: 'https://example.com',
    headers: { 'User-Agent': 'ua/1.0', Referer: 'https://example.com/' },
    encoding,
    ...(jar ? { jar } : {}),
  });
}

/** Lets the fake clock run ahead and the requests in flight settle. */
const wait = (ms: number) => vi.advanceTimersByTimeAsync(ms);

describe('HtmlClient', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('requests the path on the base url with the headers and decodes UTF-8', async () => {
    const http = relay();
    http.request.mockResolvedValue(response({ bodyBase64: utf8('<p>가나다</p>') }));

    const html = await client(http).get('/board/list.html?page=1');

    expect(html).toBe('<p>가나다</p>');
    expect(http.request).toHaveBeenCalledExactlyOnceWith({
      url: 'https://example.com/board/list.html?page=1',
      headers: { 'User-Agent': 'ua/1.0', Referer: 'https://example.com/' },
    });
  });

  it('decodes with the charset of the site', async () => {
    const http = relay();
    // B0 A1 is "가" in EUC-KR.
    http.request.mockResolvedValue(
      response({ bodyBase64: Buffer.from([0xb0, 0xa1]).toString('base64') })
    );

    expect(await client(http, 'euc-kr').get('/zboard.php')).toBe('가');
  });

  it('sends the jar only when the site keeps one', async () => {
    const http = relay();
    http.request.mockResolvedValue(response());

    await client(http, 'utf-8', 'dogdrip').get('/');
    await client(http).get('/');

    expect(http.request.mock.calls.map(([request]) => request.jar)).toEqual(['dogdrip', undefined]);
  });

  it('turns malformed bytes into replacement characters instead of failing', async () => {
    const http = relay();
    http.request.mockResolvedValue(response({ bodyBase64: '////' }));

    expect(await client(http).get('/')).toBe('\uFFFD\uFFFD\uFFFD');
  });

  describe('a status outside 2xx', () => {
    it('is a ServerFailure that carries what the server said', async () => {
      const http = relay();
      http.request.mockResolvedValue(
        response({
          status: 403,
          bodyBase64: utf8('서버에 접속 할 수 없습니다'),
          headers: {
            server: 'cloudflare',
            'cf-ray': 'abc',
            'content-type': 'text/html',
            'set-cookie': 'PHPSESSID=secret',
          },
        })
      );

      const failure = await client(http)
        .get('/123')
        .catch((error: unknown) => error);

      expect(failure).toBeInstanceOf(ServerFailure);
      expect(failure).toMatchObject({
        message: 'HTTP 403',
        http: {
          statusCode: 403,
          headers: { server: 'cloudflare', 'cf-ray': 'abc', 'content-type': 'text/html' },
          bodySnippet: '서버에 접속 할 수 없습니다',
          requestPath: '/123',
        },
      });
    });

    it('keeps the snippet to the first 500 characters', async () => {
      const http = relay();
      http.request.mockResolvedValue(response({ status: 404, bodyBase64: utf8('가'.repeat(900)) }));

      const failure = (await client(http)
        .get('/')
        .catch((error: unknown) => error)) as ServerFailure;

      expect(failure.http?.bodySnippet).toHaveLength(500);
    });

    it('is retried on the 503 schedule when it is a 503, until a page comes', async () => {
      const http = relay();
      http.request
        .mockResolvedValueOnce(response({ status: 503 }))
        .mockResolvedValueOnce(response({ status: 503 }))
        .mockResolvedValueOnce(response({ bodyBase64: utf8('ok') }));

      const pending = client(http).get('/');
      await wait(0);
      expect(http.request).toHaveBeenCalledTimes(1);
      await wait(1000);
      expect(http.request).toHaveBeenCalledTimes(2);
      await wait(4000);

      await expect(pending).resolves.toBe('ok');
      expect(http.request).toHaveBeenCalledTimes(3);
    });

    it('waits what a 503 asks for in Retry-After', async () => {
      const http = relay();
      http.request
        .mockResolvedValueOnce(response({ status: 503, headers: { 'retry-after': '7' } }))
        .mockResolvedValueOnce(response({ bodyBase64: utf8('ok') }));

      const pending = client(http).get('/');
      await wait(6999);
      expect(http.request).toHaveBeenCalledTimes(1);
      await wait(1);

      await expect(pending).resolves.toBe('ok');
    });

    it('is given up at once when Retry-After asks for more than 30 seconds', async () => {
      const http = relay();
      http.request.mockResolvedValue(response({ status: 503, headers: { 'retry-after': '120' } }));

      const failure = await client(http)
        .get('/')
        .catch((error: unknown) => error);

      expect(failure).toBeInstanceOf(ServerFailure);
      expect(http.request).toHaveBeenCalledTimes(1);
    });

    it('is given up after the schedule runs out', async () => {
      const http = relay();
      http.request.mockResolvedValue(response({ status: 503 }));

      const pending = client(http)
        .get('/')
        .catch((error: unknown) => error);
      await wait(15_000);

      expect(await pending).toBeInstanceOf(ServerFailure);
      expect(http.request).toHaveBeenCalledTimes(4);
    });
  });

  describe('no answer at all', () => {
    it('is retried on the network schedule until an answer comes', async () => {
      const http = relay();
      http.request
        .mockRejectedValueOnce(new Error('timeout'))
        .mockRejectedValueOnce(new Error('timeout'))
        .mockResolvedValueOnce(response({ bodyBase64: utf8('ok') }));

      const pending = client(http).get('/');
      await wait(499);
      expect(http.request).toHaveBeenCalledTimes(1);
      await wait(1);
      await wait(1000);

      await expect(pending).resolves.toBe('ok');
      expect(http.request).toHaveBeenCalledTimes(3);
    });

    it('is a NetworkFailure once the schedule runs out', async () => {
      const http = relay();
      http.request.mockRejectedValue(new Error('failed to connect to example.com'));

      const pending = client(http)
        .get('/board')
        .catch((error: unknown) => error);
      await wait(3500);

      const failure = await pending;
      expect(failure).toBeInstanceOf(NetworkFailure);
      expect(failure).toMatchObject({
        message: 'failed to connect to example.com',
        http: { requestPath: '/board' },
      });
      expect(http.request).toHaveBeenCalledTimes(4);
    });
  });
});
