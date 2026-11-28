# Design

Visual design rules and direction for this project. See code files for specific values.

> **Boundary**: This document covers HOW things LOOK (theme, components, motion).
> For WHAT features exist and HOW users interact with them, see [PRODUCT_PLAN.md](PRODUCT_PLAN.md).

## Design Principles

1. **Content First** — UI chrome minimizes, content area maximized.
2. **Visual Hierarchy** — Size, weight, and color contrast make structure instantly recognizable.
3. **Perceived Speed** — Skeleton screens, smooth animations create the illusion of speed.
4. **Familiarity** — Follow standard Korean community app visual patterns.
5. **Accessibility** — WCAG 2.1 AA compliance. 44pt touch targets. Screen reader support.

## Theme Strategy

The design system is shadcn in both apps: shadcn/ui for React in the web app, `shadcn_ui` for Flutter. Where a rule below names a web thing and a Flutter thing, the web one is current; the Flutter one is the reference until the move is complete (PRODUCT_PLAN §9).

### Web app (`web/src/`) — current

- **shadcn/ui (Radix) with Tailwind CSS 4.** Components live in `web/src/components/ui/`, are added with the shadcn CLI (`npx shadcn@latest add <name>`) and stay as the CLI writes them.
- **Dark only, orange primary.** Tokens are the shadcn CSS variables, defined once in `web/src/index.css`.
- **App root:** `web/src/app.tsx`. A page is chosen by path (`/`, `/settings`, `/bookmarks`, `/blocked-images`, `/relay-check`) through the browser history (`web/src/utils/router.ts`); Back leaves the page. An overlay over a page — the comments sheet, the image viewer, the video viewer of a comment, the media menu — pushes one history entry at the page's own address, carrying its own id (`web/src/utils/use_history_back.ts`): Back closes the frontmost overlay first, and only the next Back leaves the page. Overlays close before a page is left, the frontmost first.
- **System font of the device** (Noto Sans KR on Android). No web font is loaded.
- **Touch targets of 44px:** shadcn's default button is 32px, so every interactive element is made `h-11` / `size-11` — through `ActionButton`, or the `className` of a button. The save button is an `ActionButton` (`size-11`); a row of the media menu is `h-14`; the buttons of the viewer and of a video are `size-11`.

### Flutter app (`lib/`) — reference

- **shadcn_ui** is the design system library. App theme assembled in `lib/theme/shad_theme.dart` using `ShadThemeData` with `ShadOrangeColorScheme.dark()`.
- **Dark-only** for now. `ShadApp.router` is the root widget in `lib/app.dart`.
- `ShadApp` derives Material `ThemeData` internally (via `materialThemeBuilder`), so `Theme.of(context)` keeps working for any Material widgets (url_launcher, webview_flutter, etc.).
- `ScaffoldMessenger` is provided explicitly via the `builder` parameter in `KeekNewsApp` since `ShadApp` uses `WidgetsApp` (not `MaterialApp`).

## Color Rules

shadcn color tokens are used throughout:

| Token | Use |
|-------|-----|
| `primary` | brand color (orange); the played part of a video's progress bar; the icon of a save button that is pressed |
| `foreground` / `mutedForeground` | text on surfaces; a second line of text |
| `muted` | skeleton placeholder, neutral backgrounds; the placeholder of a picture before its size is known |
| `border` | dividers and borders |
| `accent` | hover/pressed states |
| `destructive` | error states, destructive actions (`이미지 차단`; a row of the media menu that failed) |
| `primaryForeground` | text on primary |

- **Web:** the Tailwind classes of the tokens — `bg-card`, `text-muted-foreground`, `text-primary`. No raw color values outside `web/src/index.css`.
- **Web, the scrim exception:** `bg-black`, `bg-black/…` and `text-white` are for a surface that is a scrim or a black stage, and for nothing else but the `BEST` badge (last rule): the scrim under a sheet (`bg-black/60`), the surface of the image viewer with the white of its buttons and its position over it, the stage of a video with its chrome (its track and buttons in white at their opacities, `bg-white/…`), and the position pill and the `⋯` button of a card's pager (`bg-black/60`, `text-white`). They are scrim colors, not theme tokens, and they take no raw color value: `bg-black/60`, never a hex or an `rgb()`.
- **Flutter:** `ShadTheme.of(context).colorScheme.*`; `Theme.of(context).colorScheme.surfaceContainer` for card surfaces.
- **Flutter:** white-on-dark video overlays use inline literals (`#fff`, `Colors.white`, `Colors.black54`) — these are scrim colors tied to video chrome, not theme tokens.
- Domain-specific colors (recommend-tier thresholds) are inlined as private constants in `count_badge.tsx` / `count_badge.dart`.

## Typography Rules

- **Web:** text sizes through Tailwind (`text-sm`, `text-base`, `text-lg`), weights `font-medium` / `font-semibold` / `font-bold`.
- **Flutter:** shadcn text theme uses semantic names: `h1Large`, `h1`, `h2`, `h3`, `h4`, `p` (body), `blockquote`, `table`, `list`, `lead`, `large`, `small`, `muted`.

Korean text rules:

- Letter spacing: `0` or positive. Hangul is a block script.
- Line height: 1.3–1.6x font size (the web app sets 1.5).
- Font: System default (Noto Sans KR on Android, Apple SD Gothic Neo on iOS).

## Spacing and Layout Rules

No central spacing tokens. Use raw values: Tailwind classes on the web (`p-4`, `gap-3`), raw literals in Flutter (`EdgeInsets.all(16)`, `SizedBox(width: 8)`).

- **8pt grid** convention: prefer multiples of 4 (`4`, `8`, `12`, `16`, `24`). Tailwind's unit is 4px: `p-4` is 16, `gap-3` is 12.
- **Minimum touch target:** 44px (`h-11`, `size-11`). Hard-coded as `44` in Flutter.
- **Screen horizontal padding:** `16` (`px-4`).
- **Corners:** every rounded corner is measured from one token, `--radius` (`0.625rem`, 10px, in `web/src/index.css`): `rounded-md` is 8px (a skeleton), `rounded-lg` 10px (a small picture, a button), `rounded-xl` 14px (a card, the top edge of a sheet), `rounded-full` for what is round (the position pill, the buttons of the viewer and of a video). The one corner off the token is the `BEST` badge, which keeps Tailwind's own `rounded` (4px).
- **Thumbnail sizes:** Three tiers — `48`, `72`, `120` (`size-12`, `size-18`, `size-30`). The media of a comment is the `72` tier, by height (`h-18`). The thumbnail of a blocked image is the `72` tier, a square; the picture a saved post kept from its listing is the `48` tier.
- **Blocked image thumbnail** (`BlockedImageTile`): 72px square (`size-18`), `rounded-lg`, `bg-muted`. The picture is shown unfiltered, filling the box. While it loads the box stays empty; when it fails the box shows Lucide `ImageOff` (`size-8`, `muted-foreground`) — never a broken picture.
- **Media of a card:** a page of the pager is a box as wide as the card, as tall as the picture it shows — square until the size of the picture is known, then its ratio — between 120px and 600px. Until the size is known the box is the placeholder: `bg-muted`, under a `Skeleton` with no corner (`rounded-none`). A video's stage holds 16:9, or the ratio known for the video, and the video is letterboxed in it (`object-contain`). The pager is as tall as the page shown.
- **A sheet** (`BottomSheet`): `16` from the left and right edges (`px-4`), a 44px close button (`size-11`), and a 1px `border-t` on its top edge. The comments sheet fills `70dvh`; the media menu is as high as its rows, at most `85dvh`. A row of the media menu is 56px high (`h-14`), with a `Separator` between two. In the comments sheet a reply sits one step further in per depth (`depth × 16`, `pl-4`), with a 1px `border` line on its left.

## Elevation Rules

- **Web:** a card is a surface (`bg-card`) with a hairline (`ring-1 ring-foreground/10`) and no shadow. Only the floating scroll-to-top button has a shadow (`shadow-sm`). A sheet (`BottomSheet`: the comments sheet, the media menu) is a `bg-card` panel with rounded top corners (`rounded-t-xl`) and a `border-t` hairline, no shadow, over a scrim that dims the page. The image viewer raises no surface: it is `bg-black` over everything.
- **Flutter:** Material `Theme.of(context).colorScheme.surfaceContainer` for card surfaces. Material `elevation` parameter used directly (typically `0` or `1`).

## Motion Rules

No central motion tokens. Use raw literals:

| Speed | Web | Flutter |
|-------|-----|---------|
| Fast | `duration-100` | `Duration(milliseconds: 100)` |
| Medium | `duration-250` | `Duration(milliseconds: 250)` |
| Slow | `duration-500` | `Duration(milliseconds: 500)` |

- **Curves:** `ease-in-out`; `ease-out` decelerates and `ease-in` accelerates (Flutter: `Curves.easeInOut`, `Curves.decelerate`, `Curves.accelerate`).
- **Web:** every transition and spinner is switched off under `prefers-reduced-motion` (`motion-reduce:` utilities; a global rule in `index.css`).
- **Web, scrolls:** a smooth scroll is not a transition, so the global rule does not reach it. A scroll that is smooth carries `motion-reduce:scroll-auto` (Tailwind 4) and is instant under reduced motion. The pager of a card and the image viewer page that way.
- **Web, a sheet:** every sheet is the one `BottomSheet` (the comments sheet, the media menu); the app uses neither shadcn's sheet nor its drawer. It slides in from the bottom (`slide-in-from-bottom`), at Medium speed (`duration-250`) with `ease-out`, so it decelerates as it arrives. It is removed at once when closed: there is no exit animation.
- **Web, the pager of a card** (`FeedImageCarousel`): one swipe is one page (`snap-always`; no fling skips pages). The travel between pages is the browser's smooth scroll, instant under reduced motion; the height of the pager follows the page it moves to at Medium speed (`duration-250`, `ease-out`).
- **Web, the image viewer** (`ImageViewer`): it opens and closes at once — there is no transition of the picture growing out of its card — and pages by a smooth scroll, instant under reduced motion. A zoom step from the button or the keys eases (`transition-transform`, `duration-250`, `ease-out`); a pinch or a pan moves the picture at once, with no transition.
- **Web, the controls of a video:** they fade (`transition-opacity`, `duration-250`, `ease-in-out`) 3 seconds after the video started to play, or after the controls were last shown, and fade back in when they return.

## Component Library Rules

Components live in `web/src/widgets/` (web) and `lib/widgets/` (Flutter). Flat directory (no atoms/molecules/organisms split).

### Patterns

| Pattern | When | Example |
|---------|------|---------|
| Direct shadcn primitive | When shadcn has a 1:1 match | `Avatar` placeholder → `Avatar`; `Badge` |
| Hybrid wrapper | Wrap shadcn primitive + business logic | `ActionButton` → ghost icon button, 44px, with an accessible name |
| Custom composition | Compose multiple shadcn primitives + business plumbing | `FeedCard` → `Card` + `Avatar` + `Badge` + `ActionButton` |
| Pure plumbing | Video/image rendering where shadcn has no surface | `FeedImageCarousel`, `InlineVideoPlayer`, `ImageViewer` — a native scroller, `<img>`, `<video>`; no shadcn primitive for the media itself |
| Overlay | Over a page, not a route | `CommentsSheet`, `MediaActionSheet` — both made of `BottomSheet`: a portal, a scrim and a panel; `ImageViewer` and `CommentVideoViewer` — a portal over everything; one history entry each through `useHistoryBack` |

### Rules

- Every interactive widget MUST have an accessible name (web: `aria-label`; Flutter: `Semantics` labels).
- Color is never the sole indicator of state. Pair with icon, text, or shape.
- Component variants are constructor parameters, not separate widget classes.
- No additional widget classes in `*_view.tsx` / `*_view.dart` files — extract to the widgets directory.
- A control that does nothing is never shown: an action appears with the screen that performs it.
- The comments sheet keeps to it. It has no drag handle, since it cannot be dragged. Nothing in it writes, recommends or logs in. The media of a comment is tappable where the page opens something with it: a picture opens the image viewer, the poster of a video carries a play icon and opens the video viewer, and a long-press opens the media menu (`utils/use_long_press.ts`, which the pager and the viewer's stage use as well). Where a page opens nothing, the thumbnail stays a plain picture with no icon.
- The media menu (`MediaActionSheet`) keeps to it. Its rows come in a fixed order, and a row that cannot act is not drawn: `갤러리에 저장` for an image or a video, never for an outside embed; `공유` and `URL 복사` for every kind; `이미지 차단` for an image only, never for a video. Every sheet has its `닫기`. A running row is not a button: while a save or a share runs, the row is a status (`role="status"`), since nothing there can cancel it. The toast's `취소` comes only after an image was really blocked.
- The card of a post keeps to it where the page gives it nothing to open: with no viewer to open, a picture is not a button; with no menu to open, there is no `⋯` button and no long-press. This is the case today for the thumbnail of a blocked image on 차단된 이미지, which has no preview to open yet.
- A video keeps to it: no full-screen button where the document cannot go full screen; a clip the site made of a GIF, which has no sound and needs no way out of the card, has `재생` / `일시정지` only.

### Widget Inventory

| Widget | Web (shadcn/ui) | Flutter (shadcn_ui) |
|--------|-----------------|---------------------|
| `Avatar` | plain `span` with a Lucide `User` | `ShadAvatar` |
| `ActionButton` | `Button` ghost, icon size | `ShadIconButton.ghost` |
| `CountBadge` family | plain `span` with a Lucide icon | `ShadBadge` |
| `BestBadge` | `Badge` | `ShadBadge` |
| `ScrollToTopButton` | `Button` outline, icon size | `ShadIconButton` |
| `SettingsGroup` | `Separator` dividers | `ShadSeparator` dividers |
| `SettingsTile` | shadcn tokens (no list primitive) | ShadTheme colors |
| `FeedCard` | `Card` + composition; ends its counts row with two `ActionButton`s, `링크 복사` and `저장` / `저장 취소` | `ShadCard` + composition |
| `FeedDetailCard` | composes `FeedCard` and `FeedErrorCard`; `keepOnBodyError` keeps a body that failed inside the card | `ShadCard` + composition |
| `ErrorStateView` retry | `Button` outline | `ShadButton.outline` |
| `FeedErrorCard` actions | `Button` outline | `TextButton.icon` |
| `FeedImageCarousel` | a scroller that snaps (`snap-x snap-mandatory`), a `Skeleton` placeholder, `Button` ghost (`⋯`), and a plain `<button>` over each picture as its tap layer | `PageView` |
| `InlineVideoPlayer` | a native `<video>` on a `bg-black` stage; its `VideoBottomBar`: `Button` ghost (`ControlButton`, 44px, white) and a native range `input` (`재생 위치`) over a track of its own | `VideoPlayer` + Material `IconButton` |
| `CommentVideoViewer` | a portal over everything on `bg-black`, holding `InlineVideoPlayer` with `fill` and `autoStart`; `Button` ghost (`닫기`, `⋯`), 44px, white on `bg-black/60` | `CommentVideoViewerView` |
| `ImageViewer` | a portal over everything; `Button` ghost (`닫기`, `확대`, `⋯`, `이전`, `다음`), 44px, white on `bg-black/60`; a `Skeleton` placeholder | `PageView` + `InteractiveViewer`, Material `IconButton` |
| `BottomSheet` | a portal, a scrim (`bg-black/60`), a `bg-card` panel (`rounded-t-xl border-t`), `Button` ghost (close) + `Separator` | `showModalBottomSheet` |
| `CommentsSheet` | `BottomSheet` + `CommentTile`s | `showModalBottomSheet` + `Divider` |
| `MediaActionSheet` | `BottomSheet` + `Button` ghost rows (`h-14`) + `Separator` | `showModalBottomSheet` |
| `BlockedImageTile` | a 72px `bg-muted` box with the picture, and `ActionButton` (`차단 해제`) | `RetryableNetworkImage` + `IconButton` |
| `EmptyStateView` | a `div` (`role="status"`) with a Lucide icon | `EmptyStateView` (ShadTheme colors) |
| `CommentTile` | `BestBadge` + `LinkText` | `ShadBadge` + `LinkText` |
| Skeleton | `Skeleton` | `SkeletonBox` (custom) |
| Community switch | `Switch` | `ShadSwitch` |
| Snackbar / toast | `Toaster` (sonner) | `ScaffoldMessenger` |
| `StaleDataBanner` | not in the web app yet | `ShadAlert` |

`CommentsSheet` (`comments_sheet.tsx`) is made of `BottomSheet` (`bottom_sheet.tsx`), as `MediaActionSheet` (`media_action_sheet.tsx`) is; every sheet of the app is, and the app uses neither shadcn's sheet nor its drawer. `CommentsSheet`, `CommentTile` (`comment_tile.tsx`) and the other widgets above are in the flat `web/src/widgets/`. The strings of the comments sheet:

- `댓글 N개 모두 보기` — the preview on a post card; it is the name of its button too.
- `댓글 N개` — the header of the sheet, and the label of its dialog.
- `BEST` — a best comment, through `BestBadge`.
- `추천` — said to a screen reader before the recommend count of a comment, since the icon alone says nothing.
- `닫기` — the name of the close button; its icon is `aria-hidden`.
- `댓글이 없습니다.` — a sheet with nothing to list, under `댓글 0개`.
- `다시 시도` — the retry of an error card (`FeedErrorCard`) or view (`ErrorStateView`); a body that failed offers it, and no comments sheet.
- `0` — a count of none is shown as `0`: the comment count in a card's counts row, and the recommend count of a comment.

## Icon System

Icons are Lucide in both apps.

- **Web:** `import { Settings } from 'lucide-react'`. An icon that only decorates is `aria-hidden`.
- **Flutter:** import via `import 'package:shadcn_ui/shadcn_ui.dart';` then use `LucideIcons.foo`. No Material `Icons.*` references in widget code.
- For state-variant icons (e.g., bookmark outline vs filled), use distinct lucide names: `LucideIcons.bookmark` (idle) vs `LucideIcons.bookmarkCheck` (active). The web save button does the same: `Bookmark` for `저장`, `BookmarkCheck` for `저장 취소`. The viewer's zoom button is `ZoomIn` / `ZoomOut`.

## Accessibility Requirements

- All interactive elements have accessible names.
- Color is never the sole indicator of state.
- Font size respects system accessibility settings.
- **Web:** a control that is hidden is not focusable (`tabIndex={-1}`); errors are announced (`role="alert"`), loading and refresh states through `role="status"`; tabs use `role="tab"` with `aria-selected`; 더보기 / 접기 use `aria-expanded`; focus stays visible (`outline-ring`). This holds for what is shown in the page: an error card, the error inside a card, a row of the media menu that failed, a picture or a video that did not load. Toasts are the exception, by the library's design: they come from sonner, whose toaster is one polite live region (`aria-live="polite"` on its section), so a failure said in a toast is announced the same way as any toast, not as `role="alert"`.
- **Web, the comments sheet:** `role="dialog"` with `aria-modal="true"`, labelled `댓글 N개`. The focus starts on 닫기 and stays in the sheet: Tab turns back at its first and last stop, and a focus sent outside comes back in. Esc closes it. The page behind cannot scroll while it is open. Closed by any path — Back, 닫기, the scrim or Esc — the focus returns to what opened it, the preview, and nothing of the sheet keeps the focus. Back closes the sheet before it can leave the page: it holds one history entry.
- **Web, every dialog:** `role="dialog"` with `aria-modal="true"`, named by its label — `댓글 N개` for the comments sheet, `미디어 메뉴` for the media menu, `이미지 보기` for the viewer, `동영상 보기` for a comment's video. Each behaves as the comments sheet does: the focus starts on 닫기, Tab turns back at both ends, the page behind cannot scroll, and on close the focus returns to what had it. Only the frontmost dialog holds the focus (`web/src/utils/dialog_stack.ts`): the media menu opened over the image viewer owns the focus, and Esc and Tab are its own, until it closes; the viewer under it does not pull the focus back.
- **Web, the image viewer's keys:** `Esc` closes it, `←` / `→` page, `+` / `-` zoom a step, `Tab` stays inside.
- **Web, the names of the media of a post**, all in Korean, each on a 44px target. A control is named by what a tap does; its icon is `aria-hidden`.
  - Card: `저장` / `저장 취소` (with `aria-pressed`), `링크 복사`, and the count badges `추천 N`, `댓글 N`, `조회 N`, which say what is counted since the icon alone does not.
  - Pager: `더보기` for the `⋯` button, with `aria-haspopup="dialog"`; the position `이미지 N / M` as a status; `N번째 이미지` for the tap layer over each picture.
  - Video: `재생` / `일시정지`, `음소거` / `음소거 해제`, `전체 화면` / `전체 화면 종료`, and `재생 위치` for the scrubber, whose value is read as the time. Before the first tap the whole stage is one button, `재생`; after a failure, `탭하여 재시도`; while the controls are hidden, `컨트롤 표시`. A hidden control is not focusable.
  - Viewer: `닫기`; `확대` / `원래 크기` (with `aria-pressed`); `이전` and `다음`, switched off at the ends; `더보기`, with `aria-haspopup="dialog"`; the position `이미지 N / M` as a status; `N번째 이미지` as the `alt` of each picture.
  - Media menu: `갤러리에 저장`, `공유`, `URL 복사`, `이미지 차단`; a running row `저장 중…` / `준비 중…` as a status; a failed row `저장 실패, 탭하여 재시도` / `공유 실패, 탭하여 재시도` as an alert.
  - 차단된 이미지: `차단 해제`. The picture has no name of its own: the address next to it says what it is. `전체화면으로 보기` is not used yet — `BlockedImageTile` has that name ready for a preview button, but no page gives it one, so there the thumbnail is not a button.
- **Web, the media menu has a way that is not a gesture:** the `⋯` button is a button, so the keyboard reaches it too (Tab, then Enter). The long-press only adds to that.
- **Flutter:** every interactive widget exposes `Semantics` labels.

## Reference: Code File Locations

| Concern | Web | Flutter |
|---------|-----|---------|
| Theme | `web/src/index.css` | `lib/theme/shad_theme.dart` |
| App root | `web/src/app.tsx`, `web/src/utils/router.ts`, `web/src/utils/use_history_back.ts` (an overlay's history entry) | `lib/app.dart` (`KeekNewsApp` + `appRouter`) |
| Dialog stack (which dialog holds the focus) | `web/src/utils/dialog_stack.ts` | — |
| Providers | `web/src/provider/` | `lib/provider/` |
| shadcn components | `web/src/components/ui/` | — |
| Widgets | `web/src/widgets/` | `lib/widgets/` |
| Pages | `web/src/pages/` | `lib/pages/` |
| Test harness | `web/test/setup.ts` (Testing Library cleanup) | `test/helpers/shad_harness.dart` |
