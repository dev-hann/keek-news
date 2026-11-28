import type { Community, CommunityId } from '../model/community';
import { cn } from 'cn';

interface CommunityTabBarProps {
  communities: readonly Community[];
  selectedId: CommunityId;
  onSelect: (id: CommunityId) => void;
}

/** One chip per community that is on. A chip names its community and says which one is shown. */
export function CommunityTabBar({ communities, selectedId, onSelect }: CommunityTabBarProps) {
  return (
    <div
      role="tablist"
      aria-label="커뮤니티"
      className="flex h-14 items-center gap-2 border-b border-border bg-card px-3"
    >
      {communities.map((community) => {
        const selected = community.id === selectedId;
        return (
          <button
            key={community.id}
            type="button"
            role="tab"
            aria-selected={selected}
            onClick={() => onSelect(community.id)}
            className={cn(
              'h-11 min-w-11 flex-1 truncate rounded-full border px-4 text-sm',
              selected
                ? 'font-semibold'
                : 'border-transparent bg-muted font-normal text-muted-foreground'
            )}
            style={
              selected
                ? {
                    borderColor: community.brandColor,
                    color: community.brandColor,
                    backgroundColor: `color-mix(in oklab, ${community.brandColor} 15%, transparent)`,
                  }
                : undefined
            }
          >
            {community.shortName}
          </button>
        );
      })}
    </div>
  );
}
