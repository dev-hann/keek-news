import { useLayoutEffect, useRef, useState } from 'react';
import { LinkText } from './link_text';

interface ExpandableTextProps {
  text: string;
  /** Lines shown before the reader opens the text. */
  maxLines: number;
  className?: string;
}

/** Text cut off after `maxLines`, with 더보기 to open it and 접기 to close it again. */
export function ExpandableText({ text, maxLines, className }: ExpandableTextProps) {
  const [expanded, setExpanded] = useState(false);
  const [overflows, setOverflows] = useState(false);
  const body = useRef<HTMLParagraphElement>(null);

  // Measured while cut off: open, the text has no overflow left to measure,
  // and the last answer is what keeps the 접기 button in place.
  useLayoutEffect(() => {
    const element = body.current;
    if (expanded || !element) return;
    setOverflows(element.scrollHeight > element.clientHeight + 1);
  }, [text, maxLines, expanded]);

  return (
    <div className="min-w-0">
      <p
        ref={body}
        className={className}
        style={
          expanded
            ? undefined
            : {
                display: '-webkit-box',
                WebkitBoxOrient: 'vertical',
                WebkitLineClamp: maxLines,
                overflow: 'hidden',
              }
        }
      >
        <LinkText text={text} />
      </p>
      {overflows && (
        <button
          type="button"
          aria-expanded={expanded}
          onClick={() => setExpanded((open) => !open)}
          className="min-h-11 min-w-11 pt-0.5 text-sm font-semibold text-primary"
        >
          {expanded ? '접기' : '더보기'}
        </button>
      )}
    </div>
  );
}
