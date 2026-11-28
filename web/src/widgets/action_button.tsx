import type { LucideIcon } from 'lucide-react';
import { cn } from 'cn';
import { Button } from '../components/ui/button';

interface ActionButtonProps {
  icon: LucideIcon;
  /** What the button does, for a screen reader. */
  label: string;
  onClick?: () => void;
  /** For a button that is in one of two states, saved or not: which one it is in. */
  pressed?: boolean;
}

/** An icon-only button with a 44px target. */
export function ActionButton({ icon: Icon, label, onClick, pressed }: ActionButtonProps) {
  return (
    <Button
      type="button"
      variant="ghost"
      size="icon"
      aria-label={label}
      aria-pressed={pressed}
      onClick={onClick}
      className={cn('size-11', pressed ? 'text-primary' : 'text-muted-foreground')}
    >
      <Icon aria-hidden="true" className="size-4" />
    </Button>
  );
}
