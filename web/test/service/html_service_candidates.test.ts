// @vitest-environment jsdom
import { describe, expect, it } from 'vitest';
import {
  attrOfAny,
  parseHtml,
  queryFirst,
  statOfAny,
  textOfAny,
} from '../../src/service/html_service';

const root = (html: string): Element => parseHtml(html).body!;

describe('queryFirst — fallback chain', () => {
  it('returns null when root is null', () => {
    expect(queryFirst(null, ['.x', '.y'])).toBeNull();
  });

  it('returns null when every candidate misses', () => {
    const el = root('<div><p class="a">1</p></div>');
    expect(queryFirst(el, ['.x', '.y', '.z'])).toBeNull();
  });

  it('returns the first hit, skipping leading misses', () => {
    const el = root('<div><p class="a">1</p><p class="b">2</p></div>');
    const hit = queryFirst(el, ['.miss', '.b', '.a']);
    expect(hit?.textContent).toBe('2');
  });
});

describe('textOfAny — first non-empty wins', () => {
  it('empty when all selectors miss', () => {
    expect(textOfAny(root('<div></div>'), ['.x', '.y'])).toBe('');
  });

  it('skips leading misses and trims the hit', () => {
    const el = root('<div><span>  hello  </span></div>');
    expect(textOfAny(el, ['.miss', 'span', 'div'])).toBe('hello');
  });
});

describe('statOfAny — first non-zero wins', () => {
  it('zero when parent is null', () => {
    expect(statOfAny(null, ['.x'])).toBe(0);
  });

  it('zero when every candidate resolves to 0', () => {
    const el = root('<div><p>0</p><p>0</p></div>');
    expect(statOfAny(el, ['p', 'p'])).toBe(0);
  });

  it('skips leading zero candidates and returns the first non-zero', () => {
    const el = root('<div><p class="zero">0</p><p class="hit">42</p><p class="later">1</p></div>');
    expect(statOfAny(el, ['.zero', '.hit', '.later'])).toBe(42);
  });

  it('extracts digits from noisy text', () => {
    const el = root('<div><span>추천 (1,234)</span></div>');
    expect(statOfAny(el, ['span'])).toBe(1234);
  });
});

describe('attrOfAny — first non-empty attribute wins', () => {
  it('null when root is null', () => {
    expect(attrOfAny(null, [{ selector: '.x', attr: 'href' }])).toBeNull();
  });

  it('null when every pair misses', () => {
    const el = root('<div><a></a></div>');
    expect(
      attrOfAny(el, [
        { selector: 'a', attr: 'href' },
        { selector: '.x', attr: 'data-id' },
      ])
    ).toBeNull();
  });

  it('returns first non-empty attribute across pairs', () => {
    const el = root('<div><a href="">empty</a><a href="/r/42">hit</a></div>');
    expect(
      attrOfAny(el, [
        { selector: '.miss', attr: 'href' },
        { selector: 'a', attr: 'href' },
      ])
    ).toBe('/r/42');
  });
});
