# Design

Visual design rules and direction for this project. See code files for specific values.

> **Boundary**: This document covers HOW things LOOK (theme, components, motion).
> For WHAT features exist and HOW users interact with them, see [PRODUCT_PLAN.md](PRODUCT_PLAN.md).

## Design Principles

1. **Content First** — UI chrome minimizes, content area maximizes.
2. **Visual Hierarchy** — Size, weight, and color contrast make structure instantly recognizable.
3. **Perceived Speed** — Skeleton screens, smooth animations create the illusion of speed.
4. **Familiarity** — Follow standard Korean community app visual patterns.
5. **Accessibility** — WCAG 2.1 AA compliance. 44pt touch targets. Screen reader support.

## Theme Strategy

- **shadcn_ui** is the design system library. App theme assembled in `lib/theme/shad_theme.dart` using `ShadThemeData` with `ShadOrangeColorScheme.dark()`.
- **Dark-only** for now. `ShadApp.router` is the root widget in `lib/app.dart`.
- `ShadApp` derives Material `ThemeData` internally (via `materialThemeBuilder`), so `Theme.of(context)` keeps working for any Material widgets (url_launcher, webview_flutter, etc.).
- `ScaffoldMessenger` is provided explicitly via the `builder` parameter in `KeekNewsApp` since `ShadApp` uses `WidgetsApp` (not `MaterialApp`).

## Color Rules

shadcn color tokens are used throughout:

- `ShadTheme.of(context).colorScheme.primary` — brand color (orange)
- `colorScheme.foreground` / `mutedForeground` — text on surfaces
- `colorScheme.muted` — skeleton placeholder, neutral backgrounds
- `colorScheme.border` — dividers and borders
- `colorScheme.accent` — hover/pressed states
- `colorScheme.destructive` — error states, destructive actions
- `colorScheme.primaryForeground` — text on primary

Rules:
- White-on-dark video overlays use inline literals (`Colors.white`, `Colors.black54`) — these are scrim colors tied to video chrome, not theme tokens.
- Domain-specific colors (recommend-tier thresholds) are inlined as private constants in `count_badge.dart`.

## Typography Rules

shadcn text theme uses semantic names: `h1Large`, `h1`, `h2`, `h3`, `h4`, `p` (body), `blockquote`, `table`, `list`, `lead`, `large`, `small`, `muted`.

Material `Theme.of(context).textTheme.titleMedium` etc. still works for legacy widgets — it's auto-derivedived from shadcn's `textTheme.family` field by `ShadApp.materialTheme`.

Korean text considerations (informational, not enforced by tokens):
- Letter spacing: `0` or positive. Hangul is a block script.
- Line height: 1.3–1.6x font size.
- Font: System default (Noto Sans KR on Android, Apple SD Gothic Neo on iOS).

## Spacing and Layout Rules

No central spacing tokens. Use raw literals (`EdgeInsets.all(16)`, `SizedBox(width: 8)`).

- **8pt grid** convention: prefer multiples of 4 (`4`, `8`, `12`, `16`, `24`).
- **Minimum touch target**: 44pt. Hard-coded as `44` literal where needed.
- **Screen horizontal padding**: `16` raw value.
- **Thumbnail sizes**: Three tiers — `48`, `72`, `120`.

## Elevation Rules

Material `Theme.of(context).colorScheme.surfaceContainer` for card surfaces. Material `elevation` parameter used directly (typically `0` or `1`).

## Motion Rules

No central motion tokens. Use raw literals:
- Fast: `Duration(milliseconds: 100)`
- Medium: `Duration(milliseconds: 250)`
- Slow: `Duration(milliseconds: 500)`
- Curves: `Curves.easeInOut`, `Curves.decelerate`, `Curves.accelerate`

## Component Library Rules

Components live in `lib/widgets/`. Flat directory (no atoms/molecules/organisms split).

### Patterns

| Pattern | When | Example |
|---------|------|---------|
| Direct shadcn primitive | When shadcn has a 1:1 match | `Avatar` → `ShadAvatar` |
| Hybrid wrapper | Wrap shadcn primitive + business logic | `ActionButton` → `ShadIconButton.ghost` + active toggle |
| Custom composition | Compose multiple shadcn primitives + business plumbing | `FeedCard` → `ShadCard` + `ShadAvatar` + `ShadBadge` + `ShadButton.Icon` |
| Pure plumbing | Video/image rendering where shadcn has no surface | `InlineVideoPlayer`, `VideoSurface`, `RetryableNetworkImage` — uses ShadTheme colors only |

### Rules

- Every interactive widget MUST expose `Semantics` labels.
- Color is never the sole indicator of state. Pair with icon, text, or shape.
- Component variants are constructor parameters, not separate widget classes.
- No additional widget classes in `*_view.dart` files — extract to `lib/widgets/`.

### Widget Inventory (after shadcn migration)

| Widget | shadcn primitive |
|--------|-----------------|
| `Avatar` | `ShadAvatar` |
| `ActionButton` | `ShadIconButton.ghost` |
| `CountBadge` family | `ShadBadge` |
| `MediaCountBadge` | `ShadBadge` |
| `ScrollToTopButton` | `ShadIconButton` |
| `StaleDataBanner` | `ShadAlert` |
| `SettingsTile` | `ShadTheme` colors (no shadcn ListTile primitive) |
| `SettingsGroup` | `ShadSeparator` dividers |
| `FeedCard` | `ShadCard` + composition |
| `ErrorStateView` retry | `ShadButton.outline` |
| `SkeletonBox` | Custom (shadcn Skeleton ❌ upstream) |
| `InlineVideoPlayer` controls | Material `IconButton` (white-on-dark video chrome) |

## Icon System

Icons use `lucide_icons_flutter` (re-exported by `shadcn_ui`).

- Import via `import 'package:shadcn_ui/shadcn_ui.dart';` then use `LucideIcons.foo`.
- No Material `Icons.*` references in widget code.
- For state-variant icons (e.g., bookmark outline vs filled), use distinct lucide names: `LucideIcons.bookmark` (idle) vs `LucideIcons.bookmarkCheck` (active).
- Video chrome uses `Icons.play_arrow` etc. only where lucide lacks equivalents — currently none, all migrated.

## Accessibility Requirements

- All interactive elements have `Semantics` labels.
- Color is never the sole indicator of state.
- Font size respects system accessibility settings.

## Reference: Code File Locations

| Concern | File |
|---------|------|
| Theme assembly | `lib/theme/shad_theme.dart` |
| App root | `lib/app.dart` (`KeekNewsApp` + `appRouter`) |
| Widgets | `lib/widgets/` (flat) |
| Pages | `lib/pages/` |
| Test harness helper | `test/helpers/shad_harness.dart` |
