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
 * Base class of what a page fetch can fail with. `instanceof` a subclass tells the kinds apart.
 */
export class Failure extends Error {
  readonly http: HttpDiagnostics | undefined;

  constructor(message: string, http?: HttpDiagnostics) {
    super(message);
    this.name = new.target.name;
    this.http = http;
  }
}

/** The server answered, but not with the page. */
export class ServerFailure extends Failure {}

/** No answer arrived: the connection, a timeout or the relay itself failed. */
export class NetworkFailure extends Failure {}
