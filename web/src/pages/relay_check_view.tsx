import { Http, base64ToBytes, decodeText, type HttpRequest } from '@gyo-community/http';
import { useEffect, useState } from 'react';
import { cn } from 'cn';
import { Button } from '../components/ui/button';
import { AppBar } from '../widgets/app_bar';
import type { CommunityId } from '../model/community';
import { Failure, NetworkFailure, ServerFailure } from '../model/failures';
import { HtmlClient } from '../service/html_client';
import { htmlClient } from '../service/service_locator';

/** First page of each community the app shows. The parsers own these paths from their port on. */
const listPaths: Partial<Record<CommunityId, string>> = {
  humoruniv: '/board/list.html?table=pds&pg=0',
  todayhumor: '/board/list.php?table=humorbest&page=1',
  ppomppu: '/zboard/zboard.php?id=humor&page=1',
  dogdrip: '/index.php?mid=dogdrip&page=1',
  bobaedream: '/list?code=humor&page=1',
  ruliweb: '/best/humor?page=1',
  natepann: '/talk?page=1',
};

/** Routes of dev/relay-check-server.ts, which only `vite dev` serves. */
const HARNESS = `${location.origin}/__relay-check`;

type Verdict = 'PASS' | 'FAIL' | 'PENDING';

interface CheckResult {
  name: string;
  verdict: Verdict;
  detail: string;
  ms: number;
}

interface Outcome {
  verdict: 'PASS' | 'PENDING';
  detail: string;
}

interface Check {
  name: string;
  run: () => Promise<Outcome>;
}

const pass = (detail: string): Outcome => ({ verdict: 'PASS', detail });

function describe(error: unknown): string {
  if (!(error instanceof Failure)) {
    return error instanceof Error ? error.message : String(error);
  }
  const http = error.http;
  if (!http) return error.message;
  const headers = Object.entries(http.headers).map(([name, value]) => `${name}=${value}`);
  return [error.message, http.bodySnippet.slice(0, 120), ...headers].filter(Boolean).join(' · ');
}

function harnessChecks(http: Http): Check[] {
  const echo = (jar?: string): HttpRequest => ({
    url: `${HARNESS}/echo`,
    ...(jar ? { jar } : {}),
  });
  const cookieReceived = async (request: HttpRequest) =>
    (JSON.parse(decodeText(await http.request(request))) as { cookie: string | null }).cookie;
  const harnessClient = () =>
    new HtmlClient(http, { baseUrl: HARNESS, headers: {}, encoding: 'utf-8' });
  /** Fails unless `path` comes back as a ServerFailure with that status, and returns it. */
  const refusal = async (path: string, status: number) => {
    try {
      await harnessClient().get(path);
    } catch (error) {
      if (!(error instanceof ServerFailure) || error.http?.statusCode !== status) throw error;
      return error;
    }
    throw new Error(`${path} answered with a page instead of ${status}`);
  };

  return [
    {
      name: 'redirect followed',
      run: async () => {
        const response = await http.request({ url: `${HARNESS}/redirect` });
        const finalPath = new URL(response.url).pathname;
        if (response.status !== 200 || !finalPath.endsWith('/echo')) {
          throw new Error(`${response.status} ${finalPath}`);
        }
        return pass(`final url ${finalPath}`);
      },
    },
    {
      name: 'cookies kept per jar',
      run: async () => {
        // A name no earlier run used: jars persist, so a fixed name would carry a cookie over.
        const freshJar = `fresh-${Math.random().toString(36).slice(2)}`;
        await cookieReceived(echo('jar-a'));
        const again = await cookieReceived(echo('jar-a'));
        const withoutJar = await cookieReceived(echo());
        const otherJar = await cookieReceived(echo(freshJar));
        if (again !== 'relay_sid=step0' || withoutJar !== null || otherJar !== null) {
          throw new Error(
            `second request in the jar: ${again}; without a jar: ${withoutJar}; other jar: ${otherJar}`
          );
        }
        return pass('a jar sends its cookie back; no jar and other jars send none');
      },
    },
    {
      name: 'cookies survive a restart',
      run: async () => {
        const cookie = await cookieReceived(echo('persist'));
        return cookie === 'relay_sid=step0'
          ? pass('the cookie of the earlier run came back')
          : {
              verdict: 'PENDING',
              detail: 'no cookie yet: restart the app and open this page again',
            };
      },
    },
    {
      name: '404 reported with its headers',
      run: async () => {
        const failure = await refusal('/status/404', 404);
        if (failure.http?.headers['content-type'] !== 'text/plain') {
          throw new Error(`headers ${JSON.stringify(failure.http?.headers)}`);
        }
        return pass(`snippet "${failure.http.bodySnippet}"`);
      },
    },
    {
      name: '503 with a long Retry-After is not retried',
      run: async () => {
        const failure = await refusal('/status/503?retry-after=120', 503);
        if (failure.http?.headers['retry-after'] !== '120') {
          throw new Error(`headers ${JSON.stringify(failure.http?.headers)}`);
        }
        return pass('gave up at once on retry-after=120');
      },
    },
    {
      name: 'unreachable host is a network failure',
      run: async () => {
        try {
          await new HtmlClient(http, {
            baseUrl: 'http://127.0.0.1:9',
            headers: {},
            encoding: 'utf-8',
          }).get('/');
        } catch (error) {
          if (!(error instanceof NetworkFailure)) throw error;
          return pass(error.message);
        }
        throw new Error('the refused connection answered with a page');
      },
    },
    ...[1500, 4000].map((kb): Check => ({
      name: `body of ${kb} KB`,
      run: async () => {
        const response = await http.request({ url: `${HARNESS}/big/${kb}` });
        const bytes = base64ToBytes(response.bodyBase64).length;
        if (bytes !== kb * 1024) throw new Error(`got ${bytes} bytes`);
        return pass(`${bytes} bytes`);
      },
    })),
  ];
}

const communityChecks: Check[] = (Object.entries(listPaths) as [CommunityId, string][]).map(
  ([id, path]) => ({
    name: `list · ${id}`,
    run: async () => {
      const html = await htmlClient(id).get(path);
      const hangul = (html.match(/[\uac00-\ud7a3]/g) ?? []).length;
      const broken = (html.match(/\ufffd/g) ?? []).length;
      if (!html.includes('<')) throw new Error('no markup in the answer');
      if (broken > 0) throw new Error(`${broken} broken characters`);
      if (hangul === 0) throw new Error('no Korean text');
      return pass(`${html.length} chars · Hangul ${hangul}`);
    },
  })
);

/** Runs every check in turn and hands each result to `onResult` as it comes. */
async function runChecks(onResult: (result: CheckResult) => void): Promise<void> {
  const http = new Http();
  const checks = import.meta.env.DEV
    ? [...harnessChecks(http), ...communityChecks]
    : communityChecks;
  const results: CheckResult[] = [];

  for (const check of checks) {
    const started = performance.now();
    let result: CheckResult;
    try {
      result = {
        name: check.name,
        ...(await check.run()),
        ms: Math.round(performance.now() - started),
      };
    } catch (error) {
      result = {
        name: check.name,
        verdict: 'FAIL',
        detail: describe(error),
        ms: Math.round(performance.now() - started),
      };
    }
    results.push(result);
    onResult(result);
  }

  // The dev server logs it, so a check can be read from the development machine.
  if (import.meta.env.DEV) {
    await fetch(`${HARNESS}/report`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userAgent: navigator.userAgent, results }),
    });
  }
}

const VERDICT_COLOR: Record<Verdict, string> = {
  PASS: 'text-primary',
  FAIL: 'text-destructive',
  PENDING: 'text-muted-foreground',
};

interface RelayCheckViewProps {
  onBack: () => void;
}

/** Runs the checks of the native relay on a device and shows what came of them. */
export function RelayCheckView({ onBack }: RelayCheckViewProps) {
  const [results, setResults] = useState<CheckResult[]>([]);
  const [running, setRunning] = useState(true);
  const [run, setRun] = useState(0);

  useEffect(() => {
    let current = true;
    runChecks((result) => {
      if (current) setResults((soFar) => [...soFar, result]);
    }).finally(() => {
      if (current) setRunning(false);
    });
    return () => {
      current = false;
    };
  }, [run]);

  const failed = results.filter((result) => result.verdict === 'FAIL').length;
  const passed = results.filter((result) => result.verdict === 'PASS').length;
  const pending = results.length - passed - failed;

  return (
    <div className="min-h-dvh bg-background">
      <AppBar title="릴레이 검사" onBack={onBack} />
      <main className="mx-auto w-full max-w-2xl px-4 pb-16">
        <p role="status" className="py-3 text-muted-foreground">
          PASS {passed} · FAIL {failed} · PENDING {pending}
          {running ? ' · running…' : ''}
        </p>
        {running || (
          <Button
            type="button"
            variant="outline"
            className="h-11"
            onClick={() => {
              setResults([]);
              setRun(run + 1);
            }}
          >
            다시 실행
          </Button>
        )}
        <ol className="mt-4 border-t border-border">
          {results.map((result) => (
            <li key={result.name} className="border-b border-border py-2">
              <div className="flex items-baseline gap-3">
                <span className={cn('w-16 shrink-0 font-semibold', VERDICT_COLOR[result.verdict])}>
                  {result.verdict}
                </span>
                <span className="min-w-0 flex-1 font-medium">{result.name}</span>
                <span className="shrink-0 text-sm text-muted-foreground">{result.ms} ms</span>
              </div>
              <p className="pt-0.5 pl-19 text-sm break-words text-muted-foreground">
                {result.detail}
              </p>
            </li>
          ))}
        </ol>
      </main>
    </div>
  );
}
