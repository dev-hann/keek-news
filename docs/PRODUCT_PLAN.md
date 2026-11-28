# Product Plan

## 1. Project Definition

Unofficial mobile app for [humoruniv.com](https://m.humoruniv.com), a Korean humor community since 1998. A web app (React 19, Vite, TypeScript, Tailwind 4, shadcn/ui) inside an Android WebView shell (gyo). No iOS; Android from 7.0 (API 24).

The app is `web/`. Its shell is `shell/` (package `com.keek_news.app`): the WebView that opens the web app where it is served, holding the Android modules of the native plugins the page uses (`@gyo-community/http`, `@gyo-community/media`). The version of the app is `version` in `shell/gyo.config.json` — 4.0.0, the first above the Flutter app's last, 3.14.3 (§9).

- No backend server. The page cannot fetch `m.humoruniv.com` itself: CORS, the WebView's own user agent and its Referer get in the way. The native relay (`@gyo-community/http`) fetches the HTML with the site's mobile user agent, Referer, cookie jar and charset; the page decodes UTF-8 (the site served EUC-KR until 2026-10), parses the DOM, and presents structured data. Images and videos are loaded by the WebView straight from the community CDNs; the document sends no Referer.
- Clean Architecture: Presentation / Domain / Data layers with strict dependency direction: `service/` → `repository/` → `use_case/` → `provider/` under `web/src/`.
- TDD-first development. Every feature has unit and widget tests (Vitest), mirroring `web/src/` under `web/test/`.

### History

The app was a Flutter app until 2026-11-28. Its last version is the tag `v3.14.3`, where that code and its roadmap remain; nothing of it is in the repository any more.

### Core Constraint: Single Board Focus

The app focuses exclusively on **웃긴자료 (pds)** — the main humor board.

Rationale:

- Reduces parser surface area from 30+ board layouts to 1.
- Dramatically lowers maintenance risk (1 parser to update vs 30+).
- The pds board is the highest-traffic, highest-value board on the site.

One community, 웃대. By the user's decision of 2026-11-28 the web app serves 웃대 alone. 오늘의유머, 개드립, 뽐뿌, 보배드림, 루리웹 and 네이트판, which the Flutter app served, are not planned for it; if they are ever wanted they are designed and built anew (§9). The feed, the settings switches and the tabs take every registered community, so one would join by registering its repository.

## 2. Target Users (Personas)

### Casual Viewer

- **Behavior**: Commute, spare time. Consumes recent posts.
- **Core Need**: Fast scroll through content.
- **Scenario**: Opens app on subway. Sees the 웃긴자료 feed immediately and scrolls through posts inline — images open fullscreen, comments open as a sheet. Closes app after 5 minutes. No login needed.
- **Frequency**: 2-3 times per week.

### Regular

- **Behavior**: Visits daily. Reads broadly.
- **Core Need**: Full feed with search (search is not in the app).
- **Scenario**: Opens app during lunch break. Scrolls the 웃긴자료 feed, expands long bodies, opens comment sheets on hot posts. Saves a post now and then, with `저장` on its card, to read it later in 저장함.
- **Frequency**: Daily.

### Active User

- **Behavior**: Comments, recommends, participates.
- **Core Need**: Login, interactions.
- **Scenario**: Would log in first thing, check responses to their comments, recommend the posts they enjoy and write comments on hot topics. The app gives none of this today: it has no login, and nothing in it writes — the comments sheet is for reading.
- **Frequency**: Multiple times daily.

### Newcomer

- **Behavior**: First visit. Doesn't know the site.
- **Core Need**: Curated best content, low barrier.
- **Scenario**: Heard about the app from a friend. Opens it and sees the 웃긴자료 feed at once — the newest posts, not a curated list. No login, no setup needed. Reads the posts with the most recommends to get a feel for the community.
- **Frequency**: First few visits, may convert to Casual or Regular.

## 3. UX Principles

1. **3-second content access**: First meaningful content visible within 3 seconds of app launch. The first page is asked for as soon as Home is shown, with a skeleton until it arrives; a refresh keeps what is shown until the new page has arrived.
2. **Zero-friction browsing**: Scroll through home feed without extra taps. No forced onboarding, no login wall. Content is always one tap away.
3. **Visual content priority**: Posts with images are emphasized in the feed. Image viewing is fullscreen, swipeable, and requires no extra navigation.
4. **Seamless navigation**: Page changes, Back and the overlays work naturally: Back closes the frontmost overlay first and leaves the page only when none is open. Users never feel "lost" in the app.
5. **Never a blank screen**: A skeleton while a page loads, an error with a way to try again, a message when there is nothing to show. Nothing is kept for offline reading (§9).
6. **Korean-first UX**: Korean typography, reading direction, content density optimized for Korean community content. No Western-centric assumptions.

## 4. Information Architecture

Single-screen IA. Home is the only primary destination. The other pages are reached from it, or from a page that is — except the relay check, which is reached by its address:

```
┌─────────────────────────────────────────────┐
│  웃긴대학                            ⚙️ 설정  │
│  title (plain text)                 /settings │
└─────────────────────────────────────────────┘
```

| Entry | Icon | Label | AppBar Title | Screen |
|-------|------|-------|-------------|--------|
| Root `/` | — | — | 웃긴대학 | `HomeView` (Instagram-style vertical feed of pds, chronological, no filter) |
| AppBar action | `Settings` | 설정 | 설정 | `SettingsView` (pushed route `/settings`, back to Home) |
| Settings, group 저장함 | `Bookmark` | 저장한 게시물 | 저장함 | `BookmarksView` (pushed route `/bookmarks`, back to Settings) |
| Settings, group 미디어 & 데이터 | `ImageOff` | 차단된 이미지 (`N개`) | 차단된 이미지 | `BlockedImagesView` (pushed route `/blocked-images`, back to Settings) |
| Its address only; nothing in the app leads there | — | — | 릴레이 검사 | `RelayCheckView` (`/relay-check`): checks of the native relay on the device. A development aid, not a user screen |

**No bottom navigation bar.** Single-board scope has only one primary destination (Home), so a bottom tab bar is chrome that doesn't justify itself (DESIGN.md principle: Content First). Settings is reached from the Home AppBar gear icon, and 저장함 and 차단된 이미지 each from a row of Settings. Search is not in the app.

**Home is one feed.** A single Instagram-style vertical feed of 웃긴자료 (pds) posts — full-bleed media cards for posts with pictures or a video, text cards for the rest — in a single chronological order, latest first (no sort/filter UI). There is no board list and no separate Board tab: the app has one board.

**Communities in the app bar**: the title is the name of the community shown (웃긴대학). With two or more communities on, a tab bar of community chips (44px) sits under the app bar; with one, there is no tab bar and nothing that hints at communities to come.

### Home (루트 `/`)

- Instagram-style vertical feed of 웃긴자료 (pds) posts, single chronological order (latest-first), no sort/filter UI.
- Each card renders content **inline**: author header (`BEST` beside the author from 500 recommends) → full-bleed media → counts row, ending with the `링크 복사` and `저장` / `저장 취소` buttons → caption (title + expandable body) → comment preview → timestamp where the listing gives a date (웃대's listing gives none).
- Media: one pager per post (`FeedImageCarousel`) — its images first, then its videos, a page each. A video without a poster still gets a page. An outside embed (YouTube, youtu.be, Vimeo: the `external` kind) has no player and shows its poster only; it gets no page without one. The position `N / M` shows when there is more than one page. Blocked images are left out of the pager, and leave it as soon as they are blocked.
- **No detail screen.** All reading happens in the feed: a comment preview tap opens the comments sheet over it, and a tap on a picture opens the image viewer over it. Neither is a route, and the viewer opens at once: there is no transition of the picture growing out of its card.
- **No control that does nothing.** The comment preview is tappable if, and only if, the post's body lists a comment; a tap opens the comments sheet. The media of a card is tappable: a tap on a picture opens the viewer, a video starts on `재생`, and the `⋯` button or a long-press opens the media menu (`MediaActionSheet`) to save to the gallery, share, copy the address or block an image. The media of a comment in the sheet is tappable the same way: a picture opens the viewer on that comment's pictures, a video opens the full-screen video viewer (`CommentVideoViewer`), and a long-press opens the media menu.
- Refresh by pulling down at the top of the page, or with the floating 맨 위로 button, which goes to the top and loads the first page again. Both keep what is shown until the new page has arrived.
- Infinite scroll: the next page is asked for at 85% of the list; a first page that does not fill the screen asks for it at once.

### Settings (pushed route `/settings`, from Home AppBar gear)

- Community switches — persisted locally. There is one, 웃긴대학, and it is on: the switch cannot be switched off, since the last community that is on is locked to keep the feed from going empty.
- Groups, in this order: 커뮤니티, 저장함, 미디어 & 데이터, 정보. 저장함 holds 저장한 게시물, which opens `/bookmarks`; 미디어 & 데이터 holds 차단된 이미지, with the count `N개`, which opens `/blocked-images`.
- 정보 holds 버전 and 소스 코드. 버전 is the version of the web app (`version` in `web/package.json`), not the version of the shell. 소스 코드 opens the repository on GitHub, in the browser.
- No update check: nothing in the app looks for a newer version (§9).
- Dark mode: the app is dark only.
- No first-launch warning about adult content, and no setting for one (owner decision, 2026-11-28).

### 저장함 (pushed route `/bookmarks`, from the 저장한 게시물 row of Settings)

- The saved posts, most recently saved first, each shown as the feed shows a card. The body of each is asked for when the list is shown.
- Reached only from Settings; Back returns to Settings.

### 차단된 이미지 (pushed route `/blocked-images`, from the 차단된 이미지 row of Settings)

- One row per blocked image, most recently blocked first: the picture itself, when it was blocked, its address, and `차단 해제`.
- Reached only from Settings; Back returns to Settings.

## 5. Screen Map

```
App
├── HomeView (root `/`, AppBar: 웃긴대학 + ⚙️ settings action)
│   │   └── Instagram-style vertical feed of 웃긴자료 (pds) — inline content
│   │       ├── ImageViewer (overlay over `/`, on image tap) — not a route
│   │       ├── MediaActionSheet (overlay over `/`, from the ⋯ button or a long-press on the media) — not a route
│   │       └── CommentsSheet (bottom sheet over `/`, on comment-preview tap) — an overlay, not a route
│   └── SettingsView (push `/settings`, from Home AppBar gear)
│       ├── BookmarksView (push `/bookmarks`, from the 저장한 게시물 row)
│       │   └── CommentsSheet (overlay over `/bookmarks`, on comment-preview tap)
│       └── BlockedImagesView (push `/blocked-images`, from the 차단된 이미지 row)
└── RelayCheckView (`/relay-check`, by its address) — development aid
```

The pages are `HomeView`, `SettingsView`, `BookmarksView`, `BlockedImagesView` and `RelayCheckView` (`web/src/pages/`); the overlays are the widgets `ImageViewer`, `CommentVideoViewer`, `MediaActionSheet` and `CommentsSheet` (`web/src/widgets/`).

> **No post detail screen.** The feed is inline: all reading happens in the feed card itself, and nothing in the app navigates to a detail screen.

Navigation rules:
- AppBar gear (Home) → SettingsView (push), back returns to Home.
- 저장한 게시물 (Settings) → BookmarksView (push `/bookmarks`); 차단된 이미지 (Settings) → BlockedImagesView (push `/blocked-images`). Back returns to Settings.
- Image tap (in a card of the feed) → `ImageViewer`, an overlay over `/`. It is not a route: opening it pushes one entry of the WebView's history, at the page's own address.
- `⋯` button or long-press (on the media of a card, or on a picture in the viewer) → `MediaActionSheet`, an overlay over the page, with one history entry of its own.
- Comment-preview tap (in a card of the feed, or of 저장함) → `CommentsSheet`, a bottom sheet over the page. It is not a route: opening it pushes one entry of the WebView's history, at the page's own address.
- Back (system back gesture or button) → the frontmost overlay closes first, and only Back with no overlay open goes to the previous page of the WebView's history. With the media menu over the viewer open, Back closes the menu, then the viewer, and only then leaves the page; with the comments sheet open, Back closes the sheet first; with all three open (a comment's picture tapped in the sheet, then `⋯` in the viewer), Back closes the menu, then the viewer, then the sheet, and leaves the page only after that.

## 6. Screen Requirements

### HomeView (inline feed)

- Body: per-post `FeedCard` rendered inline — author header + media (one pager: the images, then the videos) + counts row, with the `링크 복사` and `저장` / `저장 취소` buttons + caption (title + expandable body, `더보기`/`접기`) + comment preview + timestamp where the listing gives a date.
- The body of each post is fetched as the post enters the list: a skeleton in the place of the media while it loads, an error card when it fails. The error card says why (`불러오기 실패 — ` and the reason), and offers `다시 시도` and `오류 정보 복사`, which copies a plain-text report of what the app could see — the kind of failure, the status, a few headers and the start of the answer — to paste into a bug report.
- Media of a post: one pager per card (`FeedImageCarousel`) — every image, then every video, a page each. A video without a poster still gets a page; an outside embed (YouTube, youtu.be, Vimeo — the `external` kind) has no player and shows its poster only, with no page when it has none. The position `N / M` shows when there is more than one page, and one swipe is one page. A page is as tall as what it shows, from 120 to 600px, square until the size of the picture is known. Blocked images are left out, and leave the pager when they are blocked.
- A tap on a picture opens the image viewer on that picture. The `⋯` button of the pager, and a long-press (half a second) on the media, open the media menu for what the page shows: an image, a video, or an outside embed.
- Media menu (`MediaActionSheet`): a sheet whose rows come in this order, each only where it can act — `갤러리에 저장` for an image or a video of the post, never for an outside embed; `공유` for every kind; `URL 복사` for every kind, the address of the media and not of the post; `이미지 차단` for an image only. `닫기` is always there. Saving to the gallery (an image or a video of a post) and sharing go through the native plugin `@gyo-community/media`. From Android 10 on, saving asks for no permission; below it the app declares the storage permission up to Android 9 (`maxSdkVersion="28"`), which is compiled but was never run — no such device was at hand.
- Blocking an image hides it at once from every post that shows it. Images are blocked by address. A fingerprint of the picture is stored with the block, but the pictures shown are not fingerprinted, so the same picture under another address is not hidden yet.
- Saving a post: the card's `저장` button saves it to 저장함 and becomes `저장 취소` (`aria-pressed`); the same button unsaves it. `링크 복사` copies the address of the post.
- Inline video (`InlineVideoPlayer`): a video starts only when the reader taps `재생`, and nothing of the video is fetched before the tap — only its poster. It starts muted and loops. Its controls: `재생` / `일시정지`, `음소거` / `음소거 해제`, `전체 화면`, a progress bar to scrub with the time `m:ss / m:ss`, and a buffering indicator. The controls hide after 3 seconds of playing; a tap on the stage shows or hides them and never plays or pauses. The stage keeps the shape it reserved — 16:9, or the ratio known for the video — and the video is letterboxed in it. One video plays and loads at a time; under 40 % on screen, a playing video pauses. Full screen is asked of the player's own element, where its controls stay; the shell's own Back leaves it, so the player adds no history entry for it. A clip the site made of a GIF has `재생` / `일시정지` only. A video that cannot be loaded says `동영상을 불러올 수 없습니다` over its poster, with `탭하여 재시도`.
- Comments: under a post's text, the preview `댓글 N개 모두 보기` with the first comment the body lists. It is a button if, and only if, the body has arrived and lists at least one comment; a tap opens the comments sheet (`CommentsSheet`) over the feed, and nothing else opens it. The sheet is to read only — nothing in it writes, recommends or logs in — and makes no request. Its header says `댓글 N개`. It lists what the body lists, in that order: the best comments, marked `BEST`, first, then every other comment, each with its replies nested under it. A body that arrived without a comment shows no preview: nothing to tap.
- Counts: recommend / comment / view — display-only (there is no recommend action). Until a post's body has arrived, the counts row shows what the site's listing counted (`post.commentCount`); once it has, the comment count is `N` as defined next.
- Comment count: `N = listedCommentCount(detail.comments)` — every comment the body lists and every reply under it, at any depth, each once; not the total the site shows for the post. Whether there is a preview is a separate gate, `comments.length > 0`; the site's count never decides it. Once the body has arrived, the same `N` is in the card's counts row, in the preview, in the sheet's header and in the dialog's label. A body that arrived with no comment shows `0`, whatever the site counted. A comment's recommend count of `0` is shown as `0`.
- No navigation to a detail screen.

### Image viewer (`ImageViewer`)

The viewer is the widget `ImageViewer`: an overlay over the page, not a route, opened by a tap on a picture of a card. It shows the images of that post, the blocked ones left out, and opens on the one that was tapped.

- Over everything, on black, inside the safe area of the screen; a modal dialog named `이미지 보기`. It does not go full screen itself, so the system bars stay as the page leaves them.
- One image at a time. Paged by a swipe — one swipe is one image — by the `이전` and `다음` buttons, and by the keys `←` and `→`. A tap does not page, not even on the left or right third of the viewer.
- Always a `닫기` button; the position `N / M`, with `이전` and `다음`, when there is more than one image. The buttons are 44px, and switched off at the ends.
- Pinch to zoom, up to 4×. A picture is panned only once it is zoomed. A double-tap puts a zoomed picture back to 1×, and never pages. The keys `+` and `-` zoom one step at a time (1, 2, 3, 4); the button `확대` goes to 2×, and `원래 크기` back to 1×. `확대` is switched off until the picture has loaded, and for a picture that cannot be zoomed.
- A picture narrower than the screen — a strip — is shown at the width of the viewer and scrolled up and down; it is not zoomed.
- The `⋯` button, and a long-press on the picture, open the media menu for that image: save it to the gallery, share it, copy its address, or block it. Saving to the gallery and sharing work here as from the card, for an image of a post.
- A picture that is blocked while the viewer is open leaves it; when none is left, the viewer closes itself.
- A picture that does not load says `이미지를 불러오지 못했습니다`, with `다시 시도`.
- Closed by Back, `닫기` or `Esc`. On close the page is where it was, and the focus goes back to the picture that opened the viewer.

### BookmarksView (저장함)

- Pushed route `/bookmarks`, from the 저장한 게시물 row of Settings. Its app bar is titled 저장함, with a way back.
- The saved posts, most recently saved first, each as the feed shows a card: the author, counts and title that were saved with it, and its body, which is asked for once when the list is shown. While the body loads, the card shows the feed's skeleton.
- Blocked images are hidden here as in the feed.
- A body that failed stays inside the card, which keeps what was saved of the post: its author, counts and title, and the thumbnail of its listing. The card says why, and offers `다시 시도` where there is something to try again:
  - Cannot connect: `연결할 수 없어 본문을 불러올 수 없어요`, with `저장한 때의 글만 보여요`, and `다시 시도`.
  - Any other failure: `불러오기 실패 — ` and the reason, with `다시 시도`.
  - The site answered 404 or 410: `삭제되었거나 비공개된 게시물이에요`, with nothing to try again.
- Unsaving: the card's `저장 취소` button. The post leaves the list; when that failed, `저장을 취소하지 못했어요` says so and the post stays.
- The comment preview opens the comments sheet here as well, an overlay over `/bookmarks`.
- Empty: `저장한 게시물이 없어요`, with the hint `좋아하는 글을 북마크해 보세요`.
- Here too: the image viewer, the video viewer and the media menu open from a card of 저장함 and from its comments sheet, as on `/`.

### BlockedImagesView (차단된 이미지)

- Pushed route `/blocked-images`, from the 차단된 이미지 row of Settings, which shows the count `N개`. Its app bar is titled 차단된 이미지, with a way back.
- One row per blocked image, most recently blocked first: the picture itself, unfiltered; when it was blocked; its address; and `차단 해제`.
- `차단 해제` shows the image again in every post at once and takes the row off the list: `차단을 해제했어요`. When it failed: `차단 해제에 실패했어요`, and the image stays blocked.
- The thumbnail is not a button: the image viewer is not opened from here yet.
- Empty: `차단된 이미지가 없어요`, with the hint `이미지를 열어 메뉴에서 차단할 수 있어요`.
- Images are blocked by address (HomeView, above): the same picture under another address is not hidden.

## 7. User Flows

### Flow 1: First Launch

```
App Open → Home (loading skeleton)
  → First page fetched → 웃긴자료 feed appears
```

Home is the first screen: no dialog comes before it, and nothing has to be agreed to or set up.

### Flow 2: Content Consumption

```
Home → Scroll 웃긴자료 feed → read inline (title + body + media)
  → Tap image → image viewer → swipe → back
  → ⋯ or long-press on the media → media menu → back
  → Tap "댓글 N개 모두 보기" → comments bottom sheet → back
  → Continue scrolling feed
```

> No separate detail screen — everything is read inline.

### Flow 3: Keep a post

```
Home → Tap 저장 on a card (it becomes 저장 취소)
  → AppBar gear → Settings → 저장한 게시물 → 저장함 → read the saved posts
  → Tap 저장 취소 → the post leaves the list
```

### Flow 4: Block an image

```
Home → ⋯ or long-press on a picture → 이미지 차단
  → the picture leaves every post that showed it; the toast offers 취소, which takes the block back
  → or later: AppBar gear → Settings → 차단된 이미지 (N개) → 차단 해제
```

## 8. Interaction Patterns

### Screen Transitions

- Forward navigation: the WebView's history (`/settings`, `/bookmarks` and `/blocked-images` are pushed).
- Back navigation: system back gesture or button, which leaves the page in the history.
- Comments sheet: slides in from the bottom over the feed (`250ms`, `ease-out`; no motion under reduced motion) and is removed at once when closed, with no exit animation. It is an overlay, not a route: opening it pushes one entry of the history, at the page's own address. System Back, 닫기, the scrim and Esc all leave it through that one entry, so Back closes the sheet first and only the next Back leaves the page. On close the page is where it was scrolled, and the focus goes back to the preview that opened the sheet.
- Media menu: a sheet made of the same `BottomSheet` as the comments sheet — every sheet of the app is, and shadcn's sheet and drawer are not used. It slides in and is removed the same way, and holds one history entry of its own. Opened over the image viewer, it is the frontmost overlay: Back closes it first, and the viewer under it stays.
- Image viewer: an overlay over everything, not a route, with one history entry of its own, like the sheets. It appears at once, with no transition of the picture growing out of its card. Closed by Back, 닫기 or Esc; the page keeps its scroll and the focus goes back to the picture that opened it.
- Overlays over overlays: each one pushes its own entry, so Back closes the frontmost first — the menu, then the viewer, then the sheet it was opened from — and leaves the page only when none is open. An overlay stays open when Back lands on the entry of one opened after it, so three can be open at once.
- Full screen of a video: asked of the player's own element, where its controls stay. The Android shell's own Back leaves full screen before the page hears of it, so the player adds no history entry for it.

### Gestures

- Pull-to-refresh: Home feed, by pulling down at the top of the page; the floating 맨 위로 button loads the first page again too. **Refresh is the one exception to "a gesture is never the only way"** (the owner's decision, 2026-11-28): at the top of the page pulling is the way. The app bar has no refresh button, and its title is plain text. A touch that starts inside a dialog — a sheet, the viewer — is the dialog's, never a pull.
- Infinite scroll: Home feed (pagination triggers near the end of the loaded list).
- Expand/collapse: post body text (`더보기`/`접기`).
- Comments sheet: no drag handle — it cannot be dragged or swiped away. It closes by Back, 닫기, the scrim or Esc. Its list scrolls on its own while the page behind is locked, and a tap or a touch inside it does not reach the page.
- Pager of a card: a swipe is one page, however fast the fling; the pager takes the height of the page it lands on.
- Comment media: a picture is a button that opens the image viewer on that comment's pictures; a video, shown by its poster with a play icon, is a button that opens the full-screen video viewer (`CommentVideoViewer`), which plays at once, muted, and goes full screen through its player; a long-press on either opens the media menu. Where a page opens nothing with them, a thumbnail is a plain picture with no icon.
- Media menu: reached by the `⋯` button — by a tap, or by the keyboard, since it is a button — and by a long-press, a finger held half a second without moving, on the media of a card or on a picture in the viewer. Letting go of the long-press is not also a tap.
- Image viewer: a swipe is one image. A pinch zooms, up to 4×; a zoomed picture is panned by a drag; a double-tap puts it back to 1× and never pages. A tap does nothing: a tap on the left or right third of the viewer does not page — the swipe, the `이전` / `다음` buttons and the keys `←` / `→` do. A strip of a picture is scrolled up and down.
- Video: `재생` starts it. A tap on the stage shows or hides the controls and never plays or pauses. The progress bar scrubs, and a touch on it does not reach the page.

### Feedback Patterns

- Loading: skeleton/shimmer feed cards. A picture of a card holds its place as a muted box, square, until its size is known; the viewer shows a placeholder until its picture has loaded; a video shows a buffering indicator from the tap until it plays, and whenever the data runs out.
- Error: inline error message with retry button, never blank screen. A feed that cannot be loaded says `피드를 불러올 수 없습니다`, with `다시 시도`; with one community, a failed list is the feed's error, not a notice on one tab. A post whose body failed is an error card (HomeView). In a card, a picture that did not load keeps its place and says `이미지를 불러오지 못했습니다` with `다시 시도`; a video says `동영상을 불러올 수 없습니다` with `탭하여 재시도`.
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
- `오류 정보 복사`: `오류 정보를 복사했어요`; when it failed, `오류 정보를 복사하지 못했습니다`.
- 차단 해제: `차단을 해제했어요`; when it failed, `차단 해제에 실패했어요`, and the picture stays blocked.
- Offline: no cached content and no "Last updated" banner; neither is planned unless the user asks (§9).
- Adult content: no warning and no setting for one.

## 9. State of the App

### What is built

| Feature | What there is |
|---------|---------------|
| Feed | Home `/`: the 웃긴자료 feed of 웃대 as inline cards (text, images, video); the body of each post fetched as the post is shown; paging; refresh by pull and from the way up; loading, error and empty states (§6) |
| Image viewer | Full screen, swipe, pinch-zoom; for the images of a post's card and for the pictures of a comment |
| Comments sheet | Reading only, opened from a card's preview |
| Media of a card and of a comment | Image carousel; inline video, one at a time; the media menu (save to the gallery, share, copy the address, block an image); a comment's video opens full screen; a long-press on a comment's picture or video opens the menu |
| Saving a post | `저장` / `저장 취소` and `링크 복사` on a card; 저장함 lists the saved posts |
| Blocked images | `이미지 차단` in the media menu; 차단된 이미지 lists them, each with `차단 해제` |
| Settings | The community switch, the version, the source link |
| Shell | `shell/`: the WebView shell, with the relay (`@gyo-community/http`) and the media plugin (`@gyo-community/media`) |
| Relay check | `/relay-check`, a development aid: checks of the native relay on a device |
| Deploy and build | `deploy-web.yml` and `build-shell.yml` (below) |

Checked on an emulator's WebView (Android 14) and on a phone (Galaxy Z Flip6, Android 16, WebView 157). On both the page was read and driven through the WebView's debug protocol, on the phone its touches as well; saving to the gallery and the share chooser went through the native plugin on both. Not checked yet: a finger on the glass (how a pinch, a fling or a long-press feel), a screen reader, and Android 9 and earlier.

### Where it is served

The web app is a static site. `npm run build` writes it to `web/dist`; a Cloudflare Worker holds those files and runs no code (`web/wrangler.jsonc`: assets only, and a path the site does not have gets `index.html`). It is served at `https://keek-news.notion-blog-proxy.workers.dev`, which the shell's `standalone` profile opens. So a change to the web app reaches every installed app on its next launch; no new APK is needed for it. (The other profiles of `shell/gyo.config.json`, `development` and `dev-server`, open the dev server instead: `shell/README.md`.)

### How a change is deployed, how a release is made

GitHub Actions runs two workflows (`.github/workflows/`):

- **`deploy-web.yml` — the web app.** On a push to `master` that touches `web/**`, and on manual dispatch: `npm ci`, `npm run check`, then the deploy to Cloudflare. The token is the repository secret `CLOUDFLARE_API_TOKEN` (with `CLOUDFLARE_ACCOUNT_ID`); nothing secret is in the repository.
- **`build-shell.yml` — the APK.** On a push to `master` that touches `shell/**` or the gyo plugins (`web/package.json`, `web/package-lock.json`) it builds the release-signed APK and keeps it as a workflow artifact, to show that the shell still builds; nothing is released. On a `v*` tag it builds and creates the GitHub Release of that tag: the APK, and as its notes the section of `RELEASE_NOTES.md` whose heading starts with the tag. Nothing is released unless both hold: the tag equals `v<version>`, where `version` is the one in `shell/gyo.config.json`, and that section exists. `platforms.android.versionCode` is the Android version code (10000 × major + 100 × minor + patch), kept above the Flutter app's last code (72) so that an update installs over it. Release signing uses the repository secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

A normal release is published only when the user decides it. A push to `master` never releases.

### What a release means for someone who has the Flutter app

The web app replaced the Flutter app in place — same package `com.keek_news.app` and signing key — so an installed Flutter app updates into it. The Flutter app checks `releases/latest` and offers a newer version; a release of the web app (a version above 3.14.3) therefore reaches them as an update, installs over their app, and from then on their app is the web app.

Two things are known to be lost or missing there. Both are open items, not promises:

1. The web app does not read what the Flutter app saved: bookmarks, settings and blocked images start empty.
2. The web app has no in-app check for a new version, so later updates are installed by hand from GitHub Releases until that exists.

### Open

- **The in-app check for a new version.** Until it exists, an update is an APK to install by hand.
- **Reading what the Flutter app saved.** The web app keeps its own bookmarks, settings and blocked images in the storage of its page (`localStorage`), and starts empty.
- **An offline cache with a "Last updated" banner.** Not planned unless the user asks; the Flutter app never had one either.

### Dropped: the other communities (W-09)

By the user's decision of 2026-11-28 the web app serves 웃대 alone (§1). 오늘의유머, 개드립, 뽐뿌, 보배드림, 루리웹 and 네이트판 are not planned for it; if they are ever wanted, they are designed and built anew, not resumed.

### Not planned

iOS (there is no iOS shell), and an image cache of the app's own.

## 10. Risk Management

| Risk | Impact | Mitigation |
|------|--------|------------|
| Site HTML structure changes | The parser reads nothing, or the wrong thing; posts show errors | One board, one parser: a single point of fix. Graceful degradation: a post whose body cannot be read becomes an error card with `다시 시도` and `오류 정보 복사`, and the rest of the feed stands. A fix is a web change, deployed from `master`, and reaches every installed app on its next launch. The page samples in `web/test/fixtures/` and the tests that read them pin what the parser expects. |
| Site blocks app access | The feed cannot be loaded | The relay sends the site's own mobile user agent and Referer and keeps its cookies in a jar (`web/src/service/service_locator.ts`); it is the only way the app talks to the site. A page that comes back without a readable body is reported as `차단 또는 구조 변경 가능성`, and a refused answer keeps its status, headers and start for `오류 정보 복사`; `/relay-check` shows on a device what the relay gets. |
| Aggressive scraping triggers IP ban | App stops working | Requests come from the device, through the relay, under the site's own user agent: one list request per page and one per post shown for its body, which is not asked for again while it is loading or already here. A 503 is tried again up to three times, waiting 1, 4 and 10 seconds — or what the site's `Retry-After` names, when that is 30 seconds or less. If the site signals throttling, a hard minimum pause between requests is the fallback. |
| Store rejection | Cannot list in a store | The app is not put forward for a listing: it is distributed as an APK from GitHub Releases. It is a web page in a native shell, whose native parts are the relay and the media plugin. Non-commercial use stated. |
| Content copyright issues | Legal risk | App is a viewer. Content belongs to original authors. App does not modify or create content. |
| A `v*` tag reaches every user | Whatever APK the Release holds is offered at once to every user of the Flutter app, since it checks `releases/latest`; and once they are on the web app, nothing checks for the next version, so they update by hand | A push to `master` never releases; the tag is pushed only when the user decides, and it releases nothing without its section in `RELEASE_NOTES.md`. The shell is built and signed on every change to `shell/` or the plugins, so a shell that does not build shows before any tag. The APK holds the shell alone: the web app it opens keeps deploying from `master`, so a fault in the web app is fixed without a release. |
| The address the shell opens changes | Bookmarks, settings and blocked images stay behind: they live in the storage of the page, which belongs to one address | The address is fixed in the shell at build (`standalone` in `shell/gyo.config.json`), so it cannot change without a new APK. Moving it means moving the saved data too. |

## 11. Success Metrics

| Metric | Target |
|--------|--------|
| Crash rate | < 2%, then < 0.5% |
| Monthly active users | 300+, then 1,000+ |
| Posts viewed per session | 10+ |

Measurement: nothing in the app reports these. There is no analytics SDK and no backend; the one figure that can be read today is the number of downloads of a Release's APK on GitHub.
