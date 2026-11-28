import { useEffect, useState } from 'react';

export type LoadState = 'loading' | 'loaded' | 'failed';

interface LoadResult {
  /** The image and the attempt the answer is for. */
  key: string;
  state: Exclude<LoadState, 'loading'>;
}

/** Where loading the image at `src` stands, and a way to ask for it again. */
export function useImageLoader(src: string): [LoadState, () => void] {
  const [attempt, setAttempt] = useState(0);
  const [result, setResult] = useState<LoadResult | null>(null);
  const key = `${src}#${attempt}`;
  const state: LoadState = result?.key === key ? result.state : 'loading';

  useEffect(() => {
    let current = true;
    // Loaded off the page: the box keeps its shape until the size of the image is known.
    const image = new Image();
    image.referrerPolicy = 'no-referrer';
    image.onload = () => {
      if (current) setResult({ key, state: 'loaded' });
    };
    image.onerror = () => {
      if (current) setResult({ key, state: 'failed' });
    };
    image.src = src;
    return () => {
      current = false;
    };
  }, [key, src]);

  return [state, () => setAttempt((count) => count + 1)];
}
