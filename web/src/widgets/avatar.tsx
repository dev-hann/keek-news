import { User } from 'lucide-react';
import { cn } from 'cn';

/** The writer of a post. Communities give no picture, so every writer has the same one. */
export function Avatar({ className }: { className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        'flex size-8 shrink-0 items-center justify-center rounded-full bg-muted text-muted-foreground',
        className
      )}
    >
      <User className="size-4" />
    </span>
  );
}
