import type { ReactNode } from 'react';
import { ArrowLeft } from 'lucide-react';
import { cn } from 'cn';
import { Button } from '../components/ui/button';

interface AppBarProps {
  title: string;
  /** What a tap on the title does. Without it the title is plain text. */
  onTitleTap?: () => void;
  /** Where the back arrow goes. Without it there is no back arrow. */
  onBack?: () => void;
  actions?: ReactNode;
}

/** The bar at the top of a screen: a title, and at most a back arrow and a few actions. */
export function AppBar({ title, onTitleTap, onBack, actions }: AppBarProps) {
  return (
    <header className="sticky top-0 z-20 flex h-14 items-center gap-1 border-b border-border bg-card px-2">
      {onBack && (
        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-label="뒤로"
          onClick={onBack}
          className={cn('size-11', !onTitleTap && 'ml-[-4px]')}
        >
          <ArrowLeft aria-hidden="true" className="size-5" />
        </Button>
      )}
      <h1 className="min-w-0 flex-1 text-base font-semibold">
        {onTitleTap ? (
          <button
            type="button"
            onClick={onTitleTap}
            className="min-h-11 max-w-full truncate px-2 text-left"
          >
            {title}
          </button>
        ) : (
          <span className={cn('block truncate px-2', !onBack && 'pl-4')}>{title}</span>
        )}
      </h1>
      {actions}
    </header>
  );
}
