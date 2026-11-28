# Design

Visual design rules and direction for this project. See code files for specific values.

> **Boundary**: This document covers HOW things LOOK (theme, components, motion).
> For WHAT features exist and HOW users interact with them, see [PRODUCT_PLAN.md](PRODUCT_PLAN.md).

## Design Principles

1. **Content First** — UI chrome minimizes, content area maximized.
2. **Visual Hierarchy** — Size, weight, and color contrast make structure instantly recognizable.
3. **Perceived Speed** — Skeleton screens, smooth animations create the illusion of speed.
4. **Familiarity** — Follow standard Korean community app visual patterns.
5. **Accessibility** — WCAG 2.1 AA compliance. 44px touch targets. Screen reader support.

## Theme Strategy

The design system is shadcn/ui for React with Tailwind CSS 4, and `lucide-react` for the icons.

- **shadcn/ui (Radix) with Tailwind CSS 4.** Components live in `web/src/components/ui/`, are added with the shadcn CLI (`npx shadcn@latest add <name>`) and stay as the CLI writes them (`web/components.json`: CSS variables on, Lucide icons).
- **Dark only, orange primary.** Tokens are the shadcn CSS variables, defined once in `web/src/index.css`: the dark set, on `:root`, with `color-scheme: dark`. There is no light set and no theme switch. No `.dark` class is put on the document, so the `dark:` variants in the code never apply.
- **App root:** `web/src/app.tsx`. A page is chosen by path (`/`, `/settings`, `/bookmarks`, `/blocked-images`, `/relay-check`) through the browser history (`web/src/utils/router.ts`); Back leaves the page. An overlay over a page — the comments sheet, the image viewer, the video viewer of a comment, the media menu — pushes one history entry at the page's own address, carrying its own id (`web/src/utils/use_history_back.ts`): Back closes the frontmost overlay first, and only the next Back leaves the page. Overlays close before a page is left, the frontmost first.
- **System font of the device** (Noto Sans KR on Android). No web font is loaded.
- **Touch targets of 44px:** shadcn's default button is 32px, so every interactive element is made `h-11` / `size-11` — through `ActionButton`, or the `className` of a button. The save button is an `ActionButton` (`size-11`); a row of the media menu is `h-14`; the buttons of the viewer and of a video are `size-11`.

## Color Rules

shadcn color tokens are used throughout:

| Token | Use |
|-------|-----|
| `primary` | brand color (orange); the played part of a video's progress bar; the icon of a save button that is pressed; a link in a text, and the `더보기` / `접기` button |
| `primaryForeground` | text on primary |
| `foreground` / `mutedForeground` | text on surfaces; a second line of text |
| `muted` | skeleton placeholder, neutral backgrounds; the placeholder of a picture before its size is known; the hover and pressed state of a button or a row |
| `card` | the surface of a card, of the app bar and of a sheet's panel |
| `background` | the page; the thumb of a switch; the play mark over the poster of a comment's video |
| `border` | dividers and borders |
| `ring` | the focus ring (`focus-visible:ring-ring/50`, `outline-ring/50`) |
| `destructive` | error states, destructive actions (`이미지 차단`; a row of the media menu that failed) |
| `popover` | the surface of a toast, through the shadcn `Toaster` |
| `input` | the track of a switch that is off |

- The Tailwind classes of the tokens — `bg-card`, `text-muted-foreground`, `text-primary`. No raw color values outside `web/src/index.css`, apart from the two files named in the last two rules.
- **The scrim exception:** `bg-black`, `bg-black/…` and `text-white` are for a surface that is a scrim or a black stage, and for nothing else but the `BEST` badge (last rule): the scrim under a sheet (`bg-black/60`), the surface of the image viewer with the white of its buttons and its position over it, the stage of a video with its chrome (its track and buttons in white at their opacities, `bg-white/…`), and the position pill and the `⋯` button of a card's pager (`bg-black/60`, `text-white`). They are scrim colors, not theme tokens, and they take no raw color value: `bg-black/60`, never a hex or an `rgb()`.
- **A community's colour** is not a token. It is `brandColor` in the metadata of the community (`web/src/model/community.ts`; 웃대's is `#EF4444`), put on by inline style where the community is named: the selected chip of the community tab bar (`CommunityTabBar`: its border, its text, and a 15 % tint behind it) and the round badge at the head of its row in Settings. The tab bar shows only with two or more communities on, so today only the Settings row is on a screen.
- Domain-specific colors (recommend-tier thresholds) are inlined as private constants in `count_badge.tsx`: the color of a recommend count follows its tier, and the `BEST` badge is red with white text.

## Typography Rules

- Text sizes through Tailwind (`text-xs`, `text-sm`, `text-base`, `text-lg`), weights `font-medium` / `font-semibold` / `font-bold`.
- Where each size is:
  - `text-lg font-semibold` — the title of a sheet; the message of an empty state.
  - `text-base font-semibold` — the title of the app bar, of a card, of a settings group.
  - `text-base` — the text of a comment; the title of a settings row; the text of a media menu row.
  - `text-sm` — the author and the body of a post, a reply, a count, a time or an address, a second line.
  - `text-xs` — a badge, a position pill, the time of a video.

Korean text rules:

- Letter spacing: `0` or positive. Hangul is a block script.
- Line height: 1.3–1.6x font size (the app sets 1.5).
- Font: the stack of `--font-sans` in `web/src/index.css` — `system-ui`, then the Korean system faces (`Apple SD Gothic Neo`, `Noto Sans KR`, `Malgun Gothic`). On Android that is Noto Sans KR. Headings use the same stack.

## Spacing and Layout Rules

No central spacing tokens. Use raw values: Tailwind classes (`p-4`, `gap-3`).

- **8pt grid** convention: prefer multiples of 4 (`4`, `8`, `12`, `16`, `24`). Tailwind's unit is 4px: `p-4` is 16, `gap-3` is 12.
- **Minimum touch target:** 44px (`h-11`, `size-11`).
- **Screen horizontal padding:** `16` (`px-4`).
- **Width:** the feed and 저장함 are at most `max-w-2xl`, centred, with `gap-3` between two cards; 설정 and 차단된 이미지 span the screen.
- **App bar** (`AppBar`): sticky, 56px high (`h-14`), `bg-card` with a 1px `border-b`; a back arrow (`size-11`) where there is a way back; the title is plain text, never a button.
- **Corners:** every rounded corner is measured from one token, `--radius` (`0.625rem`, 10px, in `web/src/index.css`): `rounded-md` is 8px (a skeleton), `rounded-lg` 10px (a small picture, a button), `rounded-xl` 14px (a card, the top edge of a sheet), `rounded-full` for what is round (the position pill, the buttons of the viewer and of a video). The one corner off the token is the `BEST` badge, which keeps Tailwind's own `rounded` (4px).
- **Thumbnail sizes:** Three tiers — `48`, `72`, `120` (`size-12`, `size-18`, `size-30`). The media of a comment is the `72` tier, by height (`h-18`). The thumbnail of a blocked image is the `72` tier, a square; the picture a saved post kept from its listing is the `48` tier.
- **Blocked image thumbnail** (`BlockedImageTile`): 72px square (`size-18`), `rounded-lg`, `bg-muted`. The picture is shown unfiltered, filling the box. While it loads the box stays empty; when it fails the box shows Lucide `ImageOff` (`size-8`, `muted-foreground`) — never a broken picture.
- **Media of a card:** a page of the pager is a box as wide as the card, as tall as the picture it shows — square until the size of the picture is known, then its ratio — between 120px and 600px. Until the size is known the box is the placeholder: `bg-muted`, under a `Skeleton` with no corner (`rounded-none`). While the body of a post is still coming, the card holds a `Skeleton` of `min(600px, 66vh)` in the place of its media. A video's stage holds 16:9, or the ratio known for the video, and the video is letterboxed in it (`object-contain`). The pager is as tall as the page shown.
- **A sheet** (`BottomSheet`): `16` from the left and right edges (`px-4`), a 44px close button (`size-11`), and a 1px `border-t` on its top edge. The comments sheet fills `70dvh`; the media menu is as high as its rows, at most `85dvh`. A row of the media menu is 56px high (`h-14`), with a `Separator` between two. In the comments sheet a reply sits one step further in per depth (`depth × 16`, `pl-4`), with a 1px `border` line on its left.
- **Community tab bar** (`CommunityTabBar`): 56px high (`h-14`), `bg-card` with a 1px `border-b`, holding chips of 44px (`h-11`, `rounded-full`), one per community that is on, named by its short name. It shows only with two or more communities on; the app serves one.

## Elevation Rules

- A card is a surface (`bg-card`) with a hairline (`ring-1 ring-foreground/10`) and no shadow. Only the floating scroll-to-top button has a shadow (`shadow-sm`). A sheet (`BottomSheet`: the comments sheet, the media menu) is a `bg-card` panel with rounded top corners (`rounded-t-xl`) and a `border-t` hairline, no shadow, over a scrim that dims the page. The image viewer and the video viewer of a comment raise no surface: each is `bg-black` over everything.

## Motion Rules

No central motion tokens. Use raw literals:

| Speed | Class |
|-------|-------|
| Fast | `duration-100` |
| Medium | `duration-250` |
| Slow | `duration-500` |

- **Curves:** `ease-in-out`; `ease-out` decelerates and `ease-in` accelerates.
- Every transition and spinner is switched off under `prefers-reduced-motion` (`motion-reduce:` utilities; a global rule in `index.css`).
- **Scrolls:** a smooth scroll is not a transition, so the global rule does not reach it. A scroll that is smooth carries `motion-reduce:scroll-auto` (Tailwind 4) and is instant under reduced motion. The pager of a card and the image viewer page that way.
- **A sheet:** every sheet is the one `BottomSheet` (the comments sheet, the media menu); the app uses neither shadcn's sheet nor its drawer. It slides in from the bottom (`slide-in-from-bottom`), at Medium speed (`duration-250`) with `ease-out`, so it decelerates as it arrives. It is removed at once when closed: there is no exit animation.
- **The pager of a card** (`FeedImageCarousel`): one swipe is one page (`snap-always`; no fling skips pages). The travel between pages is the browser's smooth scroll, instant under reduced motion; the height of the pager follows the page it moves to at Medium speed (`duration-250`, `ease-out`).
- **The image viewer** (`ImageViewer`): it opens and closes at once — there is no transition of the picture growing out of its card — and pages by a smooth scroll, instant under reduced motion. A zoom step from the button or the keys eases (`transition-transform`, `duration-250`, `ease-out`); a pinch or a pan moves the picture at once, with no transition.
- **The controls of a video:** they fade (`transition-opacity`, `duration-250`, `ease-in-out`) 3 seconds after the video started to play, or after the controls were last shown, and fade back in when they return.
- **Small moves** (`duration-100`, `ease-in-out`): the indicator of a pull follows the finger and turns over once the pull would release; the floating 맨 위로 button fades in and out.

## Component Library Rules

Components live in `web/src/widgets/`. Flat directory (no atoms/molecules/organisms split).

### Patterns

| Pattern | When | Example |
|---------|------|---------|
| Direct shadcn primitive | When shadcn has a 1:1 match | `BestBadge` → `Badge`; `Skeleton`; `Separator`; the community switch → `Switch` |
| Hybrid wrapper | Wrap shadcn primitive + business logic | `ActionButton` → `Button` ghost, icon size, 44px, with an accessible name |
| Custom composition | Compose multiple shadcn primitives + business plumbing | `FeedCard` → `Card` + `Avatar` + `Badge` + `ActionButton` |
| Pure plumbing | Video/image rendering where shadcn has no surface | `FeedImageCarousel`, `InlineVideoPlayer`, `ImageViewer` — a native scroller, `<img>`, `<video>`; no shadcn primitive for the media itself |
| Plain element | Where shadcn has no surface, and the element itself is enough | `Avatar`, `CountBadge` (a `span`); `SettingsTile` (a `button`, an `a` or a `div`); `LinkText` (an `<a>`) |
| Overlay | Over a page, not a route | `CommentsSheet`, `MediaActionSheet` — both made of `BottomSheet`: a portal, a scrim and a panel; `ImageViewer` and `CommentVideoViewer` — a portal over everything; one history entry each through `useHistoryBack` |

### Rules

- Every interactive widget MUST have an accessible name: `aria-label` where it has no text, its text where it has.
- Color is never the sole indicator of state. Pair with icon, text, or shape.
- Component variants are props, not separate components.
- No additional components in a `*_view.tsx` file — extract to the widgets directory.
- A control that does nothing is never shown: an action appears with the screen that performs it.
- The comments sheet keeps to it. It has no drag handle, since it cannot be dragged. Nothing in it writes, recommends or logs in. The media of a comment is tappable where the page opens something with it: a picture opens the image viewer, the poster of a video carries a play icon and opens the video viewer, and a long-press opens the media menu (`utils/use_long_press.ts`, which the pager and the viewer's stage use as well). Where a page opens nothing, the thumbnail stays a plain picture with no icon.
- The media menu (`MediaActionSheet`) keeps to it. Its rows come in a fixed order, and a row that cannot act is not drawn: `갤러리에 저장` for an image or a video, never for an outside embed; `공유` and `URL 복사` for every kind; `이미지 차단` for an image only, never for a video. Every sheet has its `닫기`. A running row is not a button: while a save or a share runs, the row is a status (`role="status"`), since nothing there can cancel it. The toast's `취소` comes only after an image was really blocked.
- The card of a post keeps to it where the page gives it nothing to open: with no viewer to open, a picture is not a button; with no menu to open, there is no `⋯` button and no long-press. This is the case today for the thumbnail of a blocked image on 차단된 이미지, which has no preview to open yet.
- A video keeps to it: no full-screen button where the document cannot go full screen; a clip the site made of a GIF, which has no sound and needs no way out of the card, has `재생` / `일시정지` only.

### Widget Inventory

| Widget | Made of |
|--------|---------|
| `AppBar` | a sticky `header` (`h-14`, `bg-card`, `border-b`); `Button` ghost (`size-11`) for the back arrow, named `뒤로`; a plain `h1` title |
| `Avatar` | plain `span` with a Lucide `User` |
| `ActionButton` | `Button` ghost, icon size, `size-11` |
| `CountBadge` family | plain `span` with a Lucide icon |
| `BestBadge` | `Badge` |
| `ScrollToTopButton` | `Button` outline, icon size |
| `SettingsGroup` | `Separator` dividers |
| `SettingsTile` | shadcn tokens (no list primitive) |
| `FeedCard` | `Card` + composition; ends its counts row with two `ActionButton`s, `링크 복사` and `저장` / `저장 취소` |
| `FeedDetailCard` | composes `FeedCard` and `FeedErrorCard`; `keepOnBodyError` keeps a body that failed inside the card |
| `CardBodyError` | why the body of a saved post is missing, inside its card: a `role="alert"` block, with `Button` outline (`다시 시도`) where there is something to try again |
| `FeedErrorCard` | a `role="alert"` card; its two actions, `다시 시도` and `오류 정보 복사`, are `Button` outline |
| `ErrorStateView` | a `role="alert"` block with a Lucide icon; its retry is `Button` outline |
| `FeedImageCarousel` | a scroller that snaps (`snap-x snap-mandatory`), a `Skeleton` placeholder, `Button` ghost (`⋯`), and a plain `<button>` over each picture as its tap layer |
| `SkeletonFeedCard` | `Skeleton`s in the shape of a `Card`, as one `role="progressbar"` |
| `InlineVideoPlayer` | a native `<video>` on a `bg-black` stage; its `VideoBottomBar`: `Button` ghost (`ControlButton`, 44px, white) and a native range `input` (`재생 위치`) over a track of its own |
| `CommentVideoViewer` | a portal over everything on `bg-black`, holding `InlineVideoPlayer` with `fill` and `autoStart`; `Button` ghost (`닫기`, `⋯`), 44px, white on `bg-black/60` |
| `ImageViewer` | a portal over everything; `Button` ghost (`닫기`, `확대`, `⋯`, `이전`, `다음`), 44px, white on `bg-black/60`; a `Skeleton` placeholder |
| `BottomSheet` | a portal, a scrim (`bg-black/60`), a `bg-card` panel (`rounded-t-xl border-t`), `Button` ghost (close) + `Separator` |
| `CommentsSheet` | `BottomSheet` + `CommentTile`s |
| `MediaActionSheet` | `BottomSheet` + `Button` ghost rows (`h-14`) + `Separator` |
| `BlockedImageTile` | a 72px `bg-muted` box with the picture, and `ActionButton` (`차단 해제`) |
| `EmptyStateView` | a `div` (`role="status"`) with a Lucide icon |
| `CommentTile` | `BestBadge` + `LinkText` |
| `LinkText` | a plain `<a>` (`target="_blank"`) in `text-primary underline` for each address of a text |
| `ExpandableText` | a `<p>` cut off after `maxLines`, and a plain `<button>` (`더보기` / `접기`, `aria-expanded`, `text-primary`) |
| `CommunityTabBar` | a `role="tablist"` of plain `<button>`s (`role="tab"`, `aria-selected`) |
| `PullToRefresh` | a fixed indicator (`ChevronDown`, or `LoaderCircle` while refreshing) and an `sr-only` status |
| Skeleton | `Skeleton` |
| Community switch | `Switch` |
| Snackbar / toast | `Toaster` (sonner), top-centre, gone after 2500ms |

`CommentsSheet` (`comments_sheet.tsx`) is made of `BottomSheet` (`bottom_sheet.tsx`), as `MediaActionSheet` (`media_action_sheet.tsx`) is; every sheet of the app is, and the app uses neither shadcn's sheet nor its drawer. `CommentsSheet`, `CommentTile` (`comment_tile.tsx`) and the other widgets above are in the flat `web/src/widgets/`. The strings of the comments sheet:

- `댓글 N개 모두 보기` — the preview on a post card; it is the name of its button too.
- `댓글 N개` — the header of the sheet, and the label of its dialog.
- `BEST` — a best comment, through `BestBadge`.
- `추천` — said to a screen reader before the recommend count of a comment, since the icon alone says nothing.
- `닫기` — the name of the close button; its icon is `aria-hidden`.
- `댓글이 없습니다.` — a sheet with nothing to list, under `댓글 0개`.
- `다시 시도` — the retry of an error card (`FeedErrorCard`) or view (`ErrorStateView`); a body that failed offers it, and no comments sheet.
- `0` — a count of none is shown as `0`: the comment count in a card's counts row, and the recommend count of a comment.

### Feedback

- **Loading** is a `Skeleton` in the shape of what is coming — four `SkeletonFeedCard`s for a first page, a media box for a post's body — or a spinner (`LoaderCircle`, `animate-spin`, which does not turn under reduced motion). What loads says so through `role="status"` (`새로고침 중`, `게시글을 더 불러오는 중`) or, for a skeleton, `role="progressbar"`.
- **An error** is said where it happened, as `role="alert"`: a Lucide icon (`CircleAlert`, `ImageOff`) — in `text-destructive` on a surface — the reason as text, and a `Button` outline (`다시 시도`) where there is something to try again. A failed row of the media menu is itself the alert, named for what to do (`저장 실패, 탭하여 재시도`).
- **What came of an action** is a toast, never a dialog: `Toaster` (sonner) at the top centre, on the `popover` surface, gone after 2500ms; it carries an action only where one exists (`취소` after an image was blocked).
- **Nothing to show** is `EmptyStateView`: a Lucide icon (`size-12`, `muted-foreground`), a message, and a hint of what there is to do about it.
- **A state that toggles** changes the control itself and says so: `저장` becomes `저장 취소` with `aria-pressed`, `확대` becomes `원래 크기`.

## Icon System

Icons are Lucide (`lucide-react`).

- `import { Settings } from 'lucide-react'`. An icon that only decorates is `aria-hidden`.
- For state-variant icons, use distinct Lucide names: `Bookmark` for `저장` and `BookmarkCheck` for `저장 취소`; `ZoomIn` / `ZoomOut` for `확대` / `원래 크기`; `Play` / `Pause`, `Volume2` / `VolumeX` and `Maximize` / `Minimize` in the controls of a video. A spinner is `LoaderCircle`.

## Accessibility Requirements

- All interactive elements have accessible names.
- Color is never the sole indicator of state.
- Font size respects system accessibility settings.
- A control that is hidden is not focusable (`tabIndex={-1}`); errors are announced (`role="alert"`), loading and refresh states through `role="status"`; a community chip is `role="tab"` with `aria-selected` (the tab bar shows only with two or more communities on, which the app does not have); 더보기 / 접기 use `aria-expanded`; focus stays visible (`outline-ring`). This holds for what is shown in the page: an error card, the error inside a card, a row of the media menu that failed, a picture or a video that did not load. Toasts are the exception, by the library's design: they come from sonner, whose toaster is one polite live region (`aria-live="polite"` on its section), so a failure said in a toast is announced the same way as any toast, not as `role="alert"`.
- **The comments sheet:** `role="dialog"` with `aria-modal="true"`, labelled `댓글 N개`. The focus starts on 닫기 and stays in the sheet: Tab turns back at its first and last stop, and a focus sent outside comes back in. Esc closes it. The page behind cannot scroll while it is open. Closed by any path — Back, 닫기, the scrim or Esc — the focus returns to what opened it, the preview, and nothing of the sheet keeps the focus. Back closes the sheet before it can leave the page: it holds one history entry.
- **Every dialog:** `role="dialog"` with `aria-modal="true"`, named by its label — `댓글 N개` for the comments sheet, `미디어 메뉴` for the media menu, `이미지 보기` for the viewer, `동영상 보기` for a comment's video. Each behaves as the comments sheet does: the focus starts on 닫기, Tab turns back at both ends, the page behind cannot scroll, and on close the focus returns to what had it. Only the frontmost dialog holds the focus (`web/src/utils/dialog_stack.ts`): the media menu opened over the image viewer owns the focus, and Esc and Tab are its own, until it closes; the viewer under it does not pull the focus back.
- **The image viewer's keys:** `Esc` closes it, `←` / `→` page, `+` / `-` zoom a step, `Tab` stays inside.
- **The names of the media of a post**, all in Korean, each on a 44px target. A control is named by what a tap does; its icon is `aria-hidden`.
  - Card: `저장` / `저장 취소` (with `aria-pressed`), `링크 복사`, and the count badges `추천 N`, `댓글 N`, `조회 N`, which say what is counted since the icon alone does not.
  - Pager: `더보기` for the `⋯` button, with `aria-haspopup="dialog"`; the position `이미지 N / M` as a status; `N번째 이미지` for the tap layer over each picture.
  - Video: `재생` / `일시정지`, `음소거` / `음소거 해제`, `전체 화면` / `전체 화면 종료`, and `재생 위치` for the scrubber, whose value is read as the time. Before the first tap the whole stage is one button, `재생`; after a failure, `탭하여 재시도`; while the controls are hidden, `컨트롤 표시`. A hidden control is not focusable.
  - Viewer: `닫기`; `확대` / `원래 크기` (with `aria-pressed`); `이전` and `다음`, switched off at the ends; `더보기`, with `aria-haspopup="dialog"`; the position `이미지 N / M` as a status; `N번째 이미지` as the `alt` of each picture.
  - Media menu: `갤러리에 저장`, `공유`, `URL 복사`, `이미지 차단`; a running row `저장 중…` / `준비 중…` as a status; a failed row `저장 실패, 탭하여 재시도` / `공유 실패, 탭하여 재시도` as an alert.
  - 차단된 이미지: `차단 해제`. The picture has no name of its own: the address next to it says what it is. `전체화면으로 보기` is not used yet — `BlockedImageTile` has that name ready for a preview button, but no page gives it one, so there the thumbnail is not a button.
- **The bars and the settings**, also in Korean: `뒤로` for the back arrow of the app bar, `설정` for the gear of Home, `맨 위로` for the floating button, `웃긴대학 보기` for the community switch, and the text of a settings row for the row itself.
- **The media menu has a way that is not a gesture:** the `⋯` button is a button, so the keyboard reaches it too (Tab, then Enter). The long-press only adds to that.

## Reference: Code File Locations

| Concern | Where |
|---------|-------|
| Tokens of the theme | `web/src/index.css` |
| shadcn configuration | `web/components.json` |
| shadcn components | `web/src/components/ui/` |
| App root | `web/src/app.tsx`, `web/src/main.tsx` |
| Paths and navigation | `web/src/utils/router.ts` |
| An overlay's history entry | `web/src/utils/use_history_back.ts` |
| Dialog stack (which dialog holds the focus) | `web/src/utils/dialog_stack.ts` |
| Long-press | `web/src/utils/use_long_press.ts` |
| Providers | `web/src/provider/` |
| Widgets | `web/src/widgets/` |
| Pages | `web/src/pages/` |
| Communities and their colour | `web/src/model/community.ts` |
| Test setup | `web/test/setup.ts` (Testing Library cleanup) |
