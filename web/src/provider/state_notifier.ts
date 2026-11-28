import { useSyncExternalStore } from 'react';

/**
 * A holder of one state that tells its listeners whenever the state is
 * replaced. The base of every provider: the state machine of a screen lives in
 * a notifier, tested without React; a hook binds the notifier to the screen.
 */
export abstract class StateNotifier<State> {
  private current: State;
  private readonly listeners = new Set<() => void>();

  protected constructor(initial: State) {
    this.current = initial;
  }

  getState = (): State => this.current;

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  protected set state(next: State) {
    this.current = next;
    this.listeners.forEach((listener) => listener());
  }

  protected get state(): State {
    return this.current;
  }
}

/** The state of a notifier, re-read whenever the notifier replaces it. */
export function useNotifierState<State>(notifier: StateNotifier<State>): State {
  return useSyncExternalStore(notifier.subscribe, notifier.getState, notifier.getState);
}
