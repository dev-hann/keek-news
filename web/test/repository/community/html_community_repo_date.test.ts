import { describe, expect, it } from 'vitest';
import { HumorunivImpl } from '../../../src/repository/community/humoruniv/humoruniv_impl';

// HumorunivImpl is only used as a concrete carrier of the shared
// parseDatePattern helper; no fixture data is fetched.
const repo = new HumorunivImpl({ get: () => Promise.reject(new Error('no http')) });

describe('HtmlCommunityRepo.parseDatePattern', () => {
  it('parses full date-time with 6 groups', () => {
    const date = repo.parseDatePattern(
      '2026-08-14 09:30:15',
      /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/
    );
    expect(date).toEqual(new Date(2026, 7, 14, 9, 30, 15));
  });

  it('resolves two-digit years against 2000 when year2 is set', () => {
    const date = repo.parseDatePattern(
      '26/08/14 09:30',
      /(\d{2})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})/,
      {
        year2: true,
      }
    );
    expect(date).toEqual(new Date(2026, 7, 14, 9, 30));
  });

  it('date-only patterns zero the time components', () => {
    const date = repo.parseDatePattern('2026.08.14', /(\d{4})\.(\d{2})\.(\d{2})/);
    expect(date).toEqual(new Date(2026, 7, 14));
  });

  it('null groups inside an optional time section become 0', () => {
    const date = repo.parseDatePattern(
      '2026-08-14',
      /(\d{4})-(\d{1,2})-(\d{1,2})(?:[^\d]*?(\d{1,2}):(\d{2}):(\d{2}))?/
    );
    expect(date).toEqual(new Date(2026, 7, 14));
  });

  it('returns null when the pattern does not match', () => {
    const date = repo.parseDatePattern('no date here', /(\d{4})-(\d{2})-(\d{2})/);
    expect(date).toBeNull();
  });
});
