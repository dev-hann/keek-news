import { useMemo } from 'react';
import { cn } from 'cn';
import { parseLinkSegments } from '../utils/link_segments';

interface LinkTextProps {
  text: string;
  className?: string;
}

/** Text whose bare addresses are links. Each opens outside the app. */
export function LinkText({ text, className }: LinkTextProps) {
  const segments = useMemo(() => parseLinkSegments(text), [text]);

  return (
    <>
      {segments.map((segment, index) =>
        segment.url ? (
          <a
            key={index}
            href={segment.url}
            target="_blank"
            rel="noopener noreferrer"
            className={cn('break-all text-primary underline', className)}
          >
            {segment.text}
          </a>
        ) : (
          <span key={index}>{segment.text}</span>
        )
      )}
    </>
  );
}
