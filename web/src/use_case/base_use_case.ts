import { Failure, ServerFailure } from '../model/failures';
import type { Result } from '../model/result';

export abstract class BaseUseCase {
  /** Runs `action`. What it throws comes back as a Failure instead of propagating. */
  protected async guard<T>(action: () => Promise<T>): Promise<Result<T>> {
    try {
      return { ok: true, value: await action() };
    } catch (error) {
      return {
        ok: false,
        failure: error instanceof Failure ? error : new ServerFailure(String(error)),
      };
    }
  }
}
