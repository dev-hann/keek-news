import { Inbox } from 'lucide-react';

export function EmptyStateView({ message }: { message: string }) {
  return (
    <div
      role="status"
      className="flex min-h-[60vh] flex-col items-center justify-center gap-4 p-6 text-center"
    >
      <Inbox aria-hidden="true" className="size-12 text-muted-foreground" />
      <p className="text-lg font-semibold">{message}</p>
    </div>
  );
}
