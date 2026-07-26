# Design: Multi-Community Merged Feed

- **Date**: 2026-07-26
- **Status**: Approved — awaiting implementation plan
- **Scope**: Phase 3 expansion. Adds 4 external communities to the existing
  웃긴자료 (pds) feed and merges them into a single chronological timeline.
- **Parent design**: [2026-06-28-instagram-feed-design.md](2026-06-28-instagram-feed-design.md)

## 1. Overview

The current app serves a single community (`humoruniv.com`, board `pds`).
Users report the feed feels sparse. This design integrates four additional
Korean humor communities into one merged timeline so that scrolling the
home feed surfaces content from all five sources, interleaved by recency.

### Target communities

| Community | Site | Encoding | List path | Notes |
|-----------|------|----------|-----------|-------|
| 웃대 (humoruniv) | `m.humoruniv.com` | EUC-KR | `/main.html` (best) | Existing — refactored onto adapter |
| 오유 (todayhumor) | `m.todayhumor.com` | UTF-8 *(verify M2)* | `/list.php?table=bestofbest` | Sibling humor site |
| 개드립 (dogdrip) | `dogdrip.net` | UTF-8 | `/` Drupal list | Cloudflare risk |
| 뽐뿌 (ppomppu) | `ppomppu.co.kr` | **EUC-KR** | `/zboard/zboard.php?id=humor` | `charset_converter` reusable |
| FM (fmkorea) | `fmkorea.com` | UTF-8 | `/humorbest` | Relative time (`X 시간 전`) |

### Locked decisions

1. **Read-only** for this expansion. Login, recommend, comment write, and
   scrap sync remain out of scope (carried over from Phase 2 plan). Adding
   five separate login flows + CSRF handling would multiply risk.
2. **Inline feed preserved.** No `PostDetailScreen`. All reading happens
   in `FeedCard` exactly as in Phase 1. Each community's detail HTML is
   normalized into the existing `PostDetail` entity and rendered by the
   same card components.
3. **`CommunityAdapter` abstraction first (big-bang pluggable).** The
   adapter interface is built and proven before any new site ships. Each
   site is a self-contained adapter with its own HTTP client config and
   parser set.
4. **Community discriminator on entities.** Every post-bearing entity
   gains a `CommunityId community` field. Existing humoruniv code is
   migrated to set `CommunityId.humoruniv`.
5. **Per-source fairness applied post-merge.** Pure timestamp merge ships
   first (M1); fairness quota lands in M5. FM코리아's higher post volume
   is not capped until M5 — acceptable because the merged feed is not
   user-visible until M2 at earliest.

## 2. Architecture

Dependency direction is unchanged (Presentation → Domain ← Data). The
humoruniv-specific `HumorunivRemoteDs` and `PostRepository` are absorbed
behind a new adapter abstraction; no presentation code calls them
directly after M0.

```
┌────────────────────────────────────────────────────────────────┐
│  Presentation                                                  │
│  HomeScreen → FeedCard (with source badge)                     │
│      ↳ mergedFeedProvider (FutureProvider.family)              │
└──────────────────────────────┬─────────────────────────────────┘
                               │ Domain
┌──────────────────────────────┴─────────────────────────────────┐
│  GetMergedFeed UseCase                                         │
│      ↳ MergedFeedRepository (interface)                        │
│      ↳ k-way merge pure function (timestamp + fairness quota)  │
└──────────────────────────────┬─────────────────────────────────┘
                               │ Data
┌──────────────────────────────┴─────────────────────────────────┐
│  MergedFeedRepositoryImpl                                      │
│      ↳ Future.wait over 5 CommunityAdapter implementations     │
│                                                                │
│  HumorunivAdapter   TodayhumorAdapter   DogdripAdapter         │
│   ↳ HtmlClient#1     ↳ HtmlClient#2      ↳ HtmlClient#3        │
│   ↳ MainPageParser   ↳ TodayhumorList…   ↳ DogdripList…        │
│   ↳ PostDetailParser ↳ TodayhumorDetail… ↳ DogdripDetail…      │
│                                                                │
│  PpompuAdapter                FmkoreaAdapter                   │
│   ↳ HtmlClient#4 (EUC-KR)     ↳ HtmlClient#5                   │
│   ↳ PpompuList…               ↳ FmkoreaList…                   │
│   ↳ PpompuDetail…             ↳ FmkoreaDetail… (+rel. time)    │
└────────────────────────────────────────────────────────────────┘
```

## 3. Domain Layer

### New entities / value objects

```dart
// lib/domain/entities/community.dart
enum CommunityId { humoruniv, todayhumor, dogdrip, ppomppu, fmkorea }

class Community {
  final CommunityId id;
  final String shortName;          // "웃대", "오유", "개드립", "뽐뿌", "FM"
  final String displayName;        // "웃긴대학", "오늘의유머", ...
  final int brandColorArgb;
  final String iconAsset;
  const Community({...);
}

const communities = <Community>[ ... ];  // ordered config list
```

### Migrations to existing entities

`Post`, `BoardPost`, `PostDetail` each gain a non-nullable
`CommunityId community` field. All humoruniv construction sites set it
to `CommunityId.humoruniv`. Tier B tests updated accordingly.

### New merged-feed types

```dart
// lib/domain/entities/feed_item.dart
class FeedItem {
  final CommunityId community;
  final String id;                  // unique within (community, id)
  final String title;
  final String author;
  final String url;
  final DateTime publishedAt;       // ★ merge key
  final int recommendCount;
  final int commentCount;
  final int viewCount;
  final String? thumbnailUrl;
  final String? previewText;
}

// lib/domain/entities/merged_feed.dart
class MergedCursor {
  final DateTime oldestSeen;
  final Map<CommunityId, String?> perSourceTokens;
  const MergedCursor({...});
}

class MergedPage {
  final List<FeedItem> items;
  final MergedCursor? next;
  final Set<CommunityId> failedSources;   // for partial-failure banner
  const MergedPage({...});
}
```

### Repository interface

```dart
// lib/domain/repositories/merged_feed_repository.dart
abstract class MergedFeedRepository {
  Future<Either<Failure, MergedPage>> fetchMerged({
    required int perSource,
    MergedCursor? cursor,
    Set<CommunityId> enabled = const {},          // empty = all
  });
}
```

### UseCase

```dart
// lib/domain/usecases/get_merged_feed.dart
class GetMergedFeed implements UseCase<MergedPage, MergedFeedParams> { ... }
```

The existing `PostRepository` and `GetBestPosts` / `GetPostDetail` use
cases are deleted at the end of M0 once all callers route through the
new path. M0 keeps them temporarily to keep tests GREEN during the
refactor.

## 4. Data Layer

### Adapter abstraction

```dart
// lib/data/datasources/community_adapter.dart
abstract class CommunityAdapter {
  CommunityId get communityId;
  Future<List<FeedItemDto>> fetchLatest({String? pageToken});
  Future<PostDetailDto> fetchDetail(String id);
  Future<bool> healthCheck();    // true if site reachable, not captcha'd
}
```

Each implementation owns:
- A dedicated `HtmlClient` instance parameterized by `(baseUrl, encoding,
  userAgent)`.
- A list parser (returns `List<FeedItemDto>` with `pageToken` for the next
  page).
- A detail parser (returns `PostDetailDto`).
- A per-host rate limiter (minimum 2 seconds between requests to the same
  host; cross-host concurrency permitted).

### Adapters

| Adapter | baseUrl | Encoding | Notes |
|---|---|---|---|
| `HumorunivAdapter` | `https://m.humoruniv.com` | EUC-KR | Wraps existing `MainPageParser` + `PostDetailParser`. Zero parser changes. |
| `TodayhumorAdapter` | `https://m.todayhumor.com` | UTF-8 *(verify M2)* | Parses `list.php?table=bestofbest`. Mobile list DOM. |
| `DogdripAdapter` | `https://www.dogdrip.net` | UTF-8 | Drupal list. `healthCheck()` detects Cloudflare captcha HTML. |
| `PpompuAdapter` | `https://www.ppomppu.co.kr` | EUC-KR | `zboard.php?id=humor` table layout; reuses `charset_converter`. |
| `FmkoreaAdapter` | `https://www.fmkorea.com` | UTF-8 | `/humorbest`. Relative time → absolute `DateTime` conversion. |

### Multi-binding in DI

`lib/di/injection.dart` registers a `Map<CommunityId, CommunityAdapter>`
containing all five adapters. `MergedFeedRepositoryImpl` takes this map
plus per-host `HtmlClient` instances.

### `MergedFeedRepositoryImpl`

1. Filter to `enabled` adapters (empty set → all).
2. Call `healthCheck()` on each in parallel; skip unhealthy ones (mark
   in `failedSources`).
3. `Future.wait` over `fetchLatest(pageToken: cursor.perSourceTokens[c])`
   for each healthy adapter.
4. Hand the per-source lists to the pure `mergeFeedStreams` function
   (Domain layer).
5. Apply fairness quota (M5 onward) inside the pure function.
6. Build `MergedCursor` from the oldest returned timestamp + each
   adapter's returned `pageToken`.

## 5. Merge Algorithm

Pure function in the Domain layer, unit-tested in isolation:

```dart
// lib/domain/services/feed_merger.dart
MergedPage mergeFeedStreams({
  required Map<CommunityId, List<FeedItem>> streams,
  required int perSourceLimit,
  DateTime? olderThan,
  double maxRatioPerSource = 1.0,        // 1.0 = no cap (M1 default)
  Set<CommunityId> failedSources = const {},
})
```

### Algorithm

1. **Filter**: drop any `FeedItem` with `publishedAt >= olderThan` when
   paginating (only older items advance the cursor).
2. **Heap merge**: push the head of each stream onto a max-heap keyed by
   `publishedAt`. Pop the newest, push the next from that source.
   Continues until the heap is empty or `perSourceLimit * |streams|`
   items have been emitted.
3. **Tie-break**: when two items share a timestamp (common when sites
   expose minute- or hour-granularity only), break ties by round-robin
   across sources — never let one source dominate a tie cluster.
4. **Fairness quota (M5+)**: after the merge, walk the result list and
   down-rank any source exceeding `maxRatioPerSource` by deferring its
   surplus items to the next page. Default at M5 launch: `0.4`.
5. **Cursor**: `oldestSeen = items.last.publishedAt`;
   `perSourceTokens[c]` comes from each adapter's `pageToken`.

### Time normalization rules (per adapter)

| Source | Raw time format | Conversion |
|---|---|---|
| humoruniv | Absolute `YY/MM/DD HH:MM` | Parse directly |
| todayhumor | Absolute date + time | Parse directly |
| dogdrip | Absolute (list often hour-only) | Parse; tie-break absorbs precision loss |
| ppomppu | Absolute `HH:MM:SS` + date row | Parse directly |
| fmkorea | Relative (`X 시간 전`, `X 분 전`) | Convert at fetch time: `now - X unit`. Items older than 24 h fall back to absolute date display. |

## 6. Presentation Layer

### Information architecture

Unchanged: single-screen IA. No bottom tab bar. Home remains the root
route `/`. The merged feed replaces the humoruniv-only feed.

### FeedCard changes

Add a **source badge** to the author header row: a colored dot in the
community's `brandColorArgb` followed by the `shortName` ("웃대", "오유",
"개드립", "뽐뿌", "FM"). Tapping the badge sets a temporary in-feed
filter showing only that community (cleared on navigation away).

Media, body, counts, and comment-preview rendering are unchanged — they
already handle image / video / text-only variants. Each adapter's
`PostDetailDto` normalizes into the existing shape.

### Settings screen

New "커뮤니티" group:

- One toggle per community (persisted via `SharedPreferences`).
  Disabled communities are excluded from `enabled` set on
  `MergedFeedRepository.fetchMerged`.
- "한 커뮤니티 최대 비율" slider, 25%–60%, default 40%. Wired to
  `maxRatioPerSource` (M5).
- "마지막 업데이트" banner extended to show per-source last-success
  timestamps.

### Providers

```dart
final mergedFeedProvider =
    FutureProvider.family<MergedPage, MergedCursor?>((ref, cursor) async {
  final settings = ref.watch(communitySettingsProvider);
  return ref.read(getMergedFeedProvider)(
    MergedFeedParams(cursor: cursor, enabled: settings.enabled),
  );
});

final communitySettingsProvider =
    NotifierProvider<CommunitySettingsNotifier, CommunitySettings>(...);
```

## 7. Risk Mitigation

| Risk | Mitigation |
|---|---|
| One site down | `healthCheck()` per adapter; failed sources returned in `MergedPage.failedSources`; banner shown ("X 커뮤니티 일시적 오류"). Other sources still render. |
| Cloudflare / dogdrip block | Standard mobile UA per host; on captcha detection, adapter enters 30-minute unhealthy cooldown; not retried until expiry. |
| Site HTML change breaks parser | Each adapter owns its own parsers; one site's breakage cannot affect others. Errors logged; hotfix scope is one adapter. |
| IP ban from over-fetching | Per-host 2 s rate limit preserved. Global cool-down triggers if 3+ adapters fail `healthCheck()` in a 60 s window. |
| ToS / copyright | Non-commercial viewer; content is not modified or created; each site's `robots.txt` is checked in M0 before its adapter goes live. |
| Comment parsing per site grows scope | Acknowledged gap (see §10). Comment sheets for non-humoruniv sites may be deferred to a follow-up if estimate slips. |

## 8. Milestones

Big-bang architecture, but delivered in testable milestones. Each
milestone ends with `flutter test` GREEN, `flutter analyze` clean, and a
commit. Total estimate: **6.5–7 weeks** (comment parsing is the
uncertain piece).

| Milestone | Scope | Exit criteria | Estimate |
|---|---|---|---|
| **M0** | `CommunityAdapter` interface; `HumorunivAdapter` refactored to implement it; existing `Post`/`BoardPost`/`PostDetail` gain `community` field; all existing callers route through adapter. | All existing tests GREEN with no behavior change. humoruniv feed visually identical. | 1.0 wk |
| **M1** | `MergedFeedRepository` + `feed_merger` pure function + `MergedCursor`; verified with two in-test fake adapters. Pure-timestamp merge only (no fairness). | Unit tests cover merge, pagination cursor, partial failure. | 0.5 wk |
| **M2** | `TodayhumorAdapter` end-to-end (list parser TDD, detail parser TDD, `healthCheck`, encoding verification). First real 2-community merged feed live. | Two-community feed renders on device; smoke test passes against `m.todayhumor.com`. | 1.0 wk |
| **M3** | `PpompuAdapter` (EUC-KR; closest analog to humoruniv). | Three-community feed live; smoke test passes. | 0.5 wk |
| **M4** | `DogdripAdapter` (Cloudflare handling) + `FmkoreaAdapter` (relative-time conversion). | Five-community feed live; smoke tests pass for both. | 1.5 wk |
| **M5** | Fairness quota in `feed_merger`; settings UI (per-community toggles, max-ratio slider); source badge on `FeedCard`; per-source last-updated banner; partial-failure banner. | All user-facing features complete; widget tests GREEN. | 1.0 wk |
| **M6** | Hardening: per-source in-memory cache (extend F-08 pattern); parallel-fetch performance measurement; E2E tests; release candidate. | `make check` clean; crash-rate acceptable on internal dogfood. | 0.5–1.0 wk |

User value ("more content") starts materializing at **M2** — the merged
feed is shippable from that point onward with incremental source
additions.

## 9. Testing Strategy

Tiers per `docs/TESTING.md`:

| Layer | Tier | Notes |
|---|---|---|
| Entities (`Community`, `FeedItem`, `MergedCursor`, `MergedPage`) | B | Per-layer; write tests then impl. |
| `feed_merger` pure function | **S** | Strict per-test-case. Heap merge, tie-break, fairness, cursor advancement, partial-failure. |
| Per-site list parsers (todayhumor/dogdrip/ppompu/fmkorea) | **S** | Strict per-test-case with fixture HTML captured from each live site. |
| Per-site detail parsers | **S** | Same. |
| `CommunityAdapter` implementations | A | Per-class; mock `HtmlClient`. |
| `MergedFeedRepositoryImpl` | A | Per-class; mock adapters; verify `Future.wait` orchestration + failure propagation. |
| `GetMergedFeed` UseCase | A | Per-class. |
| `mergedFeedProvider`, `communitySettingsProvider` | A | Per-class. |
| `FeedCard` source badge, settings group | A | Widget tests. |
| Integration: repository + real adapters + mock `HtmlClient` returning fixtures | — | One suite per milestone. |
| E2E / smoke: real network against each live site | — | One test per adapter; gated behind `make smoke` (needs device + internet). |

## 10. Loose Ends Requiring Verification

Items that cannot be fully resolved without spike work. Each is
assigned to a milestone so it is addressed deliberately, not
discovered late.

| # | Item | Milestone | Risk if it slips |
|---|---|---|---|
| 1 | `robots.txt` per site — confirm scraping is permitted for dogdrip / fmkorea / ppomppu / todayhumor. | M0 | Could force dropping a site. |
| 2 | Todayhumor response encoding (assumed UTF-8). | M2 | Low — `charset_converter` already handles EUC-KR if needed. |
| 3 | Dogdrip Cloudflare behavior under mobile-app UA + repeated requests. | M4 | May force WebView fallback or site deferral. |
| 4 | Per-site pagination model (page=N, cursor, after_id, …) — adapter normalizes to `pageToken: String`, but the mapping differs per site. | M2 / M3 / M4 | Per-site parsing work. |
| 5 | **Comment parsing per site.** Current `FeedCommentsSheet` is humoruniv-only. Each new adapter needs its own comment parser, which is not yet included in the milestone estimates. | M2 / M3 / M4 | Adds 0.5–1.0 week. May defer non-humoruniv comment sheets to a follow-up. |
| 6 | `image_cache_service.dart` — verify it supports arbitrary source CDN domains, not just humoruniv's. | M0 | May need a small refactor. |
| 7 | Caller map for `PostRepository` / `GetBestPosts` / `GetPostDetail` before they are removed in M0. | M0 | Refactor scope creep. |
| 8 | HTML fixture capture for each site (Tier S parser TDD). | M2 / M3 / M4 | Manual work; one-time per site. |
| 9 | FM코리아 relative-time precision loss ("X 시간 전") affects merge ordering. | M4 | Tie-break rotation absorbs this; documented in `feed_merger`. |

Item 5 is the most material estimate risk. The plan defaults to
**including comment parsing** in M2–M4 (hence 6.5–7 weeks). If timeline
pressure emerges, the fallback is to ship non-humoruniv comment sheets
in a follow-up release; the merged feed itself does not depend on them.

## 11. Out of Scope

- Login, recommend, comment write, scrap sync (Phase 2 territory).
- Search across communities (existing P1 search stays humoruniv-only
  until a separate design extends it).
- Block lists, font size, color themes (existing P2/P3 backlog).
- Tablet layout.
- Offline disk cache (Phase 3 F-25, separate design).
- Write operations of any kind.

## 12. Open Questions

None blocking. All architectural decisions confirmed during
brainstorming. Items in §10 are implementation-time verification, not
open design questions.
