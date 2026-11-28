# Product Plan

> **Web migration (2026-11).** The app is being moved from Flutter to a web app shown in a native Android WebView shell (gyo). `web/` is the web app and `shell/` the Android project; the Flutter code under `lib/` is the reference until the move is complete. This plan describes the web app and says where the Flutter app still differs. The state of the move: §9.

## 1. Project Definition

Unofficial mobile app for [humoruniv.com](https://m.humoruniv.com), a Korean humor community since 1998. A web app (React, Vite, TypeScript) inside a native Android WebView shell (gyo). No iOS.

- No backend server. The page cannot fetch `m.humoruniv.com` itself: CORS, the WebView's own user agent and its Referer get in the way. The native relay (`@gyo-community/http`) fetches the HTML with the site's mobile user agent, Referer, cookie jar and charset; the page decodes UTF-8 (the site served EUC-KR until 2026-10), parses the DOM, and presents structured data. Images and videos are loaded by the WebView straight from the community CDNs; the document sends no Referer.
- Clean Architecture: Presentation / Domain / Data layers with strict dependency direction: `service/` → `repository/` → `use_case/` → `provider/` under `web/src/`.
- TDD-first development. Every feature has unit and widget tests (Vitest); Dart tests are ported with their code.

### Core Constraint: Single Board Focus

The app focuses exclusively on **웃긴자료 (pds)** — the main humor board — until Phase 3.

Rationale:
- Reduces parser surface area from 30+ board layouts to 1.
- Dramatically lowers maintenance risk (1 parser to update vs 30+).
- Faster time to MVP: 1.5-2 weeks instead of 3-4.
- The pds board is the highest-traffic, highest-value board on the site.
- Most other boards share the same HTML template, so adding them later requires minimal new parser code.

The web app serves 웃대 alone. The Flutter app also serves 오늘의유머, 개드립, 뽐뿌, 보배드림, 루리웹 and 네이트판: they are not planned for the web app (§9, W-09). The feed, the settings switches and the tabs take every registered community, so one would join by registering its repository.

## 2. Target Users (Personas)

### Casual Viewer

- **Behavior**: Commute, spare time. Consumes recent posts.
- **Core Need**: Fast scroll through content.
- **Scenario**: Opens app on subway. Sees the 웃긴자료 feed immediately and scrolls through posts inline — images open fullscreen, comments open as a sheet. Closes app after 5 minutes. No login needed.
- **Frequency**: 2-3 times per week.

### Regular

- **Behavior**: Visits daily. Reads broadly.
- **Core Need**: Full feed with search.
- **Scenario**: Opens app during lunch break. Scrolls the 웃긴자료 feed, expands long bodies, opens comment sheets on hot posts. Uses search (P1) to find older posts. Saves a post now and then to read it later (P1, not P2: bookmarks are P1 in the Flutter roadmap — the local save, F-16a, which the web app has as 저장함, and its server sync, F-16).
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
│  웃긴대학                            ⚙️ 설정  │
│  title (plain text)                 ⚙️ /settings │
└─────────────────────────────────────────────┘
```

| Entry | Icon | Label | AppBar Title | Screen |
|-------|------|-------|-------------|--------|
| Root `/` | — | — | 웃긴대학 | HomeScreen (Instagram-style vertical feed of pds, chronological, no filter) |
| AppBar action | `settings` (label: 설정) | 설정 | 설정 | SettingsScreen (pushed route `/settings`, back to Home) |
| Settings, group 저장함 | `bookmark` | 저장한 게시물 | 저장함 | BookmarksScreen (pushed route `/bookmarks`, back to Settings) |
| Settings, group 미디어 & 데이터 | `imageOff` | 차단된 이미지 (`N개`) | 차단된 이미지 | BlockedImagesScreen (pushed route `/blocked-images`, back to Settings) |

**No bottom navigation bar.** Single-board scope has only one primary destination (Home), so a bottom tab bar is chrome that doesn't justify itself (DESIGN.md principle: Content First). Settings is reached from the Home AppBar gear icon, and 저장함 and 차단된 이미지 each from a row of Settings. Search is not yet implemented (P1); when it lands it will be a pushed route or an in-feed affordance, not a permanent bottom tab.

**Phase 1 IA change**: Home and Board tabs merged. Home is now a single Instagram-style vertical feed of 웃긴자료 (pds) posts — full-bleed media cards for image posts, brand-color typography cards for text-only posts, single chronological order (no sort/filter UI). The separate Board tab is removed for the single-board phase; multi-board exploration (BoardListScreen → BoardDetailScreen) returns in Phase 3. The 종합베스트 / "오늘의 1위" hero concept is dropped.

**Communities in the app bar**: the title is the name of the community shown (웃긴대학, as the Flutter app has it). With two or more communities on, a tab bar of community chips (44pt) sits under the app bar; with one, there is no tab bar and nothing that hints at communities to come.

### Home (루트 `/`)

- Instagram-style vertical feed of 웃긴자료 (pds) posts, single chronological order (latest-first), no sort/filter UI.
- Each card renders content **inline**: author header → full-bleed media → counts row, ending with the `링크 복사` and `저장` / `저장 취소` buttons → caption (title + expandable body) → comment preview → timestamp.
- Media: one pager per post (`FeedImageCarousel`) — its images first, then its videos, a page each. A video without a poster still gets a page. An outside embed (YouTube, youtu.be, Vimeo: the `external` kind) has no player and shows its poster only; it gets no page without one. The position `N / M` shows when there is more than one page. Blocked images are left out of the pager, and leave it as soon as they are blocked.
- **No detail screen.** All reading happens in the feed: a comment preview tap opens the comments sheet over it, and a tap on a picture opens the image viewer over it. Neither is a route, and the viewer opens at once: there is no transition of the picture growing out of its card.
- **No control that does nothing.** The comment preview is tappable if, and only if, the post's body lists a comment; a tap opens the comments sheet. The media of a card is tappable: a tap on a picture opens the viewer, a video starts on `재생`, and the `⋯` button or a long-press opens the media menu (`MediaActionSheet`) to save to the gallery, share, copy the address or block the image. The media of a comment in the sheet is tappable the same way: a picture opens the viewer on that comment's pictures, a video opens the full-screen video viewer (`CommentVideoViewer`), and a long-press opens the media menu.
- Read posts shown in muted color (Phase: F-06).
- Cached data shown when offline, with a "Last updated X minutes ago" banner (Phase: F-08).
- Refresh by pulling down at the top of the page, or with the floating 맨 위로 button, which goes to the top and loads the first page again. Both keep what is shown until the new page has arrived.
- Infinite scroll: the next page is asked for at 85% of the list.

### Search (P1 — pushed route or in-feed affordance)

- Search bar with debounce.
- Period filter: 1 day / 1 week / 1 month / 6 months / 1 year / all.
- Search history (stored locally).
- Results shown as feed cards (same inline treatment as Home).
- Not implemented in current phase; when it lands it is NOT a permanent bottom tab (single-screen IA).

### Settings (pushed route `/settings`, from Home AppBar gear)

- Community switches — persisted locally. The last community that is on cannot be switched off.
- Version, and the link to the source code.
- Groups, in this order: 커뮤니티, 저장함, 미디어 & 데이터, 정보. 저장함 holds 저장한 게시물, which opens `/bookmarks`; 미디어 & 데이터 holds 차단된 이미지, with the count `N개`, which opens `/blocked-images`.
- Not in the web app yet: the update check. The image cache of the Flutter app is not part of the web app.
- Dark mode: the app is dark only.
- The first-launch NSFW warning and its toggle are not part of the web app (owner decision, 2026-11-28).

### 저장함 (pushed route `/bookmarks`, from the 저장한 게시물 row of Settings)

- The saved posts, most recently saved first, each shown as the feed shows a card. The body of each is asked for when the list is shown.
- Reached only from Settings; Back returns to Settings.

### 차단된 이미지 (pushed route `/blocked-images`, from the 차단된 이미지 row of Settings)

- One row per blocked image, most recently blocked first: the picture itself, when it was blocked, its address, and `차단 해제`.
- Reached only from Settings; Back returns to Settings.

## 5. Screen Map

```
App
├── HomeScreen (root `/`, AppBar: 웃긴대학 + ⚙️ settings action
│   │   └── Instagram-style vertical feed of 웃긴자료 (pds) — inline content
│   │       ├── ImageViewerScreen (overlay over `/`, on image tap) — in the web app; not a route
│   │       ├── MediaActionSheet (overlay over `/`, from the ⋯ button or a long-press on the media) — in the web app; not a route
│   │       └── CommentsSheet (bottom sheet over `/`, on comment-preview tap) — in the web app; an overlay, not a route
│   └── SettingsScreen (push `/settings`, from Home AppBar gear)
│       ├── BookmarksScreen (push `/bookmarks`, from the 저장한 게시물 row) — in the web app
│       │   └── CommentsSheet (overlay over `/bookmarks`, on comment-preview tap)
│       └── BlockedImagesScreen (push `/blocked-images`, from the 차단된 이미지 row) — in the web app
└── (Phase 2+) LoginScreen, ReadHistoryScreen
```

The Flutter app also shows an `NsfwWarningDialog` over HomeScreen at first launch. The web app does not.

In the web app the pages are `HomeView`, `SettingsView`, `BookmarksView` and `BlockedImagesView` (`web/src/pages/`); the overlays are the widgets `ImageViewer`, `CommentVideoViewer`, `MediaActionSheet` and `CommentsSheet` (`web/src/widgets/`).

> **No `PostDetailScreen`.** Phase 1 is an inline feed — all reading happens in the feed card itself. A dedicated detail screen returns only if Phase 2 (comment write / recommend) needs a focused surface.
> **Phase 3**: a BoardTab returns (BoardListScreen → BoardDetailScreen) when multi-board support lands, at which point a bottom tab bar may be reintroduced.

Navigation rules:
- AppBar gear (Home) → SettingsScreen (push), back returns to Home.
- 저장한 게시물 (Settings) → BookmarksScreen (push `/bookmarks`); 차단된 이미지 (Settings) → BlockedImagesScreen (push `/blocked-images`). Back returns to Settings.
- Image tap (in a card of the feed) → ImageViewerScreen, an overlay over `/`. It is not a route: opening it pushes one entry of the WebView's history, at the page's own address.
- `⋯` button or long-press (on the media of a card, or on a picture in the viewer) → `MediaActionSheet`, an overlay over the page, with one history entry of its own.
- Comment-preview tap (in a card of the feed, or of 저장함) → `CommentsSheet`, a bottom sheet over the page. It is not a route: opening it pushes one entry of the WebView's history, at the page's own address.
- Back (system back gesture or button) → the frontmost overlay closes first, and only Back with no overlay open goes to the previous page of the WebView's history. With the media menu over the viewer open, Back closes the menu, then the viewer, and only then leaves the page; with the comments sheet open, Back closes the sheet first; with all three open (a comment's picture tapped in the sheet, then `⋯` in the viewer), Back closes the menu, then the viewer, then the sheet, and leaves the page only after that.

## 6. Screen Requirements

### HomeScreen (inline feed) — Phase: P0

- Body: per-post `FeedCard` rendered inline — author header + media (one pager: the images, then the videos) + counts row, with the `링크 복사` and `저장` / `저장 취소` buttons + caption (title + expandable body, `더보기`/`접기`) + comment preview + timestamp.
- The body of each post is fetched as the post enters the list: a skeleton while it loads, an error card with `다시 시도` when it fails.
- Media of a post: one pager per card (`FeedImageCarousel`) — every image, then every video, a page each. A video without a poster still gets a page; an outside embed (YouTube, youtu.be, Vimeo — the `external` kind) has no player and shows its poster only, with no page when it has none. The position `N / M` shows when there is more than one page, and one swipe is one page. A page is as tall as what it shows, from 120 to 600px, square until the size of the picture is known. Blocked images are left out, and leave the pager when they are blocked.
- A tap on a picture opens the image viewer on that picture. The `⋯` button of the pager, and a long-press (half a second) on the media, open the media menu for what the page shows: an image, a video, or an outside embed.
- Media menu (`MediaActionSheet`): a sheet whose rows come in this order, each only where it can act — `갤러리에 저장` for an image or a video of the post, never for an outside embed; `공유` for every kind; `URL 복사` for every kind, the address of the media and not of the post; `이미지 차단` for an image only. `닫기` is always there. Saving to the gallery and sharing are in the web app for an image or a video of a post, through the native plugin `@gyo-community/media`. From Android 10 on, saving asks for no permission; below it the app declares the storage permission up to Android 9 (`maxSdkVersion="28"`), which is compiled but was never run — no such device was at hand.
- Blocking an image hides it at once from every post that shows it. The web app blocks by address: the fingerprint of a blocked picture is stored, as the Flutter app stores it, but the pictures the web app shows are not fingerprinted, so the same picture under another address is not hidden yet.
- Saving a post: the card's `저장` button saves it to 저장함 and becomes `저장 취소` (`aria-pressed`); the same button unsaves it. `링크 복사` copies the address of the post.
- Inline video (`InlineVideoPlayer`): a video starts only when the reader taps `재생`, and nothing of the video is fetched before the tap — only its poster. It starts muted and loops. Its controls: `재생` / `일시정지`, `음소거` / `음소거 해제`, `전체 화면`, a progress bar to scrub with the time `m:ss / m:ss`, and a buffering indicator. The controls hide after 3 seconds of playing; a tap on the stage shows or hides them and never plays or pauses. The stage keeps the shape it reserved — 16:9, or the ratio known for the video — and the video is letterboxed in it. One video plays and loads at a time; under 40 % on screen, a playing video pauses. Full screen is asked of the player's own element, where its controls stay; the shell's own Back leaves it, so the player adds no history entry for it. A clip the site made of a GIF has `재생` / `일시정지` only. A video that cannot be loaded says `동영상을 불러올 수 없습니다` over its poster, with `탭하여 재시도`.
- Comments: under a post's text, the preview `댓글 N개 모두 보기` with the first comment the body lists. It is a button if, and only if, the body has arrived and lists at least one comment; a tap opens the comments sheet (`CommentsSheet`) over the feed, and nothing else opens it. The sheet is to read only — writing, recommending and logging in are Phase 2 — and makes no request. Its header says `댓글 N개`. It lists what the body lists, in that order: the best comments, marked `BEST`, first, then every other comment, each with its replies nested under it. A body that arrived without a comment shows no preview: nothing to tap.
- Counts: recommend / comment / view — display-only in Phase 1 (no recommend action until Phase 2). Until a post's body has arrived, the counts row shows what the site's listing counted (`post.commentCount`); once it has, the comment count is `N` as defined next.
- Comment count: `N = listedCommentCount(detail.comments)` — every comment the body lists and every reply under it, at any depth, each once; not the total the site shows for the post. Whether there is a preview is a separate gate, `comments.length > 0`; the site's count never decides it. Once the body has arrived, the same `N` is in the card's counts row, in the preview, in the sheet's header and in the dialog's label. A body that arrived with no comment shows `0`, whatever the site counted. A comment's recommend count of `0` is shown as `0`. This differs from the Flutter app, whose sheet header uses the site's `commentCount` and hides a recommend count of 0.
- No navigation to a detail screen.

### ImageViewerScreen — Phase: P0

In the web app the viewer is the widget `ImageViewer`: an overlay over `/`, not a route, opened by a tap on a picture of a card. It shows the images of that post, the blocked ones left out, and opens on the one that was tapped.

- Over everything, on black, inside the safe area of the screen; a modal dialog named `이미지 보기`. It does not go full screen itself, so the system bars stay as the page leaves them.
- One image at a time. Paged by a swipe — one swipe is one image — by the `이전` and `다음` buttons, and by the keys `←` and `→`. A tap does not page, not even on the left or right third of the viewer.
- Always a `닫기` button; the position `N / M`, with `이전` and `다음`, when there is more than one image. The buttons are 44px, and switched off at the ends.
- Pinch to zoom, up to 4×. A picture is panned only once it is zoomed. A double-tap puts a zoomed picture back to 1×, and never pages. The keys `+` and `-` zoom one step at a time (1, 2, 3, 4); the button `확대` goes to 2×, and `원래 크기` back to 1×. `확대` is switched off until the picture has loaded, and for a picture that cannot be zoomed.
- A picture narrower than the screen — a strip — is shown at the width of the viewer and scrolled up and down; it is not zoomed.
- The `⋯` button, and a long-press on the picture, open the media menu for that image: save it to the gallery, share it, copy its address, or block it. Saving to the gallery and sharing are in the web app for an image of a post from here as from the card (F-19 and F-26, for the media of a post).
- A picture that is blocked while the viewer is open leaves it; when none is left, the viewer closes itself.
- A picture that does not load says `이미지를 불러오지 못했습니다`, with `다시 시도`.
- Closed by Back, `닫기` or `Esc`. On close the page is where it was, and the focus goes back to the picture that opened the viewer.

### BookmarksScreen (저장함) — Phase: P1

- Pushed route `/bookmarks`, from the 저장한 게시물 row of Settings. Its app bar is titled 저장함, with a way back.
- The saved posts, most recently saved first, each as the feed shows a card: the author, counts, title and time that were saved with it, and its body, which is asked for once when the list is shown. While the body loads, the card shows the feed's skeleton.
- Blocked images are hidden here as in the feed.
- A body that failed stays inside the card, which keeps what was saved of the post: its author, counts and title, and the thumbnail of its listing. The card says why, and offers `다시 시도` where there is something to try again:
  - Cannot connect: `연결할 수 없어 본문을 불러올 수 없어요`, with `저장한 때의 글만 보여요`, and `다시 시도`.
  - Any other failure: `불러오기 실패 — ` and the reason, with `다시 시도`.
  - The site answered 404 or 410: `삭제되었거나 비공개된 게시물이에요`, with nothing to try again.
- Unsaving: the card's `저장 취소` button. The post leaves the list; when that failed, `저장을 취소하지 못했어요` says so and the post stays.
- The comment preview opens the comments sheet here as well, an overlay over `/bookmarks`.
- Empty: `저장한 게시물이 없어요`, with the hint `좋아하는 글을 북마크해 보세요`.
- Here too: the image viewer, the video viewer and the media menu open from a card of 저장함 and from its comments sheet, as on `/`.

### BlockedImagesScreen (차단된 이미지) — Phase: web (W-06)

- Pushed route `/blocked-images`, from the 차단된 이미지 row of Settings, which shows the count `N개`. Its app bar is titled 차단된 이미지, with a way back.
- One row per blocked image, most recently blocked first: the picture itself, unfiltered; when it was blocked; its address; and `차단 해제`.
- `차단 해제` shows the image again in every post at once and takes the row off the list: `차단을 해제했어요`. When it failed: `차단 해제에 실패했어요`, and the image stays blocked.
- The thumbnail is not a button: the image viewer is not opened from here yet.
- Empty: `차단된 이미지가 없어요`, with the hint `이미지를 열어 메뉴에서 차단할 수 있어요`.
- The web app blocks by address. The fingerprint of a blocked picture is stored, in the shape the Flutter app uses, but the pictures shown are not fingerprinted: the same picture under another address is not hidden yet.

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
App Open → Home (loading skeleton)
  → Background fetch → 웃긴자료 feed appears
```

The Flutter app inserts a splash and an NSFW warning dialog before Home. The web app has neither.

### Flow 2: Content Consumption

```
Home → Scroll 웃긴자료 feed → read inline (title + body + media)
  → Tap image → ImageViewerScreen → swipe → back
  → ⋯ or long-press on the media → media menu → back
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

- Forward navigation: the WebView's history (`/settings`, `/bookmarks` and `/blocked-images` are pushed).
- Back navigation: system back gesture or button, which leaves the page in the history.
- Comments sheet: slides in from the bottom over the feed (`250ms`, `ease-out`; no motion under reduced motion) and is removed at once when closed, with no exit animation. It is an overlay, not a route: opening it pushes one entry of the history, at the page's own address. System Back, 닫기, the scrim and Esc all leave it through that one entry, so Back closes the sheet first and only the next Back leaves the page. On close the page is where it was scrolled, and the focus goes back to the preview that opened the sheet.
- Media menu: a sheet made of the same `BottomSheet` as the comments sheet — every sheet of the web app is, and shadcn's sheet and drawer are not used. It slides in and is removed the same way, and holds one history entry of its own. Opened over the image viewer, it is the frontmost overlay: Back closes it first, and the viewer under it stays.
- Image viewer: an overlay over everything, not a route, with one history entry of its own, like the sheets. It appears at once, with no transition of the picture growing out of its card. Closed by Back, 닫기 or Esc; the page keeps its scroll and the focus goes back to the picture that opened it.
- Overlays over overlays: each one pushes its own entry, so Back closes the frontmost first — the menu, then the viewer, then the sheet it was opened from — and leaves the page only when none is open. An overlay stays open when Back lands on the entry of one opened after it, so three can be open at once.
- Full screen of a video: asked of the player's own element, where its controls stay. The Android shell's own Back leaves full screen before the page hears of it, so the player adds no history entry for it.

### Gestures

- Pull-to-refresh: Home feed, by pulling down at the top of the page; the floating 맨 위로 button loads the first page again too. **Refresh is the one exception to "a gesture is never the only way"** (the owner's decision, 2026-11-28): at the top of the page pulling is the way, as in the Flutter app. The app bar has no refresh button, and its title is plain text. A touch that starts inside a dialog — a sheet, the viewer — is the dialog's, never a pull.
- Infinite scroll: Home feed (pagination triggers near the end of the loaded list).
- Expand/collapse: post body text (`더보기`/`접기`).
- Comments sheet: no drag handle — it cannot be dragged or swiped away. It closes by Back, 닫기, the scrim or Esc. Its list scrolls on its own while the page behind is locked, and a tap or a touch inside it does not reach the page.
- Pager of a card: a swipe is one page, however fast the fling; the pager takes the height of the page it lands on.
- Comment media: a picture is a button that opens the image viewer on that comment's pictures; a video, shown by its poster with a play icon, is a button that opens the full-screen video viewer (`CommentVideoViewer`), which plays at once, muted, and goes full screen through its player; a long-press on either opens the media menu. Where a page opens nothing with them, a thumbnail is a plain picture with no icon.
- Media menu: reached by the `⋯` button — by a tap, or by the keyboard, since it is a button — and by a long-press, a finger held half a second without moving, on the media of a card or on a picture in the viewer. Letting go of the long-press is not also a tap.
- Image viewer: a swipe is one image. A pinch zooms, up to 4×; a zoomed picture is panned by a drag; a double-tap puts it back to 1× and never pages. A tap does nothing: a tap on the left or right third of the viewer does not page — the swipe, the `이전` / `다음` buttons and the keys `←` / `→` do. A strip of a picture is scrolled up and down.
- Video: `재생` starts it. A tap on the stage shows or hides the controls and never plays or pauses. The progress bar scrubs, and a touch on it does not reach the page.

### Feedback Patterns

- Recommend/Not-recommend: optimistic count update, revert on error (Phase 2).
- Loading: skeleton/shimmer feed cards. A picture of a card holds its place as a muted box, square, until its size is known; the viewer shows a placeholder until its picture has loaded; a video shows a buffering indicator from the tap until it plays, and whenever the data runs out.
- Error: inline error message with retry button, never blank screen. In a card, a picture that did not load keeps its place and says `이미지를 불러오지 못했습니다` with `다시 시도`; a video says `동영상을 불러올 수 없습니다` with `탭하여 재시도`.
- Empty state: message. ("게시글이 없습니다."; in 저장함, `저장한 게시물이 없어요` with a hint; in 차단된 이미지, `차단된 이미지가 없어요` with a hint.)
- Comments sheet: it opens only from a body that has arrived, so inside it there is no loading and no network state.
  - Body loading: the card's skeleton; no preview, no sheet.
  - Body error: the feed's error card with `다시 시도`; no preview, no sheet.
  - No comment in the body: no preview, nothing to tap, no sheet; `0` in the counts row.
  - Offline: only what is in memory; no sheet without a loaded body.
  - Nothing to list, when the body left in a reload while the sheet was open: `댓글이 없습니다.`
- Media menu: a row acts at once, the sheet closes, and what came of it is a toast.
  - `URL 복사`: `링크를 복사했어요`; when it failed, `링크를 복사하지 못했습니다`.
  - `이미지 차단`: `이미지를 차단했어요`, with `취소`, which takes the block back and says `차단을 해제했어요`. When the block failed: `차단하지 못했어요`, and nothing to take back.
  - `갤러리에 저장`: `저장 중…` in the row while it runs; the sheet closes when it is done, and `저장했어요` says so. When the app lacks the gallery's permission, the sheet closes too and `갤러리 접근 권한이 필요해요. 시스템 설정에서 허용해주세요` says what to do. A save that was canceled, or is already running, puts the row back to idle.
  - `공유`: `준비 중…` in the row while it prepares; the sheet closes once the media is offered, and nothing is said. A share that was canceled, or is already running, puts the row back to idle.
  - Any other failure of a save or a share stays in its row, to be tapped to try again: `저장에 실패했어요 · 탭하여 재시도`, `공유에 실패했어요 · 탭하여 재시도`.
- Saving a post: when the write failed, `저장하지 못했어요` or `저장을 취소하지 못했어요`; otherwise only the button changes.
- 차단 해제: `차단을 해제했어요`; when it failed, `차단 해제에 실패했어요`, and the picture stays blocked.
- Offline: cached content with "Last updated X minutes ago" banner. Not in the web app yet.
- NSFW: none. The first-launch warning dialog is not part of the web app.

## 9. Feature Roadmap

### Web migration

The web app is built in slices. Each one is usable on its own and leaves no control that does nothing.

| ID | Slice | Status |
|----|-------|--------|
| W-00 | Web app skeleton, native relay (`@gyo-community/http`), Android shell | Done |
| W-01 | Home: feed of 웃대 with inline cards (text and images), body fetched per post, paging, refresh by pull and from the way up, loading / error / empty states | Built. Checked on an emulator and on a phone |
| W-02 | Settings: community switches, version, source link | Built. Checked on an emulator and on a phone |
| W-03 | Image viewer: fullscreen, swipe, pinch-zoom, for the images of a post's card and for the pictures of a comment (opened from the comments sheet) | Built |
| W-04 | Comments sheet: reading only, opened from a post card's preview | Built |
| W-05 | Image carousel, inline video (one at a time) and the media menu (save to the gallery, share, copy the address, block an image), for the media of a post's card; a comment's video opens full screen (`CommentVideoViewer`), and a long-press on a comment's picture or video opens the menu | Built |
| W-06 | Bookmarks (저장함) and blocked images. Sliced out of it: the image cache, which is not part of the web app; read posts, which stay with F-06; and moving what the Flutter app saved, which is W-08 | Built |
| W-07 | Cached content and the "Last updated" banner when offline | Deferred |
| W-08 | Moving the bookmarks and settings saved by the Flutter app | Deferred |
| W-09 | The other communities, through the repository registry | Dropped: the web app serves 웃대 alone |
| W-10 | Release: the web app under the released app's package and signing key | Last |

Checked how: W-01 to W-06 were exercised on an emulator's WebView (Android 14) and on a phone (Galaxy Z Flip6, Android 16, WebView 157). On both the page was read and driven through the WebView's debug protocol, on the phone its touches as well; saving to the gallery and the share chooser went through the native plugin on both. No check has yet shown a finger on the glass (how a pinch, a fling or a long-press feel), a screen reader, or Android 9 and earlier.

Not planned for the web app: the first-launch NSFW warning (F-11), iOS, the image cache, and the other communities (W-09).

W-09 was started and set aside on 2026-11-28. Six parsers had been ported with their tests and checked against the real Dart code, and the feed named a community whose list failed; the user then decided that the web app serves 웃대 alone, and that the other communities are designed and built anew if they are ever wanted, not resumed. What that design is to know: the Flutter feed keeps the newest 20 × communities posts of a page and puts the posts without a date first, so with every community on the communities whose posts carry a date are cut — checked live on that day, 오늘의유머 kept 7 of 30 posts and 개드립 6 of 23, and the tab of a community shows only what is kept. The Flutter app behaves the same way.

### Flutter app (reference until the move is complete)

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
| F-11 | NSFW content warning on first launch (persisted) + settings toggle (persisted) | P0. Flutter only: not part of the web app |
| F-12 | Pull-to-refresh on feed | P1 |
| F-16a | Local bookmark (save posts to SharedPreferences, view in 저장함 screen) — local-only half of F-16, pulled forward as low-risk. In the web app: built, as 저장함 (W-06) | P1 |
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
| F-19 | Share post link (system share sheet; copy-to-clipboard = F-19a, done in Phase 1). In the web app: built for the media of a post — a picture, a video, or the address of an outside embed, from the media menu; the link of a post is copied (F-19a), not shared | P1 | Low |
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
| F-26 | Gallery save | Android 13+ granular permissions. In the web app: built for a picture or a video of a post, through `@gyo-community/media`; no permission from Android 10 on. |
| F-27 | Home screen widget (Android) | Requires background scraping — complex. |
| F-28 | Tablet layout | Low priority for Korean humor community demographics. |

## 10. Risk Management

| Risk | Impact | Mitigation |
|------|--------|------------|
| Site HTML structure changes | Parser breaks, app shows errors | Single parser = single point of fix. Graceful degradation: show cached data + error message. Fast hotfix deployment. |
| Site blocks app access | All features fail | The relay sends each site's own user agent and Referer and keeps its cookies (`web/src/service/service_locator.ts`); it is the only way the app talks to a site. Prepare WebView fallback mode as emergency option. |
| Write operations fail (CSRF/session) | Phase 2 features cut | Spike in Phase 0. If fragile, reposition as view-only app. Do not commit to write features until proven. |
| Login cookie expiry | Auth features stop working | Auto-detect expiry + prompt re-login. Show clear session-expired UI. |
| Store rejection | Cannot list in a store | The app is a web page in a native shell, so the earlier claim that it is not a web wrapper no longer holds. It is distributed as an APK from GitHub Releases, not through a store; a listing would have to rest on the native relay, the offline cache and the image viewer. Non-commercial use stated. |
| Content copyright issues | Legal risk | App is a viewer. Content belongs to original authors. App does not modify or create content. |
| Aggressive scraping triggers IP ban | App stops working | The native relay makes the requests, under the same rules. Parallel detail prefetch (one detail request per feed post on page load) raises request volume. Mitigations: memoizing cache dedups in-flight + repeated requests, standard mobile-browser User-Agent, single list request per page. Re-introduce a hard 2s rate-limit if the source site signals throttling. |

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
