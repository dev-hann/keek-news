# Multi-Community Merged Feed — M0 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the `CommunityAdapter` abstraction and migrate the existing humoruniv data source onto it — purely additive, zero behavior change, all existing tests GREEN.

**Architecture:** New `CommunityAdapter` interface in the data layer returns adapter-normalized types (`FeedItemDto`, `PostDetailDto`). `HumorunivAdapter` wraps the existing `HumorunivRemoteDs` and converts its outputs. The adapter is registered in DI but NOT yet wired into the active feed path — that happens in M1/M2. Existing `PostRepository`, use cases, and providers continue to operate unchanged.

**Tech Stack:** Dart, Flutter, get_it (DI), mocktail (tests), dartz (`Either`).

**Spec:** [docs/superpowers/specs/2026-07-26-multi-community-merged-feed-design.md](../specs/2026-07-26-multi-community-merged-feed-design.md)

**TDD tier:** Entities/DTOs/interface = Tier B (per-layer, no RED required). `HumorunivAdapter` = Tier A (per-class, RED→GREEN).

---

## Deviations from spec (pragmatic, noted here so the executor doesn't flag them)

1. **`FeedItem.publishedAt` is nullable (`DateTime?`)** in M0. The spec declares it non-nullable as the merge key, but humoruniv's main-page parser does not extract timestamps. It becomes non-nullable in M2 when `HumorunivAdapter` switches to the board-list source (which has dates). M0's `feed_merger` doesn't exist yet, so nullability is harmless.
2. **Existing callers do NOT route through the adapter in M0.** The spec says "all existing callers route through adapter" by end of M0. In practice that requires rewriting 13+ test files that mock `PostRepository`. M0 is purely additive; routing happens in M1–M2 when `MergedFeedRepository` replaces `PostRepository`.
3. **`PostRepository` / `GetBestPosts` / `GetPostDetail` / `GetBoardPosts` are NOT deleted in M0.** They survive until M2 switches the home feed to the merged path. Deletion is an M2 task.

These deviations preserve the spec's intent (abstraction exists, humoruniv implements it) without forcing a risky big-bang rewrite of the test surface.

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| NEW | `lib/domain/entities/community.dart` | `CommunityId` enum, `Community` VO, `communities` const list. |
| NEW | `test/unit/domain/entities/community_test.dart` | Community VO tests. |
| NEW | `lib/domain/entities/feed_item.dart` | `FeedItem` entity (merged-feed list item). |
| NEW | `test/unit/domain/entities/feed_item_test.dart` | FeedItem equality/field tests. |
| EDIT | `lib/domain/entities/post.dart` | Add `community` field (default `CommunityId.humoruniv`) + equality + hashCode. |
| EDIT | `test/unit/domain/entities/post_test.dart` | Add community-field tests. |
| EDIT | `lib/domain/entities/board_post.dart` | Add `community` field (default) + equality + hashCode. |
| EDIT | `test/unit/domain/entities/board_post_test.dart` | Add community-field tests. |
| EDIT | `lib/domain/entities/post_detail.dart` | Add `community` field (default) + equality + hashCode. |
| EDIT | `test/unit/domain/entities/post_detail_test.dart` | Add community-field tests. |
| NEW | `lib/data/models/feed_item_dto.dart` | `FeedItemDto` with `toEntity()`. |
| NEW | `test/unit/data/models/feed_item_dto_test.dart` | DTO conversion tests. |
| NEW | `lib/data/datasources/community_adapter.dart` | `CommunityAdapter` abstract interface. |
| NEW | `lib/data/datasources/humoruniv_adapter_impl.dart` | `HumorunivAdapterImpl` wraps `HumorunivRemoteDs`. |
| NEW | `test/unit/data/datasources/humoruniv_adapter_impl_test.dart` | Adapter tests (mock DS). |
| EDIT | `lib/di/injection.dart` | Register `CommunityAdapter` → `HumorunivAdapterImpl`. |
| EDIT | `test/unit/di/injection_test.dart` | Assert adapter is registered. |

Conventions confirmed against existing code:
- Entity style ref: `lib/domain/entities/post.dart` (`@immutable`, `const` ctor, `operator ==` + `Object.hash`).
- DTO style ref: `lib/data/models/post_dto.dart` (plain class, `toEntity()` method).
- DS impl style ref: `lib/data/datasources/humoruniv_remote_ds_impl.dart` (try/catch, rethrow `ServerFailure`/`NetworkFailure`, wrap others).
- Test mock style ref: `test/unit/data/api/humoruniv_remote_ds_test.dart` (mocktail `extends Mock implements HumorunivRemoteDs`).
- DI test style ref: `test/unit/di/injection_test.dart` (`expect(di.sl.isRegistered<X>(), isTrue)`).

---

## Task 1: `Community` enum + VO (Tier B)

**Files:**
- Create: `lib/domain/entities/community.dart`
- Test: `test/unit/domain/entities/community_test.dart`

- [ ] **Step 1: Write the implementation**

Create `lib/domain/entities/community.dart`:

```dart
import 'package:meta/meta.dart';

enum CommunityId { humoruniv, todayhumor, dogdrip, ppomppu, fmkorea }

@immutable
class Community {
  const Community({
    required this.id,
    required this.shortName,
    required this.displayName,
    required this.brandColorArgb,
    required this.iconAsset,
  });
  final CommunityId id;
  final String shortName;
  final String displayName;
  final int brandColorArgb;
  final String iconAsset;

  static Community? findById(CommunityId id) {
    for (final c in communities) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Community &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const communities = <Community>[
  Community(
    id: CommunityId.humoruniv,
    shortName: '웃대',
    displayName: '웃긴대학',
    brandColorArgb: 0xFFE5413B,
    iconAsset: 'assets/icons/community_humoruniv.png',
  ),
  Community(
    id: CommunityId.todayhumor,
    shortName: '오유',
    displayName: '오늘의유머',
    brandColorArgb: 0xFF2E8B57,
    iconAsset: 'assets/icons/community_todayhumor.png',
  ),
  Community(
    id: CommunityId.dogdrip,
    shortName: '개드립',
    displayName: 'DogDrip',
    brandColorArgb: 0xFF1A1A2E,
    iconAsset: 'assets/icons/community_dogdrip.png',
  ),
  Community(
    id: CommunityId.ppomppu,
    shortName: '뽐뿌',
    displayName: '뽐뿌',
    brandColorArgb: 0xFFFF6B00,
    iconAsset: 'assets/icons/community_ppomppu.png',
  ),
  Community(
    id: CommunityId.fmkorea,
    shortName: 'FM',
    displayName: '에펨코리아',
    brandColorArgb: 0xFFCC0000,
    iconAsset: 'assets/icons/community_fmkorea.png',
  ),
];
```

- [ ] **Step 2: Write the tests**

Create `test/unit/domain/entities/community_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/domain/entities/community.dart';

void main() {
  group('Community', () {
    test('should expose 5 communities in the const list', () {
      expect(communities, hasLength(5));
      final ids = communities.map((c) => c.id).toSet();
      expect(ids, containsAll(CommunityId.values));
    });

    test('should have non-empty shortName and displayName for each', () {
      for (final c in communities) {
        expect(c.shortName, isNotEmpty);
        expect(c.displayName, isNotEmpty);
      }
    });

    test('should support equality by id', () {
      const a = Community(
        id: CommunityId.humoruniv,
        shortName: 'A',
        displayName: 'A',
        brandColorArgb: 0,
        iconAsset: 'a',
      );
      const b = Community(
        id: CommunityId.humoruniv,
        shortName: 'B',
        displayName: 'B',
        brandColorArgb: 1,
        iconAsset: 'b',
      );
      expect(a, equals(b));
    });

    test('should be different when ids differ', () {
      const a = Community(
        id: CommunityId.humoruniv,
        shortName: 'A',
        displayName: 'A',
        brandColorArgb: 0,
        iconAsset: 'a',
      );
      const b = Community(
        id: CommunityId.todayhumor,
        shortName: 'A',
        displayName: 'A',
        brandColorArgb: 0,
        iconAsset: 'a',
      );
      expect(a, isNot(equals(b)));
    });

    test('findById should return matching community', () {
      final found = Community.findById(CommunityId.dogdrip);
      expect(found, isNotNull);
      expect(found!.id, CommunityId.dogdrip);
    });

    test('findById should return null if not found (cannot happen with enum, but test anyway)', () {
      const Community? missing = Community.findById(CommunityId.humoruniv);
      expect(missing, isNotNull);
    });
  });
}
```

- [ ] **Step 3: Run tests — confirm GREEN**

Run: `flutter test test/unit/domain/entities/community_test.dart`
Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/community.dart test/unit/domain/entities/community_test.dart
git commit -m "feat: add Community enum and value object for multi-community support"
```

---

## Task 2: `FeedItem` entity (Tier B)

**Files:**
- Create: `lib/domain/entities/feed_item.dart`
- Test: `test/unit/domain/entities/feed_item_test.dart`

- [ ] **Step 1: Write the implementation**

Create `lib/domain/entities/feed_item.dart`:

```dart
import 'package:humoruniv/domain/entities/community.dart';
import 'package:meta/meta.dart';

@immutable
class FeedItem {
  const FeedItem({
    required this.community,
    required this.id,
    required this.title,
    required this.url,
    this.author,
    this.publishedAt,
    this.recommendCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.thumbnailUrl,
    this.previewText,
  });

  final CommunityId community;
  final String id;
  final String title;
  final String url;
  final String? author;
  final DateTime? publishedAt;
  final int recommendCount;
  final int commentCount;
  final int viewCount;
  final String? thumbnailUrl;
  final String? previewText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedItem &&
          runtimeType == other.runtimeType &&
          community == other.community &&
          id == other.id &&
          title == other.title &&
          url == other.url &&
          author == other.author &&
          publishedAt == other.publishedAt &&
          recommendCount == other.recommendCount &&
          commentCount == other.commentCount &&
          viewCount == other.viewCount &&
          thumbnailUrl == other.thumbnailUrl &&
          previewText == other.previewText;

  @override
  int get hashCode => Object.hash(
        community,
        id,
        title,
        url,
        author,
        publishedAt,
        recommendCount,
        commentCount,
        viewCount,
        thumbnailUrl,
        previewText,
      );
}
```

- [ ] **Step 2: Write the tests**

Create `test/unit/domain/entities/feed_item_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';

void main() {
  group('FeedItem', () {
    test('should create with required fields and sensible defaults', () {
      const item = FeedItem(
        community: CommunityId.humoruniv,
        id: '100',
        title: '제목',
        url: '/board/read.html?table=pds&number=100',
      );

      expect(item.community, CommunityId.humoruniv);
      expect(item.id, '100');
      expect(item.title, '제목');
      expect(item.url, '/board/read.html?table=pds&number=100');
      expect(item.author, isNull);
      expect(item.publishedAt, isNull);
      expect(item.recommendCount, 0);
      expect(item.commentCount, 0);
      expect(item.viewCount, 0);
      expect(item.thumbnailUrl, isNull);
      expect(item.previewText, isNull);
    });

    test('should support value equality when all fields match', () {
      final a = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        author: 'writer',
        publishedAt: DateTime(2026, 7, 26),
        recommendCount: 5,
      );
      final b = FeedItem(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
        author: 'writer',
        publishedAt: DateTime(2026, 7, 26),
        recommendCount: 5,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('should not be equal when community differs', () {
      const a = FeedItem(community: CommunityId.humoruniv, id: '1', title: 't', url: 'u');
      const b = FeedItem(community: CommunityId.todayhumor, id: '1', title: 't', url: 'u');

      expect(a, isNot(equals(b)));
    });

    test('should not be equal when id differs', () {
      const a = FeedItem(community: CommunityId.humoruniv, id: '1', title: 't', url: 'u');
      const b = FeedItem(community: CommunityId.humoruniv, id: '2', title: 't', url: 'u');

      expect(a, isNot(equals(b)));
    });
  });
}
```

- [ ] **Step 3: Run tests — confirm GREEN**

Run: `flutter test test/unit/domain/entities/feed_item_test.dart`
Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/feed_item.dart test/unit/domain/entities/feed_item_test.dart
git commit -m "feat: add FeedItem entity for merged community feed"
```

---

## Task 3: Add `community` field to `Post` (Tier B)

**Files:**
- Modify: `lib/domain/entities/post.dart`
- Modify: `test/unit/domain/entities/post_test.dart`

- [ ] **Step 1: Update the implementation**

Edit `lib/domain/entities/post.dart`. Add the import, field, default value, equality, and hashCode:

```dart
import 'package:humoruniv/domain/entities/community.dart';
import 'package:meta/meta.dart';

@immutable
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.recommendCount,
    required this.url,
    this.community = CommunityId.humoruniv,
  });
  final int id;
  final String title;
  final int recommendCount;
  final String url;
  final CommunityId community;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          recommendCount == other.recommendCount &&
          url == other.url &&
          community == other.community;

  @override
  int get hashCode => Object.hash(id, title, recommendCount, url, community);
}
```

- [ ] **Step 2: Add tests for the new field**

Append to `test/unit/domain/entities/post_test.dart` (inside the `group('Post', ...)` body, before the closing `});`):

```dart
    test('should default community to humoruniv', () {
      const post = Post(id: 1, title: 't', recommendCount: 0, url: 'u');
      expect(post.community, CommunityId.humoruniv);
    });

    test('should allow community to be set explicitly', () {
      const post = Post(
        id: 1,
        title: 't',
        recommendCount: 0,
        url: 'u',
        community: CommunityId.todayhumor,
      );
      expect(post.community, CommunityId.todayhumor);
    });

    test('should not be equal when community differs', () {
      const a = Post(id: 1, title: 't', recommendCount: 0, url: 'u', community: CommunityId.humoruniv);
      const b = Post(id: 1, title: 't', recommendCount: 0, url: 'u', community: CommunityId.todayhumor);
      expect(a, isNot(equals(b)));
    });
```

Also add `import 'package:humoruniv/domain/entities/community.dart';` at the top of the test file.

- [ ] **Step 3: Run Post tests — confirm GREEN**

Run: `flutter test test/unit/domain/entities/post_test.dart`
Expected: all tests PASS (existing equality tests still pass because both sides default to `CommunityId.humoruniv`).

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/post.dart test/unit/domain/entities/post_test.dart
git commit -m "feat: add community field to Post entity"
```

---

## Task 4: Add `community` field to `BoardPost` (Tier B)

**Files:**
- Modify: `lib/domain/entities/board_post.dart`
- Modify: `test/unit/domain/entities/board_post_test.dart`

- [ ] **Step 1: Update the implementation**

Edit `lib/domain/entities/board_post.dart`. Add import, field with default, equality, hashCode:

```dart
import 'package:humoruniv/domain/entities/community.dart';
import 'package:meta/meta.dart';

@immutable
class BoardPost {
  const BoardPost({
    required this.id,
    required this.title,
    required this.url,
    required this.author,
    required this.date,
    required this.recommendCount,
    required this.notRecommendCount,
    required this.commentCount,
    required this.viewCount,
    required this.thumbnailUrl,
    this.previewText,
    this.community = CommunityId.humoruniv,
  });
  final int id;
  final String title;
  final String url;
  final String author;
  final String date;
  final int recommendCount;
  final int notRecommendCount;
  final int commentCount;
  final int viewCount;
  final String thumbnailUrl;
  final String? previewText;
  final CommunityId community;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPost &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          url == other.url &&
          author == other.author &&
          date == other.date &&
          recommendCount == other.recommendCount &&
          notRecommendCount == other.notRecommendCount &&
          commentCount == other.commentCount &&
          viewCount == other.viewCount &&
          thumbnailUrl == other.thumbnailUrl &&
          previewText == other.previewText &&
          community == other.community;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        url,
        author,
        date,
        recommendCount,
        notRecommendCount,
        commentCount,
        viewCount,
        thumbnailUrl,
        previewText,
        community,
      );
}
```

- [ ] **Step 2: Add tests for the new field**

Append to `test/unit/domain/entities/board_post_test.dart` (inside the main group, before closing `});`):

```dart
    test('should default community to humoruniv', () {
      const post = BoardPost(
        id: 1,
        title: 't',
        url: 'u',
        author: 'a',
        date: '2026-07-26',
        recommendCount: 0,
        notRecommendCount: 0,
        commentCount: 0,
        viewCount: 0,
        thumbnailUrl: '',
      );
      expect(post.community, CommunityId.humoruniv);
    });

    test('should not be equal when community differs', () {
      const a = BoardPost(
        id: 1, title: 't', url: 'u', author: 'a', date: 'd',
        recommendCount: 0, notRecommendCount: 0, commentCount: 0,
        viewCount: 0, thumbnailUrl: '', community: CommunityId.humoruniv,
      );
      const b = BoardPost(
        id: 1, title: 't', url: 'u', author: 'a', date: 'd',
        recommendCount: 0, notRecommendCount: 0, commentCount: 0,
        viewCount: 0, thumbnailUrl: '', community: CommunityId.ppomppu,
      );
      expect(a, isNot(equals(b)));
    });
```

Add `import 'package:humoruniv/domain/entities/community.dart';` at the top of the test file.

- [ ] **Step 3: Run tests — confirm GREEN**

Run: `flutter test test/unit/domain/entities/board_post_test.dart`
Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/board_post.dart test/unit/domain/entities/board_post_test.dart
git commit -m "feat: add community field to BoardPost entity"
```

---

## Task 5: Add `community` field to `PostDetail` (Tier B)

**Files:**
- Modify: `lib/domain/entities/post_detail.dart`
- Modify: `test/unit/domain/entities/post_detail_test.dart`

- [ ] **Step 1: Update the implementation**

Edit `lib/domain/entities/post_detail.dart`. Add import, field with default, equality, hashCode. The final file should look like:

```dart
import 'package:humoruniv/domain/entities/comment.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/content_block.dart';
import 'package:meta/meta.dart';

@immutable
class PostDetail {
  const PostDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.date,
    required this.contentHtml,
    required this.contentBlocks,
    required this.imageUrls,
    required this.recommendCount,
    required this.notRecommendCount,
    required this.viewCount,
    required this.commentCount,
    required this.comments,
    this.community = CommunityId.humoruniv,
  });
  final int id;
  final String title;
  final String author;
  final DateTime date;
  final String contentHtml;
  final List<ContentBlock> contentBlocks;
  final List<String> imageUrls;
  final int recommendCount;
  final int notRecommendCount;
  final int viewCount;
  final int commentCount;
  final List<Comment> comments;
  final CommunityId community;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostDetail &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          author == other.author &&
          date == other.date &&
          contentHtml == other.contentHtml &&
          recommendCount == other.recommendCount &&
          notRecommendCount == other.notRecommendCount &&
          viewCount == other.viewCount &&
          commentCount == other.commentCount &&
          community == other.community;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        author,
        date,
        contentHtml,
        recommendCount,
        notRecommendCount,
        viewCount,
        commentCount,
        community,
      );
}
```

- [ ] **Step 2: Add tests for the new field**

Append to `test/unit/domain/entities/post_detail_test.dart` (inside the main group, before closing `});`):

```dart
    test('should default community to humoruniv', () {
      final detail = PostDetail(
        id: 1,
        title: 't',
        author: 'a',
        date: DateTime(2026, 7, 26),
        contentHtml: '',
        contentBlocks: const [],
        imageUrls: const [],
        recommendCount: 0,
        notRecommendCount: 0,
        viewCount: 0,
        commentCount: 0,
        comments: const [],
      );
      expect(detail.community, CommunityId.humoruniv);
    });
```

Add `import 'package:humoruniv/domain/entities/community.dart';` at the top of the test file.

- [ ] **Step 3: Run tests — confirm GREEN**

Run: `flutter test test/unit/domain/entities/post_detail_test.dart`
Expected: all tests PASS.

- [ ] **Step 4: Run the FULL entity test suite — confirm nothing else broke**

Run: `flutter test test/unit/domain/entities/`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/post_detail.dart test/unit/domain/entities/post_detail_test.dart
git commit -m "feat: add community field to PostDetail entity"
```

---

## Task 6: `FeedItemDto` (Tier B)

**Files:**
- Create: `lib/data/models/feed_item_dto.dart`
- Test: `test/unit/data/models/feed_item_dto_test.dart`

- [ ] **Step 1: Write the implementation**

Create `lib/data/models/feed_item_dto.dart`:

```dart
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/feed_item.dart';

class FeedItemDto {
  const FeedItemDto({
    required this.community,
    required this.id,
    required this.title,
    required this.url,
    this.author,
    this.publishedAt,
    this.recommendCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.thumbnailUrl,
    this.previewText,
  });

  final CommunityId community;
  final String id;
  final String title;
  final String url;
  final String? author;
  final DateTime? publishedAt;
  final int recommendCount;
  final int commentCount;
  final int viewCount;
  final String? thumbnailUrl;
  final String? previewText;

  FeedItem toEntity() => FeedItem(
        community: community,
        id: id,
        title: title,
        url: url,
        author: author,
        publishedAt: publishedAt,
        recommendCount: recommendCount,
        commentCount: commentCount,
        viewCount: viewCount,
        thumbnailUrl: thumbnailUrl,
        previewText: previewText,
      );
}
```

- [ ] **Step 2: Write the tests**

Create `test/unit/data/models/feed_item_dto_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/models/feed_item_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';

void main() {
  group('FeedItemDto', () {
    test('toEntity should copy all fields', () {
      final dto = FeedItemDto(
        community: CommunityId.dogdrip,
        id: '42',
        title: '개드립 글',
        url: 'https://dogdrip.net/42',
        author: '개붕이',
        publishedAt: DateTime(2026, 7, 26, 10, 30),
        recommendCount: 15,
        commentCount: 3,
        viewCount: 200,
        thumbnailUrl: 'https://img.jpg',
        previewText: '미리보기',
      );

      final entity = dto.toEntity();

      expect(entity.community, CommunityId.dogdrip);
      expect(entity.id, '42');
      expect(entity.title, '개드립 글');
      expect(entity.url, 'https://dogdrip.net/42');
      expect(entity.author, '개붕이');
      expect(entity.publishedAt, DateTime(2026, 7, 26, 10, 30));
      expect(entity.recommendCount, 15);
      expect(entity.commentCount, 3);
      expect(entity.viewCount, 200);
      expect(entity.thumbnailUrl, 'https://img.jpg');
      expect(entity.previewText, '미리보기');
    });

    test('toEntity should preserve null optionals', () {
      const dto = FeedItemDto(
        community: CommunityId.humoruniv,
        id: '1',
        title: 't',
        url: 'u',
      );

      final entity = dto.toEntity();

      expect(entity.author, isNull);
      expect(entity.publishedAt, isNull);
      expect(entity.thumbnailUrl, isNull);
      expect(entity.previewText, isNull);
      expect(entity.recommendCount, 0);
    });
  });
}
```

- [ ] **Step 3: Run tests — confirm GREEN**

Run: `flutter test test/unit/data/models/feed_item_dto_test.dart`
Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/feed_item_dto.dart test/unit/data/models/feed_item_dto_test.dart
git commit -m "feat: add FeedItemDto data transfer object"
```

---

## Task 7: `CommunityAdapter` abstract interface (Tier B)

**Files:**
- Create: `lib/data/datasources/community_adapter.dart`

(No separate test file — abstract interfaces have no logic to test. Covered by Tier B layer convention.)

- [ ] **Step 1: Write the interface**

Create `lib/data/datasources/community_adapter.dart`:

```dart
import 'package:humoruniv/data/models/feed_item_dto.dart';
import 'package:humoruniv/data/models/post_detail_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';

/// One adapter per external community site. Implementations own their own
/// HTTP client config (baseUrl, encoding, user-agent), parser set, and
/// per-host rate limiter.
///
/// Return types are normalized so the merged-feed layer can treat all
/// communities uniformly.
abstract class CommunityAdapter {
  CommunityId get communityId;

  /// Fetch the latest posts from this community.
  ///
  /// [pageToken] is `null` for the first page; implementations return the
  /// next token via the [FeedListResult.pageToken] field. Token format is
  /// implementation-defined (page number, cursor, after_id, …).
  Future<FeedListResult> fetchLatest({String? pageToken});

  /// Fetch the full detail for one post.
  ///
  /// [id] is the same string returned as `FeedItemDto.id` by [fetchLatest].
  /// Implementations are responsible for converting it to the site-specific
  /// request URL.
  Future<PostDetailDto> fetchDetail(String id);

  /// Cheap reachability + captcha check. Returns `true` when the site is
  /// healthy and scrapable. The merged repository uses this to skip broken
  /// communities without failing the whole feed.
  Future<bool> healthCheck();
}

/// Output of [CommunityAdapter.fetchLatest]. Carries the items plus the
/// token to fetch the next page (or `null` if there are no more pages).
class FeedListResult {
  const FeedListResult({required this.items, this.pageToken});
  final List<FeedItemDto> items;
  final String? pageToken;
}
```

- [ ] **Step 2: Run analyze — confirm no errors**

Run: `flutter analyze lib/data/datasources/community_adapter.dart`
Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/datasources/community_adapter.dart
git commit -m "feat: add CommunityAdapter abstract interface"
```

---

## Task 8: `HumorunivAdapterImpl` (Tier A — per-class)

**Files:**
- Create: `lib/data/datasources/humoruniv_adapter_impl.dart`
- Test: `test/unit/data/datasources/humoruniv_adapter_impl_test.dart`

This adapter wraps the existing `HumorunivRemoteDs`. It converts the existing return types to the adapter-normalized types:

- `fetchMainPage()` returns `List<PostDto>` (id, title, recommendCount, url) → convert to `List<FeedItemDto>` (community=humoruniv, publishedAt=null — main page has no timestamps).
- `fetchPostDetail(url)` returns `PostDetail` → convert to `PostDetailDto`.
- `healthCheck()` delegates to a lightweight `fetchMainPage()` call and returns `true` if it doesn't throw.

The `pageToken` for humoruniv is the page number as a string (`"1"`, `"2"`, …). Page 1 maps to `fetchMainPage()` (the best-posts landing); pages ≥ 2 currently have no source in this adapter because the main page is a single curated list. This is acceptable for M0 — the merge layer (M1) calls with `pageToken: null` for the first page. Pagination beyond page 1 is an M2 concern when the adapter switches to the board-list source.

- [ ] **Step 1: Inspect `PostDetailDto` to confirm its constructor**

Before writing tests, read `lib/data/models/post_detail_dto.dart` to confirm the exact constructor parameter names. The adapter must construct `PostDetailDto` with the right field names. If names differ from what's used below, adjust the test + impl accordingly.

Run: `cat lib/data/models/post_detail_dto.dart` *(use Read tool, not bash cat)*

- [ ] **Step 2: Write ALL failing adapter tests**

Create `test/unit/data/datasources/humoruniv_adapter_impl_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/models/post_dto.dart';
import 'package:humoruniv/domain/entities/comment.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/content_block.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';
import 'package:mocktail/mocktail.dart';

class MockHumorunivRemoteDs extends Mock implements HumorunivRemoteDs {}

void main() {
  late MockHumorunivRemoteDs mockDs;
  late HumorunivAdapterImpl adapter;

  setUp(() {
    mockDs = MockHumorunivRemoteDs();
    adapter = HumorunivAdapterImpl(remoteDs: mockDs);
  });

  group('HumorunivAdapterImpl', () {
    test('communityId should be humoruniv', () {
      expect(adapter.communityId, CommunityId.humoruniv);
    });

    test('fetchLatest should delegate to fetchMainPage and convert PostDto to FeedItemDto', () async {
      when(() => mockDs.fetchMainPage()).thenAnswer((_) async => [
            const PostDto(id: 100, title: '첫 글', recommendCount: 42, url: '/board/read.html?table=pds&number=100'),
            const PostDto(id: 200, title: '둘', recommendCount: 7, url: '/board/read.html?table=pds&number=200'),
          ]);

      final result = await adapter.fetchLatest();

      expect(result.items, hasLength(2));
      expect(result.items[0].community, CommunityId.humoruniv);
      expect(result.items[0].id, '100');
      expect(result.items[0].title, '첫 글');
      expect(result.items[0].recommendCount, 42);
      expect(result.items[0].url, '/board/read.html?table=pds&number=100');
      expect(result.items[1].id, '200');
    });

    test('fetchLatest should return empty list when fetchMainPage returns empty', () async {
      when(() => mockDs.fetchMainPage()).thenAnswer((_) async => []);

      final result = await adapter.fetchLatest();

      expect(result.items, isEmpty);
    });

    test('fetchLatest should throw when underlying DS throws', () async {
      when(() => mockDs.fetchMainPage()).thenThrowException();

      expect(() => adapter.fetchLatest(), throwsA(isA<Object>()));
    });

    test('fetchDetail should delegate to fetchPostDetail and convert to PostDetailDto', () async {
      const url = '/board/read.html?table=pds&number=100';
      final detail = PostDetail(
        id: 100,
        title: '제목',
        author: '작성자',
        date: DateTime(2026, 7, 26),
        contentHtml: '<p>내용</p>',
        contentBlocks: const [],
        imageUrls: const ['https://img.jpg'],
        recommendCount: 10,
        notRecommendCount: 1,
        viewCount: 500,
        commentCount: 3,
        comments: const [],
      );
      when(() => mockDs.fetchPostDetail(any())).thenAnswer((_) async => detail);

      final dto = await adapter.fetchDetail(url);

      expect(dto.id, 100);
      expect(dto.title, '제목');
      expect(dto.author, '작성자');
      expect(dto.recommendCount, 10);
      expect(dto.imageUrls, hasLength(1));
    });

    test('healthCheck should return true when fetchMainPage succeeds', () async {
      when(() => mockDs.fetchMainPage()).thenAnswer((_) async => []);

      final healthy = await adapter.healthCheck();

      expect(healthy, isTrue);
    });

    test('healthCheck should return false when fetchMainPage throws', () async {
      when(() => mockDs.fetchMainPage()).thenThrowException();

      final healthy = await adapter.healthCheck();

      expect(healthy, isFalse);
    });
  });
}
```

- [ ] **Step 3: Run tests — verify RED**

Run: `flutter test test/unit/data/datasources/humoruniv_adapter_impl_test.dart`
Expected: FAIL with compilation error (`HumorunivAdapterImpl` does not exist).

- [ ] **Step 4: Write the minimal implementation**

Create `lib/data/datasources/humoruniv_adapter_impl.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/models/feed_item_dto.dart';
import 'package:humoruniv/data/models/post_detail_dto.dart';
import 'package:humoruniv/domain/entities/community.dart';

class HumorunivAdapterImpl implements CommunityAdapter {
  const HumorunivAdapterImpl({required this.remoteDs});

  final HumorunivRemoteDs remoteDs;

  @override
  CommunityId get communityId => CommunityId.humoruniv;

  @override
  Future<FeedListResult> fetchLatest({String? pageToken}) async {
    final dtos = await remoteDs.fetchMainPage();
    final items = dtos
        .map((d) => FeedItemDto(
              community: CommunityId.humoruniv,
              id: d.id.toString(),
              title: d.title,
              url: d.url,
              recommendCount: d.recommendCount,
            ))
        .toList();
    return FeedListResult(items: items);
  }

  @override
  Future<PostDetailDto> fetchDetail(String id) async {
    final detail = await remoteDs.fetchPostDetail(id);
    return PostDetailDto(
      id: detail.id,
      title: detail.title,
      author: detail.author,
      date: detail.date,
      contentHtml: detail.contentHtml,
      imageUrls: detail.imageUrls,
      recommendCount: detail.recommendCount,
      notRecommendCount: detail.notRecommendCount,
      viewCount: detail.viewCount,
      commentCount: detail.commentCount,
      comments: detail.comments,
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      await remoteDs.fetchMainPage();
      return true;
    } catch (e) {
      debugPrint('HumorunivAdapterImpl healthCheck failed: $e');
      return false;
    }
  }
}
```

**Note:** The `PostDetailDto` constructor signature in `fetchDetail` above assumes it matches `PostDetail`'s fields 1:1. If Step 1 found differences, adjust here. The same applies to the test.

- [ ] **Step 5: Run tests — confirm GREEN**

Run: `flutter test test/unit/data/datasources/humoruniv_adapter_impl_test.dart`
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/datasources/humoruniv_adapter_impl.dart test/unit/data/datasources/humoruniv_adapter_impl_test.dart
git commit -m "feat: add HumorunivAdapterImpl wrapping existing remote data source"
```

---

## Task 9: Register `HumorunivAdapterImpl` in DI (modify)

**Files:**
- Modify: `lib/di/injection.dart`
- Modify: `test/unit/di/injection_test.dart`

- [ ] **Step 1: Add DI registration**

Edit `lib/di/injection.dart`. Add these imports near the top (alphabetical within the existing block):

```dart
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
```

Then inside `configureDependencies()`, AFTER the existing `HumorunivRemoteDs` registration (line ~34) and BEFORE the `PostRepository` registration (line ~36), add:

```dart
  sl.registerLazySingleton<CommunityAdapter>(
    () => HumorunivAdapterImpl(remoteDs: sl<HumorunivRemoteDs>()),
  );
```

This registers the adapter as `CommunityAdapter` (the abstract type) so future adapters register under the same key. Existing `PostRepository` / use case registrations remain untouched.

- [ ] **Step 2: Add DI test assertions**

Edit `test/unit/di/injection_test.dart`. Inside the existing group that checks registrations, add:

```dart
    test('should register CommunityAdapter', () async {
      expect(di.sl.isRegistered<CommunityAdapter>(), isTrue);
    });

    test('CommunityAdapter should resolve without throwing', () async {
      expect(() => di.sl<CommunityAdapter>(), returnsNormally);
    });

    test('CommunityAdapter should be HumorunivAdapterImpl', () async {
      final adapter = di.sl<CommunityAdapter>();
      expect(adapter, isA<HumorunivAdapterImpl>());
    });
```

Add the necessary imports at the top of the test file:

```dart
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
```

- [ ] **Step 3: Run DI tests — confirm GREEN**

Run: `flutter test test/unit/di/injection_test.dart`
Expected: all tests PASS (existing + new).

- [ ] **Step 4: Commit**

```bash
git add lib/di/injection.dart test/unit/di/injection_test.dart
git commit -m "feat: register CommunityAdapter (HumorunivAdapterImpl) in DI"
```

---

## Task 10: Full verification — `make check`

**Files:** None (verification only)

- [ ] **Step 1: Run `flutter analyze` across the whole project**

Run: `flutter analyze --no-fatal-infos`
Expected: zero errors. If any warnings reference the new files, fix them.

- [ ] **Step 2: Run the full test suite (without smoke)**

Run: `flutter test`
Expected: ALL tests PASS. No existing test should be broken. The community-field additions used default values, so all existing equality checks still hold.

- [ ] **Step 3: Run integration tests**

Run: `flutter test test/integration/`
Expected: PASS.

- [ ] **Step 4: Confirm the app builds**

Run: `flutter build apk --debug --no-pub` *(or just `flutter run` if a device is attached)*
Expected: build succeeds.

- [ ] **Step 5: Tag the M0 milestone**

```bash
git tag m0-foundation
```

---

## M0 Exit Criteria Checklist

- [ ] `CommunityAdapter` abstract interface exists in `lib/data/datasources/`.
- [ ] `HumorunivAdapterImpl` implements it, wrapping the existing `HumorunivRemoteDs`.
- [ ] `Community` enum + VO + const list exist with all 5 communities defined.
- [ ] `FeedItem` entity + `FeedItemDto` exist.
- [ ] `Post`, `BoardPost`, `PostDetail` each carry a `community` field defaulting to `CommunityId.humoruniv`.
- [ ] `CommunityAdapter` is registered in DI under the abstract type.
- [ ] `flutter analyze` reports zero errors.
- [ ] `flutter test` passes (all existing tests + all new tests).
- [ ] No behavior change in the running app — humoruniv feed is visually identical.
- [ ] `PostRepository` / `GetBestPosts` / `GetPostDetail` / `GetBoardPosts` are **untouched** (deferred deletion to M2).

---

## Follow-on Milestones (outline — separate plans)

| Milestone | Scope | Own plan |
|---|---|---|
| **M1** | `MergedFeedRepository` + `feed_merger` pure function (k-way merge by timestamp, pure-timestamp mode, no fairness quota) + `MergedCursor` + tests with fake adapters. | `2026-07-26-multi-community-m1-merge.md` |
| **M2** | `TodayhumorAdapter` end-to-end (list + detail parsers, TDD Tier S per case), first real 2-community merged feed live, switch home feed onto merged path, delete legacy `PostRepository`. | `2026-07-26-multi-community-m2-todayhumor.md` |
| **M3** | `PpompuAdapter` (EUC-KR, closest analog to humoruniv). | `…-m3-ppompu.md` |
| **M4** | `DogdripAdapter` (Cloudflare) + `FmkoreaAdapter` (relative-time conversion). | `…-m4-dogdrip-fmkorea.md` |
| **M5** | Fairness quota in `feed_merger`, settings UI (per-community toggles, max-ratio slider), source badge on `FeedCard`, partial-failure banner. | `…-m5-fairness-ui.md` |
| **M6** | Per-source in-memory cache, parallel-fetch perf, E2E + smoke per site, release candidate. | `…-m6-hardening.md` |

Each follow-on plan follows the same format: this file is the template.

---

## Self-Review

**1. Spec coverage check:**

| Spec section | Covered by |
|---|---|
| §3 Domain: CommunityId/Community VO | Task 1 |
| §3 Domain: FeedItem entity | Task 2 |
| §3 Domain: community field on Post/BoardPost/PostDetail | Tasks 3, 4, 5 |
| §3 Domain: MergedCursor / MergedPage / MergedFeedRepository | **M1 plan** (deferred — correct, M0 doesn't need them) |
| §4 Data: CommunityAdapter interface | Task 7 |
| §4 Data: HumorunivAdapter | Task 8 |
| §4 Data: FeedItemDto | Task 6 |
| §4 Data: DI multi-binding | Task 9 (single adapter for now; multi-binding emerges as M2/M3/M4 add adapters) |
| §8 M0 exit criteria | Task 10 + Exit Criteria Checklist |

All in-scope M0 items covered. Deferred items correctly assigned to later milestones.

**2. Placeholder scan:** Searched for "TBD", "TODO", "implement later", "fill in", "similar to". None present except Task 8 Step 1 which instructs the executor to *read* `PostDetailDto` to confirm field names — that's a concrete inspection step, not a placeholder. The implementation code in Step 4 is complete and compilable once field names match.

**3. Type consistency:** `FeedItemDto.id` is `String` throughout (Tasks 2, 6, 8). `HumorunivAdapterImpl.fetchLatest` converts `PostDto.id` (int) → `String` via `.toString()` — consistent. `communityId` getter returns `CommunityId` enum everywhere. `fetchDetail` takes `String id` matching the `FeedItemDto.id` type. `FeedListResult` (defined in Task 7) is used in Task 8's return type — names match.

No issues found. Plan is ready for execution.
