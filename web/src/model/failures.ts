/** What the app could see about a page fetch that failed, for error reports. */
export interface HttpDiagnostics {
  statusCode?: number;
  /** The response headers that say why a server refused. */
  headers: Record<string, string>;
  /** Start of the response body. */
  bodySnippet: string;
  requestPath?: string;
}

/**
 * Base class of what a page fetch can fail with. `instanceof` a subclass
 * tells the kinds apart.
 */
export abstract class Failure extends Error {
  /**
   * The class of the failure as text. A build may rename classes, so what
   * reaches a report or a log names the kind explicitly.
   */
  abstract readonly kind: FailureKind;
  readonly http: HttpDiagnostics | undefined;

  constructor(message: string, http?: HttpDiagnostics) {
    super(message);
    this.http = http;
  }
}

export type FailureKind = 'ServerFailure' | 'NetworkFailure' | 'ParseFailure';

/** The server answered, but not with the page. */
export class ServerFailure extends Failure {
  readonly kind = 'ServerFailure' as const;
}

/** No answer arrived: the connection, a timeout or the relay itself failed. */
export class NetworkFailure extends Failure {
  readonly kind = 'NetworkFailure' as const;
}

/** The page came, but nothing in it could be read: the site's markup changed. */
export class ParseFailure extends Failure {
  readonly kind = 'ParseFailure' as const;
}
