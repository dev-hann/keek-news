import type { Failure } from './failures';

/** What a use case answers: a value, or the failure that stopped it. */
export type Result<T> = { ok: true; value: T } | { ok: false; failure: Failure };
