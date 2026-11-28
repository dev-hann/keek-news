import { CircleAlert } from 'lucide-react';
import { Button } from '../components/ui/button';

interface ErrorStateViewProps {
  message: string;
  onRetry?: () => void;
}

export function ErrorStateView({ message, onRetry }: ErrorStateViewProps) {
  return (
    <div
      role="alert"
      className="flex min-h-[60vh] flex-col items-center justify-center gap-4 p-6 text-center"
    >
      <CircleAlert aria-hidden="true" className="size-12 text-destructive" />
      <p className="text-muted-foreground">{message}</p>
      {onRetry && (
        <Button type="button" variant="outline" className="h-11" onClick={onRetry}>
          다시 시도
        </Button>
      )}
    </div>
  );
}
