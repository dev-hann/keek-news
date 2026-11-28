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
- **App root:** `web/src/app.tsx`. A page is chosen by path (`/`, `/settings`) through the browser history (`web/src/utils/router.ts`); Back leaves the page.
- **System font of the device** (Noto Sans KR on Android). No web font is loaded.
- **Touch targets of 44px:** shadcn's default button is 32px, so every interactive element is made `h-11` / `size-11` — through `ActionButton`, or the `className` of a button.

### Flutter app (`lib/`) — reference

- **shadcn_ui** is the design system library. App theme assembled in `lib/theme/shad_theme.dart` using `ShadThemeData` with `ShadOrangeColorScheme.dark()`.
- **Dark-only** for now. `ShadApp.router` is the root widget in `lib/app.dart`.
- `ShadApp` derives Material `ThemeData` internally (via `materialThemeBuilder`), so `Theme.of(context)` keeps working for any Material widgets (url_launcher, webview_flutter, etc.).
- `ScaffoldMessenger` is provided explicitly via the `builder` parameter in `KeekNewsApp` since `ShadApp` uses `WidgetsApp` (not `MaterialApp`).

## Color Rules

shadcn color tokens are used throughout:

| Token | Use |
|-------|-----|
| `primary` | brand color (orange) |
| `foreground` / `mutedForeground` | text on surfaces; a second line of text |
| `muted` | skeleton placeholder, neutral backgrounds |
| `border` | dividers and borders |
| `accent` | hover/pressed states |
| `destructive` | error states, destructive actions |
| `primaryForeground` | text on primary |

- **Web:** the Tailwind classes of the tokens — `bg-card`, `text-muted-foreground`, `text-primary`. No raw color values outside `web/src/index.css`.
- **Flutter:** `ShadTheme.of(context).colorScheme.*`; `Theme.of(context).colorScheme.surfaceContainer` for card surfaces.
- White-on-dark video overlays use inline literals (`#fff`, `Colors.white`, `Colors.black54`) — these are scrim colors tied to video chrome, not theme tokens.
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
- **Thumbnail sizes:** Three tiers — `48`, `72`, `120` (`size-12`, `size-18`, `size-30`).

## Elevation Rules

- **Web:** a card is a surface (`bg-card`) with a hairline (`ring-1 ring-foreground/10`) and no shadow. Only the floating scroll-to-top button has a shadow (`shadow-sm`).
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

## Component Library Rules

Components live in `web/src/widgets/` (web) and `lib/widgets/` (Flutter). Flat directory (no atoms/molecules/organisms split).

### Patterns

| Pattern | When | Example |
|---------|------|---------|
| Direct shadcn primitive | When shadcn has a 1:1 match | `Avatar` placeholder → `Avatar`; `Badge` |
| Hybrid wrapper | Wrap shadcn primitive + business logic | `ActionButton` → ghost icon button, 44px, with an accessible name |
| Custom composition | Compose multiple shadcn primitives + business plumbing | `FeedCard` → `Card` + `Avatar` + `Badge` + `ActionButton` |
| Pure plumbing | Video/image rendering where shadcn has no surface | `FeedImage` — uses tokens only |

### Rules

- Every interactive widget MUST have an accessible name (web: `aria-label`; Flutter: `Semantics` labels).
- Color is never the sole indicator of state. Pair with icon, text, or shape.
- Component variants are constructor parameters, not separate widget classes.
- No additional widget classes in `*_view.tsx` / `*_view.dart` files — extract to the widgets directory.
- A control that does nothing is never shown: an action appears with the screen that performs it.

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
| `FeedCard` | `Card` + composition | `ShadCard` + composition |
| `ErrorStateView` retry | `Button` outline | `ShadButton.outline` |
| `FeedErrorCard` actions | `Button` outline | `TextButton.icon` |
| Skeleton | `Skeleton` | `SkeletonBox` (custom) |
| Community switch | `Switch` | `ShadSwitch` |
| Snackbar / toast | `Toaster` (sonner) | `ScaffoldMessenger` |
| `StaleDataBanner` | not in the web app yet | `ShadAlert` |
| `InlineVideoPlayer` controls | not in the web app yet | Material `IconButton` |

## Icon System

Icons are Lucide in both apps.

- **Web:** `import { Settings } from 'lucide-react'`. An icon that only decorates is `aria-hidden`.
- **Flutter:** import via `import 'package:shadcn_ui/shadcn_ui.dart';` then use `LucideIcons.foo`. No Material `Icons.*` references in widget code.
- For state-variant icons (e.g., bookmark outline vs filled), use distinct lucide names: `LucideIcons.bookmark` (idle) vs `LucideIcons.bookmarkCheck` (active).

## Accessibility Requirements

- All interactive elements have accessible names.
- Color is never the sole indicator of state.
- Font size respects system accessibility settings.
- **Web:** a control that is hidden is not focusable (`tabIndex={-1}`); errors are announced (`role="alert"`), loading and refresh states through `role="status"`; tabs use `role="tab"` with `aria-selected`; 더보기 / 접기 use `aria-expanded`; focus stays visible (`outline-ring`).
- **Flutter:** every interactive widget exposes `Semantics` labels.

## Reference: Code File Locations

| Concern | Web | Flutter |
|---------|-----|---------|
| Theme | `web/src/index.css` | `lib/theme/shad_theme.dart` |
| App root | `web/src/app.tsx`, `web/src/utils/router.ts` | `lib/app.dart` (`KeekNewsApp` + `appRouter`) |
| shadcn components | `web/src/components/ui/` | — |
| Widgets | `web/src/widgets/` | `lib/widgets/` |
| Pages | `web/src/pages/` | `lib/pages/` |
| Test harness | `web/test/setup.ts` (Testing Library cleanup) | `test/helpers/shad_harness.dart` |
