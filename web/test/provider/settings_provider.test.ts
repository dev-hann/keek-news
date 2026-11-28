import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { CommunityId } from '../../src/model/community';
import { SettingsNotifier } from '../../src/provider/settings_provider';
import type { FeedUseCase } from '../../src/use_case/feed_use_case';

describe('SettingsNotifier', () => {
  let getEnabledCommunities: ReturnType<typeof vi.fn<() => Set<CommunityId>>>;
  let toggleCommunity: ReturnType<typeof vi.fn<(id: CommunityId) => void>>;
  let canDisableCommunity: ReturnType<typeof vi.fn<(id: CommunityId) => boolean>>;
  let useCase: FeedUseCase;

  beforeEach(() => {
    getEnabledCommunities = vi.fn<() => Set<CommunityId>>();
    toggleCommunity = vi.fn<(id: CommunityId) => void>();
    canDisableCommunity = vi.fn<(id: CommunityId) => boolean>();
    useCase = {
      getEnabledCommunities,
      toggleCommunity,
      canDisableCommunity,
    } as unknown as FeedUseCase;
  });

  it('starts with the communities the use case has on', () => {
    getEnabledCommunities.mockReturnValue(new Set(['dogdrip', 'ppomppu']));

    expect(new SettingsNotifier(useCase).getState()).toEqual(new Set(['dogdrip', 'ppomppu']));
  });

  it('toggles through the use case and shows what it has on afterwards', () => {
    getEnabledCommunities.mockReturnValueOnce(new Set(['dogdrip', 'ppomppu']));
    const notifier = new SettingsNotifier(useCase);
    getEnabledCommunities.mockReturnValueOnce(new Set(['ppomppu']));

    notifier.toggle('dogdrip');

    expect(toggleCommunity).toHaveBeenCalledExactlyOnceWith('dogdrip');
    expect(notifier.getState()).toEqual(new Set(['ppomppu']));
  });

  it('tells its listener when a community is toggled', () => {
    getEnabledCommunities.mockReturnValue(new Set(['dogdrip', 'ppomppu']));
    const notifier = new SettingsNotifier(useCase);
    const listener = vi.fn();
    notifier.subscribe(listener);

    notifier.toggle('dogdrip');

    expect(listener).toHaveBeenCalledTimes(1);
  });

  it('asks the use case whether a community may be switched off', () => {
    canDisableCommunity.mockReturnValue(false);
    const notifier = new SettingsNotifier(useCase);

    expect(notifier.canDisable('dogdrip')).toBe(false);
    expect(canDisableCommunity).toHaveBeenCalledExactlyOnceWith('dogdrip');
  });
});
