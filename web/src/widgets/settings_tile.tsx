import type { ReactNode } from 'react';
import { cn } from 'cn';

interface SettingsTileProps {
  title: string;
  subtitle?: string;
  leading?: ReactNode;
  trailing?: ReactNode;
  onClick?: () => void;
  /** An address outside the app, which opens in the browser. */
  href?: string;
  /** An action that throws something away: its icon and title are in the error color. */
  destructive?: boolean;
}

/** One row of a settings group: an icon, a title with an optional line under it, something at the end. */
export function SettingsTile({
  title,
  subtitle,
  leading,
  trailing,
  onClick,
  href,
  destructive = false,
}: SettingsTileProps) {
  const content = (
    <>
      {leading && (
        <span
          aria-hidden="true"
          className={cn('shrink-0', destructive ? 'text-destructive' : 'text-foreground')}
        >
          {leading}
        </span>
      )}
      <span className="min-w-0 flex-1">
        <span className={cn('block', destructive && 'text-destructive')}>{title}</span>
        {subtitle && (
          <span className="mt-0.5 block text-sm break-words text-muted-foreground">{subtitle}</span>
        )}
      </span>
      {trailing}
    </>
  );
  const row = 'flex min-h-12 w-full items-center gap-3 px-4 py-3 text-left text-base';

  if (href) {
    return (
      <a
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        className={cn(row, 'hover:bg-muted')}
      >
        {content}
      </a>
    );
  }
  if (onClick) {
    return (
      <button type="button" onClick={onClick} className={cn(row, 'hover:bg-muted')}>
        {content}
      </button>
    );
  }
  return <div className={row}>{content}</div>;
}
