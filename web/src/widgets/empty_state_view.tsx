import { Inbox, type LucideIcon } from 'lucide-react';

interface EmptyStateViewProps {
  message: string;
  /** A line under the message: what there is to do about it. */
  hint?: string;
  /** What is missing. A list of anything shows an inbox. */
  icon?: LucideIcon;
}

export function EmptyStateView({ message, hint, icon: Icon = Inbox }: EmptyStateViewProps) {
  return (
    <div
      role="status"
      className="flex min-h-[60vh] flex-col items-center justify-center gap-4 p-6 text-center"
    >
      <Icon aria-hidden="true" className="size-12 text-muted-foreground" />
      <div className="flex flex-col gap-2">
        <p className="text-lg font-semibold">{message}</p>
        {hint && <p className="text-sm text-muted-foreground">{hint}</p>}
      </div>
    </div>
  );
}
