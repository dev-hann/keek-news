# Product Plan

## 1. Project Definition

Unofficial native mobile app for [humoruniv.com](https://m.humoruniv.com), a Korean humor community since 1998.

- No backend server. The app fetches HTML from `m.humoruniv.com`, decodes EUC-KR, parses the DOM, and presents structured data.
- Clean Architecture: Presentation / Domain / Data layers with strict dependency direction.
- TDD-first development. All features require unit, widget, integration, and E2E tests.

### Core Constraint: Single Board Focus

The app focuses exclusively on **웃긴자료 (pds)** — the main humor board — until Phase 3.

Rationale:
- Reduces parser surface area from 30+ board layouts to 1.
- Dramatically lowers maintenance risk (1 parser to update vs 30+).
- Faster time to MVP: 1.5-2 weeks instead of 3-4.
- The pds board is the highest-traffic, highest-value board on the site.
- Most other boards share the same HTML template, so adding them later requires minimal new parser code.

## 2. Target Users (Personas)

### Casual Viewer

- **Behavior**: Commute, spare time. Consumes recent posts.
- **Core Need**: Fast scroll through content.
- **Scenario**: Opens app on subway. Sees the 웃긴자료 feed immediately and scrolls through posts inline — images open fullscreen, comments open as a sheet. Closes app after 5 minutes. No login needed.
- **Frequency**: 2-3 times per week.

### Regular

- **Behavior**: Visits daily. Reads broadly.
- **Core Need**: Full feed with search.
- **Scenario**: Opens app during lunch break. Scrolls the 웃긴자료 feed, expands long bodies, opens comment sheets on hot posts. Uses search (P1) to find older posts. Occasionally bookmarks (P2).
- **Frequency**: Daily.

### Active User

- **Behavior**: Comments, recommends, participates.
- **Core Need**: Login, interactions.
- **Scenario**: Logs in first thing. Checks responses to their comments. Recommends posts they enjoy. Writes comments on hot topics. Checks scrap list.
- **Frequency**: Multiple times daily.

### Newcomer

- **Behavior**: First visit. Doesn't know the site.
- **Core Need**: Curated best content, low barrier.
- **Scenario**: Heard about the app from a friend. Opens it and sees curated best content immediately. No login, no setup needed. Browses popular posts to understand the community.
- **Frequency**: First few visits, may convert to Casual or Regular.

## 3. UX Principles

1. **3-second content access**: First meaningful content visible within 3 seconds of app launch. Cached data shown instantly, fresh data loads in background.
2. **Zero-friction browsing**: Scroll through home feed without extra taps. No forced onboarding, no login wall. Content is always one tap away.
3. **Visual content priority**: Posts with images are emphasized in the feed. Image viewing is fullscreen, swipeable, and requires no extra navigation.
4. **Seamless navigation**: Screen transitions, back navigation, and deep links work naturally. Users never feel "lost" in the app.
5. **Offline resilience**: Cached content available when disconnected. Never show a blank screen. Clearly indicate stale data with timestamp.
6. **Korean-first UX**: Korean typography, reading direction, content density optimized for Korean community content. No Western-centric assumptions.

## 4. Information Architecture

Single-screen IA (Phase 1 — single-board scope; see `.opencode/plans/2026-06-28-instagram-feed.md`):

```
┌─────────────────────────────────────────────┐
│  홈  (웃긴자료 feed)            ⚙️ 설정      │
│  AppBar title: 웃긴자료        → push /settings │
└─────────────────────────────────────────────┘
```

| Entry | Icon | Label | AppBar Title | Screen |
|-------|------|-------|-------------|--------|
| Root `/` | `home` | — | 웃긴자료 | HomeScreen (Instagram-style vertical feed of pds, chronological, no filter) |
| AppBar action | `settings_outlined` (tooltip: 설정) | 설정 | 설정 | SettingsScreen (pushed route `/settings`, back to Home) |

**No bottom navigation bar.** Single-board scope has only one primary destination (Home), so a bottom tab bar is chrome that doesn't justify itself (DESIGN.md principle: Content First). Settings is reached from the Home AppBar gear icon. Search is not yet implemented (P1); when it lands it will be a pushed route or an in-feed affordance, not a permanent bottom tab.

**Phase 1 IA change**: Home and Board tabs merged. Home is now a single Instagram-style vertical feed of 웃긴자료 (pds) posts — full-bleed media cards for image posts, brand-color typography cards for text-only posts, single chronological order (no sort/filter UI). The separate Board tab is removed for the single-board phase; multi-board exploration (BoardListScreen → BoardDetailScreen) returns in Phase 3. The 종합베스트 / "오늘의 1위" hero concept is dropped.

### Home (루트 `/`)

- Instagram-style vertical feed of 웃긴자료 (pds) posts, single chronological order (latest-first), no sort/filter UI.
- Each card renders content **inline**: author header → full-bleed media (image carousel or inline video player) → counts row → caption (title + expandable body) → comment preview → timestamp.
- **No detail screen.** All reading happens in the feed. Image tap → `ImageViewerScreen`; comment preview tap → comments bottom sheet.
- Read posts shown in muted color (Phase: F-06).
- Cached data shown when offline, with a "Last updated X minutes ago" banner (Phase: F-08).
- Pull-to-refresh + infinite scroll.

### Search (P1 — pushed route or in-feed affordance)

- Search bar with debounce.
- Period filter: 1 day / 1 week / 1 month / 6 months / 1 year / all.
- Search history (stored locally).
- Results shown as feed cards (same inline treatment as Home).
- Not implemented in current phase; when it lands it is NOT a permanent bottom tab (single-screen IA).

### Settings (pushed route `/settings`, from Home AppBar gear)

- Dark mode toggle (system-aware) — persisted locally.
- NSFW content warning toggle — persisted locally.
- App version and update check.
- Future (Phase 2+): login status, scrap list, read history, font size, color themes.

## 5. Screen Map

```
App
├── HomeScreen (root `/`, AppBar: 웃긴자료 + ⚙️ settings action)
│   │   └── Instagram-style vertical feed of 웃긴자료 (pds) — inline content
│   │       ├── ImageViewerScreen (push, on image tap)
│   │       └── FeedCommentsSheet (bottom sheet, on comment-preview tap)
│   └── SettingsScreen (push `/settings`, from AppBar gear)
│       ├── BookmarksScreen (push, from 저장함 tile — local bookmark list, Phase 1)
│       └── (Phase 2+) LoginScreen, ReadHistoryScreen
└── NsfwWarningDialog (first-launch overlay, shown over HomeScreen)
```

> **No `PostDetailScreen`.** Phase 1 is an inline feed — all reading happens in the feed card itself. A dedicated detail screen returns only if Phase 2 (comment write / recommend) needs a focused surface.
> **Phase 3**: a BoardTab returns (BoardListScreen → BoardDetailScreen) when multi-board support lands, at which point a bottom tab bar may be reintroduced.

Navigation rules:
- AppBar gear (Home) → SettingsScreen (push), back returns to Home.
- Image tap (in feed) → ImageViewerScreen (push, shared element transition).
- Comment-preview tap (in feed) → comments bottom sheet.
- Back → pop to previous screen.

## 6. Screen Requirements

### HomeScreen (inline feed) — Phase: P0

- Body: per-post `FeedCard` rendered inline — author header + media (image carousel OR inline video player) + counts row + caption (title + expandable body, `더보기`/`접기`) + comment preview + timestamp.
- Inline images: tap to open fullscreen viewer (shared element transition).
- Inline video: in-card player with play/pause/mute/fullscreen controls; tap thumbnail in comment media opens fullscreen.
- Comments: tap the "댓글 N개 모두 보기" preview to open a bottom sheet with best-pinned + full list.
- Counts: recommend / comment / view — display-only in Phase 1 (no recommend action until Phase 2).
- No navigation to a detail screen.

### ImageViewerScreen — Phase: P0

- Fullscreen, black background. Status bar visible; SafeArea applied.
- Left/right swipe between images in the post.
- Pinch to zoom, double-tap to reset.
- Position indicator: "3 / 12".
- Save to gallery (P3).

### LoginScreen — Phase: P2

- WebView loading `web.humoruniv.com/user/login.html`.
- On success: extract cookies, store in app's HTTP client.
- Auto-detect session expiry and prompt re-login.

### SearchResult — Phase: P1

- Same inline feed-card treatment as Home.
- Empty state: "No results found" with suggestion to adjust filter.

## 7. User Flows

### Flow 1: First Launch

```
App Open → Splash (logo) → NSFW Warning Dialog
  → "Acknowledge" → HomeTab (cached or empty state)
  → Background fetch → 웃긴자료 feed appears
```

### Flow 2: Content Consumption

```
Home → Scroll 웃긴자료 feed → read inline (title + body + media)
  → Tap image → ImageViewerScreen → swipe → back
  → Tap "댓글 N개 모두 보기" → comments bottom sheet → back
  → Continue scrolling feed
```

> No separate detail screen in Phase 1 — everything is read inline.

### Flow 3: Board Exploration (Phase 3 — not in Phase 1)

```
BoardTab → See board list → Tap a board → BoardDetailScreen
  → See post list with filters → Tap post → post detail (Phase 3 may reintroduce a focused detail screen)
  → Back → BoardDetailScreen → Change filter (daily/weekly/monthly)
  → Back → BoardTab
```

### Flow 4: Search

```
Home → (search entry: pushed route or in-feed affordance) → Type query (debounced)
  → Select period filter → Results appear (inline feed cards)
  → Tap result's image → ImageViewerScreen → Back → Search results
```

### Flow 5: Login + Interaction (P2)

```
Home → AppBar gear → Settings → Tap "Login" → LoginScreen (WebView)
  → Enter credentials → Success → Settings (shows logged-in state)
  → Back to Home → (recommend/scrap actions become available, Phase 2)
```

## 8. Interaction Patterns

### Screen Transitions

- Forward navigation: platform default (slide on iOS, fade on Android).
- Back navigation: system back gesture/button.
- Image viewer: shared element transition (hero animation).
- Comments: bottom sheet (material).

### Gestures

- Pull-to-refresh: Home feed (and Search results when implemented).
- Infinite scroll: Home feed (pagination triggers near the end of the loaded list).
- Expand/collapse: post body text (`더보기`/`접기`).
- Swipe: image viewer left/right navigation.
- Pinch-to-zoom: image viewer.
- Double-tap: image viewer reset zoom.

### Feedback Patterns

- Recommend/Not-recommend: optimistic count update, revert on error (Phase 2).
- Loading: skeleton/shimmer feed cards.
- Error: inline error message with retry button, never blank screen.
- Empty state: illustration + message + suggested action.
- Offline: cached content with "Last updated X minutes ago" banner.
- NSFW: first-launch warning dialog (persisted acknowledgement), settings toggle for ongoing blur control.

## 9. Feature Roadmap

### Phase 0: Spike (3-4 days)

Prove the architecture works end-to-end with one full TDD cycle.

- [x] Install all dependencies (riverpod, dio, html, charset_converter, dartz, go_router, get_it).
- [x] Set up DI container (`di/injection.dart`).
- [x] Build `HtmlClient` with EUC-KR decoding via `charset_converter`.
- [x] Build `HumorUnivRemoteDs` with rate limiting (minimum 2s between requests). *(Later relaxed to allow parallel inline-feed prefetch — see F-09 / §10.)*
- [x] Write `PdsParser.parseBestPosts()` with fixture HTML.
- [x] Complete one full TDD cycle: test -> parser -> use case -> repository -> provider -> screen.
- [ ] Spike: attempt a POST request for recommend to assess write operation feasibility.

**Exit criteria**: Main screen displays real best posts from humoruniv.com.

### Phase 1: MVP (1.5-2 weeks)

Read-only humor content viewer.

| ID | Feature | Priority |
|----|---------|----------|
| F-01 | Home: inline 웃긴자료 feed (image carousel + video + comments preview) | P0 |
| F-02 | (Phase 3) Board: board list + full post list with filters and pagination | P3 |
| F-03 | Inline feed rendering: text + images + video + comments (read) | P0 |
| F-04 | Image viewer: fullscreen, swipe, pinch-zoom | P0 |
| F-05 | Search: keyword + period filter | P1 |
| F-06 | Read post tracking (local storage) | P1 |
| F-07 | Dark mode (system-aware, persisted) | P1 |
| F-08 | In-memory caching with TTL | P1 |
| F-09 | Polite scraping: parallel detail prefetch + memoizing cache + browser UA (rate-limit relaxed; see §10) | P0 |
| F-10 | Error states: network error, parse error, empty state | P0 |
| F-11 | NSFW content warning on first launch (persisted) + settings toggle (persisted) | P0 |
| F-12 | Pull-to-refresh on feed | P1 |
| F-16a | Local bookmark (save posts to SharedPreferences, view in 저장함 screen) — local-only half of F-16, pulled forward as low-risk | P1 |
| F-19a | Copy post link to clipboard from feed card — local-only half of F-19, pulled forward as low-risk | P1 |

**MVP exit criteria**: App is listed on store. User can browse, read, and search humor posts with a better experience than mobile web.

### Phase 2: Auth + Interactions (2-3 weeks)

Login and active participation. Write operations are high-risk and may be cut.

| ID | Feature | Priority | Risk |
|----|---------|----------|------|
| F-13 | Login via WebView + cookie management | P0 | Medium |
| F-14 | Recommend / not-recommend | P0 | **High** (POST + CSRF) |
| F-15 | Comment write | P1 | **High** (POST + CSRF) |
| F-16 | Scrap / bookmark server sync (local half = F-16a, done in Phase 1) | P1 | Low |
| F-17 | Favorite boards pin | P2 | Low |
| F-18 | Deep linking (open humoruniv URLs in app) | P1 | Low |
| F-19 | Share post link (system share sheet; copy-to-clipboard = F-19a, done in Phase 1) | P1 | Low |
| F-20 | User block list | P2 | Medium |
| F-21 | Font size setting | P2 | Low |
| F-22 | 6 color themes | P3 | Low |

**Write operation disclaimer**: Recommend, comment write, and scrap sync require POST requests against a form-based site with CSRF tokens. These features are marked **High risk** and will be spiked in Phase 0. If the POST flow proves fragile, the app will be positioned as a "view-only companion" and these features will be cut.

### Phase 3: Expansion (future)

| ID | Feature | Notes |
|----|---------|-------|
| F-23 | Additional boards | Most boards share the same HTML template as pds. Parser reuse likely. |
| F-24 | Write posts (image/video attach) | Requires full form POST reverse-engineering. |
| F-25 | Offline disk cache (Hive/Isar) | Persist parsed DTOs + images for offline reading. |
| F-26 | Gallery save | Android 13+ granular permissions. |
| F-27 | Home screen widget (Android) | Requires background scraping — complex. |
| F-28 | Tablet layout | Low priority for Korean humor community demographics. |

## 10. Risk Management

| Risk | Impact | Mitigation |
|------|--------|------------|
| Site HTML structure changes | Parser breaks, app shows errors | Single parser = single point of fix. Graceful degradation: show cached data + error message. Fast hotfix deployment. |
| Site blocks app access | All features fail | Set User-Agent to standard mobile browser. Prepare WebView fallback mode as emergency option. |
| Write operations fail (CSRF/session) | Phase 2 features cut | Spike in Phase 0. If fragile, reposition as view-only app. Do not commit to write features until proven. |
| Login cookie expiry | Auth features stop working | Auto-detect expiry + prompt re-login. Show clear session-expired UI. |
| App store rejection | Cannot distribute | App is not a web wrapper: native image viewer, caching, offline support, search. Non-commercial use stated. |
| Content copyright issues | Legal risk | App is a viewer. Content belongs to original authors. App does not modify or create content. |
| Aggressive scraping triggers IP ban | App stops working | Parallel detail prefetch (one detail request per feed post on page load) raises request volume. Mitigations: memoizing cache dedups in-flight + repeated requests, standard mobile-browser User-Agent, single list request per page. Re-introduce a hard 2s rate-limit if the source site signals throttling. |

## 11. Success Metrics

| Phase | Metric | Target |
|-------|--------|--------|
| Phase 1 | App store listing live | Yes/No |
| Phase 1 | Crash rate | < 2% |
| Phase 1 | App store rating | 4.0+ |
| Phase 2 | Monthly active users | 300+ |
| Phase 2 | Posts viewed per session | 10+ |
| Phase 2 | Logged-in user ratio | 30%+ |
| Phase 3 | Monthly active users | 1,000+ |
| Phase 3 | Crash rate | < 0.5% |

Measurement: Firebase Analytics (client-side SDK, not a backend server).

## 12. Timeline

```
Week 1        Phase 0: Spike — prove architecture, one TDD cycle
Week 2-3      Phase 1: MVP — read-only viewer
              ── MVP Release ──
Week 4-6      Phase 2: Auth + interactions (write ops high-risk)
              ── Growth Release ──
Week 7+       Phase 3: Expansion — more boards, offline, advanced features
```
