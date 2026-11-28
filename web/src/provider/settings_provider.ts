import { feedUseCase } from '../service/service_locator';
import type { CommunityId } from '../model/community';
import type { FeedUseCase } from '../use_case/feed_use_case';
import { StateNotifier, useNotifierState } from './state_notifier';

/** Which communities the user has on. */
export class SettingsNotifier extends StateNotifier<Set<CommunityId>> {
  private readonly useCase: FeedUseCase;

  constructor(useCase: FeedUseCase) {
    super(useCase.getEnabledCommunities());
    this.useCase = useCase;
  }

  toggle(id: CommunityId): void {
    this.useCase.toggleCommunity(id);
    this.state = this.useCase.getEnabledCommunities();
  }

  canDisable(id: CommunityId): boolean {
    return this.useCase.canDisableCommunity(id);
  }
}

let settings: SettingsNotifier | undefined;

/** The one settings notifier of the app, made the first time a screen asks for it. */
export function settingsNotifier(): SettingsNotifier {
  settings ??= new SettingsNotifier(feedUseCase());
  return settings;
}

/** The communities the user has on. */
export function useSettings(): Set<CommunityId> {
  return useNotifierState(settingsNotifier());
}
