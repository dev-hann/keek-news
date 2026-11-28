import { ArrowUp } from 'lucide-react';
import { cn } from 'cn';
import { Button } from '../components/ui/button';

interface ScrollToTopButtonProps {
  visible: boolean;
  onClick: () => void;
}

export function ScrollToTopButton({ visible, onClick }: ScrollToTopButtonProps) {
  return (
    <Button
      type="button"
      variant="outline"
      size="icon"
      aria-label="맨 위로"
      title="맨 위로"
      tabIndex={visible ? 0 : -1}
      onClick={onClick}
      className={cn(
        'fixed right-4 bottom-6 z-10 size-11 rounded-full bg-card shadow-sm transition-opacity duration-100 ease-in-out motion-reduce:transition-none',
        visible ? 'opacity-100' : 'pointer-events-none opacity-0'
      )}
    >
      <ArrowUp aria-hidden="true" className="size-5" />
    </Button>
  );
}
