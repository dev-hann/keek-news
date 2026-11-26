import {
  base64ToBytes,
  decodeText,
  type Http,
  type HttpRequest,
  type HttpResponse,
} from '@gyo-framework/http';
import { NetworkFailure, ServerFailure } from '../model/failures';

/** The part of the HTTP relay a page fetch needs. Tests pass a fake. */
type Relay = Pick<Http, 'request'>;

export interface HtmlClientOptions {
  /** Scheme and host every path is requested from. */
  baseUrl: string;
  /** Headers of every request: the site's user agent and Referer included. */
  headers: Record<string, string>;
  /** Charset the site encodes its pages with. */
  encoding: string;
  /** Name of the cookie jar that keeps the site's session. Omit for sites that need none. */
  jar?: string;
}

/** Network failures get a short fast schedule, so a hiccup on a mobile network recovers quickly. */
const networkBackoffMs = [500, 1000, 2000];
/** An HTTP 503 waits longer, unless the server names its own wait. */
const serverBackoffMs = [1000, 4000, 10000];
/** A server that asks for a longer wait is overloaded: give up rather than hold the reader. */
const maxRetryAfterMs = 30_000;

/** The response headers that say why a server refused; the rest is noise in an error report. */
const diagnosticHeaderNames = [
  'server',
  'cf-ray',
  'cf-mitigated',
  'retry-after',
  'content-type',
  'date',
];
const maxSnippetBytes = 2000;
const maxSnippetChars = 500;

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

const toMessage = (error: unknown) => (error instanceof Error ? error.message : String(error));

/** How long to wait before trying a 503 again, or null when the server's ask is too long. */
function retryAfterMs(value: string | undefined, fallback: number): number | null {
  if (value === undefined || !/^\d+$/.test(value)) return fallback;
  const wait = Number(value) * 1000;
  return wait > maxRetryAfterMs ? null : wait;
}

/** Runs `send` until an answer comes that will not improve on its own. */
async function withRetry(send: () => Promise<HttpResponse>): Promise<HttpResponse> {
  for (let attempt = 0; ; attempt++) {
    try {
      const response = await send();
      if (response.status !== 503) return response;
      const scheduled = serverBackoffMs[attempt];
      if (scheduled === undefined) return response;
      const wait = retryAfterMs(response.headers['retry-after'], scheduled);
      if (wait === null) return response;
      await sleep(wait);
    } catch (error) {
      const wait = networkBackoffMs[attempt];
      if (wait === undefined) throw error;
      await sleep(wait);
    }
  }
}

function diagnosticHeaders(headers: Record<string, string>): Record<string, string> {
  const picked: Record<string, string> = {};
  for (const name of diagnosticHeaderNames) {
    if (headers[name]) picked[name] = headers[name];
  }
  return picked;
}

/** Start of the body, as UTF-8 whatever the page's charset: enough to recognize a refusal page. */
function bodySnippet(response: HttpResponse): string {
  const bytes = base64ToBytes(response.bodyBase64).slice(0, maxSnippetBytes);
  return new TextDecoder().decode(bytes).slice(0, maxSnippetChars);
}

/** Fetches the pages of one site through the native relay. */
export class HtmlClient {
  private readonly relay: Relay;
  private readonly options: HtmlClientOptions;

  constructor(relay: Relay, options: HtmlClientOptions) {
    this.relay = relay;
    this.options = options;
  }

  /**
   * Returns the markup at `path`. Rejects with a ServerFailure for a status outside 2xx and a
   * NetworkFailure when no answer arrived at all.
   */
  async get(path: string): Promise<string> {
    const { baseUrl, headers, encoding, jar } = this.options;
    const request: HttpRequest = { url: baseUrl + path, headers, ...(jar ? { jar } : {}) };

    let response: HttpResponse;
    try {
      response = await withRetry(() => this.relay.request(request));
    } catch (error) {
      throw new NetworkFailure(toMessage(error), {
        headers: {},
        bodySnippet: '',
        requestPath: path,
      });
    }

    if (response.status < 200 || response.status >= 300) {
      throw new ServerFailure(`HTTP ${response.status}`, {
        statusCode: response.status,
        headers: diagnosticHeaders(response.headers),
        bodySnippet: bodySnippet(response),
        requestPath: path,
      });
    }
    return decodeText(response, encoding);
  }
}
