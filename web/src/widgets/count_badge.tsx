import type { LucideIcon } from 'lucide-react';
import { Eye, MessageCircle, ThumbsUp } from 'lucide-react';
import { cn } from 'cn';
import { Badge } from '../components/ui/badge';

// What it takes for a recommend count to stand out.
const RECOMMEND_TIERS = [
  { min: 100, className: 'font-bold text-[#e53935]' },
  { min: 50, className: 'font-semibold text-[#43a047]' },
  { min: 10, className: 'font-medium text-[#ff6d00]' },
] as const;

function recommendClassName(count: number): string {
  return RECOMMEND_TIERS.find((tier) => count >= tier.min)?.className ?? 'text-[#9e9e9e]';
}

interface CountBadgeProps {
  count: number;
  icon: LucideIcon;
  className?: string;
}

function CountBadge({ count, icon: Icon, className }: CountBadgeProps) {
  return (
    <span className={cn('inline-flex items-center gap-1 text-sm tabular-nums', className)}>
      <Icon aria-hidden="true" className="size-4" />
      {count}
    </span>
  );
}

export function RecommendBadge({ count }: { count: number }) {
  return <CountBadge count={count} icon={ThumbsUp} className={recommendClassName(count)} />;
}

export function CommentBadge({ count }: { count: number }) {
  return <CountBadge count={count} icon={MessageCircle} className="text-muted-foreground" />;
}

export function ViewBadge({ count }: { count: number }) {
  return <CountBadge count={count} icon={Eye} className="text-muted-foreground" />;
}

/** A post with 500 recommends or more. */
export function BestBadge() {
  return (
    <Badge className="rounded bg-[#e53935] px-2 py-0.5 text-xs font-bold text-white">BEST</Badge>
  );
}
