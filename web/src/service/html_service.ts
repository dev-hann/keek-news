/** Parses markup the way a browser does: scripts never run and nothing is loaded. */
export function parseHtml(html: string): Document {
  return new DOMParser().parseFromString(html, 'text/html');
}

/** `int.tryParse` of Dart: whitespace, an optional sign and digits, and nothing else. */
export function tryParseInt(text: string | null): number | null {
  if (text === null) return null;
  const match = /^\s*([+-]?\d+)\s*$/.exec(text);
  return match === null ? null : Number(match[1]);
}

/** Every digit of `text` read as one number, so `추천 (1,234)` is 1234. */
export function extractNumber(text: string | null): number {
  if (text === null) return 0;
  return tryParseInt(text.replace(/[^0-9]/g, '')) ?? 0;
}

export function textOf(element: Element | null): string {
  return (element?.textContent ?? '').trim();
}

export function attrOf(element: Element | null, name: string): string | null {
  return element?.getAttribute(name) ?? null;
}

export function statOf(parent: Element | null, selector: string): number {
  if (parent === null) return 0;
  return extractNumber(textOf(parent.querySelector(selector)));
}

/** First non-zero stat across `selectors`; 0 when every candidate misses or resolves to 0. Layer fallback selectors so a single community markup change does not break a field — the next candidate picks it up. */
export function statOfAny(parent: Element | null, selectors: readonly string[]): number {
  if (parent === null) return 0;
  for (const selector of selectors) {
    const value = extractNumber(textOf(parent.querySelector(selector)));
    if (value !== 0) return value;
  }
  return 0;
}

/** First matching element across `selectors`, or null when all miss. */
export function queryFirst(root: Element | null, selectors: readonly string[]): Element | null {
  if (root === null) return null;
  for (const selector of selectors) {
    const hit = root.querySelector(selector);
    if (hit !== null) return hit;
  }
  return null;
}

/** Trimmed text of the first hit across `selectors`; '' when all miss. */
export function textOfAny(root: Element | null, selectors: readonly string[]): string {
  return textOf(queryFirst(root, selectors));
}

/** First non-empty attribute across `selector`/`attr` pairs. Within each pair every matching element is examined so a single selector can host multiple candidates (e.g. several anchors, only some populated). */
export function attrOfAny(
  root: Element | null,
  pairs: readonly { selector: string; attr: string }[]
): string | null {
  if (root === null) return null;
  for (const { selector, attr } of pairs) {
    for (const el of root.querySelectorAll(selector)) {
      const value = el.getAttribute(attr);
      if (value !== null && value !== '') return value;
    }
  }
  return null;
}

export function extractBracketedInt(text: string | null): number {
  if (text === null) return 0;
  const match = /\[(\d+)\]/.exec(text);
  return match !== null ? Number(match[1]) : 0;
}

export function extractQueryParam(href: string, key: string): string | null {
  return new RegExp(`${key}=([^&#]+)`).exec(href)?.[1] ?? null;
}

export function toInt(value: unknown): number {
  // A Dart int is never -0 or NaN.
  if (typeof value === 'number') return Math.trunc(value) || 0;
  if (typeof value === 'string') return tryParseInt(value) ?? 0;
  return 0;
}
