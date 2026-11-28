import { describe, expect, it } from 'vitest';
import {
  type Bookmark,
  bookmarkFromFeedItem,
  bookmarkFromJson,
  bookmarkKey,
  bookmarkToJson,
} from '../../src/model/bookmark';
import { feedItemFromBookmark, type FeedItem } from '../../src/model/feed_item';

describe('Bookmark', () => {
  it('should create with required fields and savedAt', () => {
    // A plain object has no constructor to default the counts: they are written out.
    const savedAt = new Date(2026, 6, 30, 10);
    const bookmark: Bookmark = {
      community: 'humoruniv',
      id: '100',
      title: '제목',
      url: '/board/read.html?table=pds&number=100',
      savedAt,
      recommendCount: 0,
      commentCount: 0,
      viewCount: 0,
    };

    expect(bookmark.community).toBe('humoruniv');
    expect(bookmark.id).toBe('100');
    expect(bookmark.title).toBe('제목');
    expect(bookmark.url).toBe('/board/read.html?table=pds&number=100');
    expect(bookmark.author).toBeUndefined();
    expect(bookmark.thumbnailUrl).toBeUndefined();
    expect(bookmark.publishedAt).toBeUndefined();
    expect(bookmark.recommendCount).toBe(0);
    expect(bookmark.commentCount).toBe(0);
    expect(bookmark.viewCount).toBe(0);
    expect(bookmark.savedAt).toEqual(savedAt);
  });

  it('should support value equality when all fields match', () => {
    const savedAt = new Date(2026, 6, 30, 10);
    const a: Bookmark = {
      community: 'humoruniv',
      id: '1',
      title: 't',
      url: 'u',
      author: 'writer',
      thumbnailUrl: 'thumb',
      publishedAt: new Date(2026, 5, 28),
      recommendCount: 5,
      commentCount: 3,
      viewCount: 100,
      savedAt,
    };
    const b: Bookmark = {
      community: 'humoruniv',
      id: '1',
      title: 't',
      url: 'u',
      author: 'writer',
      thumbnailUrl: 'thumb',
      publishedAt: new Date(2026, 5, 28),
      recommendCount: 5,
      commentCount: 3,
      viewCount: 100,
      savedAt,
    };

    expect(a).toStrictEqual(b);
    // A plain object has no hashCode. Where a bookmark keys a collection, its composite key stands in.
    expect(bookmarkKey(a)).toBe(bookmarkKey(b));
  });

  it('should not be equal when community differs', () => {
    const savedAt = new Date(2026, 6, 30);
    const a: Bookmark = {
      community: 'humoruniv',
      id: '1',
      title: 't',
      url: 'u',
      savedAt,
      recommendCount: 0,
      commentCount: 0,
      viewCount: 0,
    };
    const b: Bookmark = { ...a, community: 'todayhumor' };

    expect(a).not.toStrictEqual(b);
  });

  it('should not be equal when id differs', () => {
    const savedAt = new Date(2026, 6, 30);
    const a: Bookmark = {
      community: 'humoruniv',
      id: '1',
      title: 't',
      url: 'u',
      savedAt,
      recommendCount: 0,
      commentCount: 0,
      viewCount: 0,
    };
    const b: Bookmark = { ...a, id: '2' };

    expect(a).not.toStrictEqual(b);
  });

  it('should not be equal when savedAt differs', () => {
    const a: Bookmark = {
      community: 'humoruniv',
      id: '1',
      title: 't',
      url: 'u',
      savedAt: new Date(2026, 6, 30, 10),
      recommendCount: 0,
      commentCount: 0,
      viewCount: 0,
    };
    const b: Bookmark = { ...a, savedAt: new Date(2026, 6, 30, 11) };

    expect(a).not.toStrictEqual(b);
  });

  it('should produce stable composite key from community and id', () => {
    const bookmark: Bookmark = {
      community: 'dogdrip',
      id: '42',
      title: 't',
      url: 'u',
      savedAt: new Date(2026, 6, 30),
      recommendCount: 0,
      commentCount: 0,
      viewCount: 0,
    };

    expect(bookmarkKey(bookmark)).toBe('dogdrip:42');
  });

  it('fromFeedItem copies every mapped field and stamps savedAt', () => {
    const savedAt = new Date(2026, 6, 30, 10);
    const item: FeedItem = {
      community: 'dogdrip',
      id: '42',
      title: 't',
      url: 'u',
      author: 'w',
      thumbnailUrl: 'th',
      publishedAt: new Date(2026, 5, 28),
      recommendCount: 5,
      commentCount: 3,
      viewCount: 10,
    };

    const bookmark = bookmarkFromFeedItem(item, savedAt);

    expect(bookmark.community).toBe('dogdrip');
    expect(bookmark.id).toBe('42');
    expect(bookmark.title).toBe('t');
    expect(bookmark.url).toBe('u');
    expect(bookmark.author).toBe('w');
    expect(bookmark.thumbnailUrl).toBe('th');
    expect(bookmark.publishedAt).toEqual(new Date(2026, 5, 28));
    expect(bookmark.recommendCount).toBe(5);
    expect(bookmark.commentCount).toBe(3);
    expect(bookmark.viewCount).toBe(10);
    expect(bookmark.savedAt).toEqual(savedAt);
  });

  it('fromFeedItem/fromBookmark round-trips', () => {
    const item: FeedItem = {
      community: 'humoruniv',
      id: '1',
      title: 't',
      url: 'u',
      author: 'w',
      publishedAt: new Date(2026, 5, 28),
      recommendCount: 1,
      commentCount: 2,
      viewCount: 3,
      thumbnailUrl: 'th',
    };

    const roundTripped = feedItemFromBookmark(bookmarkFromFeedItem(item, new Date(2026, 6, 30)));

    expect(roundTripped).toStrictEqual(item);
  });
});

describe('Bookmark.fromJson', () => {
  it('should deserialize all fields', () => {
    const json = {
      community: 'humoruniv',
      id: '100',
      title: '제목',
      url: '/u',
      savedAtMillis: 1722324000000,
      author: 'writer',
      thumbnailUrl: 'thumb',
      publishedAtMillis: 1722240000000,
      recommendCount: 5,
      commentCount: 3,
      viewCount: 100,
    };

    const b = bookmarkFromJson(json);

    expect(b.community).toBe('humoruniv');
    expect(b.id).toBe('100');
    expect(b.title).toBe('제목');
    expect(b.url).toBe('/u');
    expect(b.savedAt.getTime()).toBe(1722324000000);
    expect(b.author).toBe('writer');
    expect(b.thumbnailUrl).toBe('thumb');
    expect(b.publishedAt?.getTime()).toBe(1722240000000);
    expect(b.recommendCount).toBe(5);
    expect(b.commentCount).toBe(3);
    expect(b.viewCount).toBe(100);
  });

  it('should default counts to 0 when missing', () => {
    const b = bookmarkFromJson({
      community: 'humoruniv',
      id: '1',
      title: 't',
      url: 'u',
      savedAtMillis: 0,
    });

    expect(b.recommendCount).toBe(0);
    expect(b.commentCount).toBe(0);
    expect(b.viewCount).toBe(0);
    expect(b.publishedAt).toBeUndefined();
  });

  it('should round-trip via toJson', () => {
    const original: Bookmark = {
      community: 'dogdrip',
      id: '42',
      title: 't',
      url: 'u',
      author: 'w',
      thumbnailUrl: 'th',
      publishedAt: new Date(2026, 5, 28),
      recommendCount: 5,
      commentCount: 3,
      viewCount: 10,
      savedAt: new Date(2026, 6, 30),
    };

    const roundTripped = bookmarkFromJson(bookmarkToJson(original));

    expect(roundTripped).toStrictEqual(original);
  });
});

describe('Bookmark.toJson', () => {
  // The Flutter app moves what it saved into this app, so what is stored must
  // stay what `jsonEncode(bookmark.toJson())` wrote there. Both texts below are
  // that function's output for these bookmarks.
  it('should store the JSON the Flutter app stored', () => {
    const savedAt = new Date(1722324000000);

    expect(
      JSON.stringify(
        bookmarkToJson({
          community: 'humoruniv',
          id: '100',
          title: '제목',
          url: '/u',
          savedAt,
          author: 'writer',
          thumbnailUrl: 'thumb',
          publishedAt: new Date(1722240000000),
          recommendCount: 5,
          commentCount: 3,
          viewCount: 100,
        })
      )
    ).toBe(
      '{"community":"humoruniv","id":"100","title":"제목","url":"/u","savedAtMillis":1722324000000,"author":"writer","thumbnailUrl":"thumb","publishedAtMillis":1722240000000,"recommendCount":5,"commentCount":3,"viewCount":100}'
    );
    expect(
      JSON.stringify(
        bookmarkToJson({
          community: 'humoruniv',
          id: '100',
          title: '제목',
          url: '/u',
          savedAt,
          recommendCount: 0,
          commentCount: 0,
          viewCount: 0,
        })
      )
    ).toBe(
      '{"community":"humoruniv","id":"100","title":"제목","url":"/u","savedAtMillis":1722324000000,"recommendCount":0,"commentCount":0,"viewCount":0}'
    );
  });
});
