# Design

Visual design rules and direction for this project. See code files for specific values.

> **Boundary**: This document covers HOW things LOOK (tokens, colors, typography, spacing, components).
> For WHAT features exist and HOW users interact with them, see [PRODUCT_PLAN.md](PRODUCT_PLAN.md).

## Design Principles

1. **Content First** — UI chrome minimizes, content area maximizes. Every pixel of UI must justify its existence.
2. **Visual Hierarchy** — Size, weight, and color contrast make title, thumbnail, and metrics instantly recognizable without reading. No scanning effort required.
3. **Perceived Speed** — Skeleton screens, shimmer placeholders, and smooth animations create the illusion of speed. Motion tokens ensure consistent timing across all transitions.
4. **Familiarity** — Follow standard Korean community app visual patterns (에브리타임, 디시인사이드, Reddit). Users should recognize the layout instantly.
5. **Accessibility** — WCAG 2.1 AA compliance. Minimum 44pt touch targets. Screen reader support. Color-blind safe.

## Theme Strategy

- **6 color themes** based on the original humoruniv.com site: Orange (default), Red, Blue, Green, Classic, Mono.
- **Dark mode is an orthogonal toggle**, not a 7th theme. Every theme has both light and dark variants (12 total schemes).
- All theming uses `flex_color_scheme`. See `lib/core/themes/app_schemes.dart` for color definitions and `lib/core/themes/app_theme.dart` for ThemeData assembly.
- Theme switching is instant. No restart required.

## Color Token Rules

Token categories follow Material 3 semantic naming:

- `primary`, `onPrimary`, `primaryContainer` — brand color and its derivatives
- `surface`, `surfaceContainer`, `scaffold` — background layers
- `onSurface`, `onSurfaceVariant` — text colors on surfaces
- `outline` — dividers and borders
- `error` — error states, destructive actions

Rules:
- `onPrimary` text MUST pass WCAG AA contrast against `primary`. If the brand color is too light for white text, use dark `onPrimary` text instead.
- Domain-specific colors (e.g., "recommend") are aliases of semantic tokens, not separate first-class tokens. Document the alias in code comments.
- All token values are defined in `lib/core/themes/app_colors.dart`.

## Typography Rules

Korean text requires different treatment than Latin text:

- **Letter spacing**: Always `0` or positive. Negative letter-spacing is for Latin display type. Hangul is a block script — negative tracking causes character collision and reduces legibility.
- **Line height**: 1.3–1.6x font size. Body text needs 1.5–1.6 for comfortable Korean reading.
- **Font**: System default only (Noto Sans KR on Android, Apple SD Gothic Neo on iOS). No custom font loading — it adds app size and latency.
- **Title vs body distinction**: Minimum 1pt size difference. Never share the same size between title and body roles.

Token hierarchy: `headlineLarge` > `headlineMedium` > `titleLarge` > `titleMedium` > `titleSmall` > `bodyLarge` > `bodyMedium` > `bodySmall` > `labelLarge` > `labelMedium` > `labelSmall`.

See `lib/core/themes/app_typography.dart` for specific sizes and weights.

## Spacing and Layout Rules

- **8pt grid system** with 4pt half-steps for fine adjustments. All spacing values MUST be multiples of 4.
- **Minimum touch target**: 44pt (Apple HIG) to 48pt (Material). No interactive element smaller than 44pt in any dimension.
- **Screen horizontal padding**: Defined by a single token. Applied consistently across all screens.
- **Thumbnail sizes**: Three tiers — small, medium, large. Each tier has a fixed pixel value in `app_sizes.dart`.

See `lib/core/themes/app_spacing.dart` and `lib/core/themes/app_sizes.dart`.

## Elevation Rules

Five elevation levels defined in `lib/core/themes/app_elevation.dart`.

- Light mode: standard shadow-based elevation.
- Dark mode: tonal elevation (surface tint overlay, no shadows). This is Material 3 convention.

## Motion Rules

- Three duration tokens (fast, medium, slow) and three easing curves (standard, decelerate, accelerate).
- All animations MUST use these tokens. No hardcoded `Duration` or `Curves` in widget code.
- Screen transitions: use platform-default (slide on iOS, fade on Android).
- Shared element transitions for image tap → fullscreen viewer.

See `lib/core/themes/app_durations.dart`.

## Component Library Rules

Components follow Atomic Design:

### Hierarchy

| Level | Responsibility | Examples |
|-------|---------------|----------|
| **Atom** | Single visual element, no domain knowledge | Avatar, CountBadge, FeedMedia, Thumbnail, SkeletonBox, LoadingIndicator |
| **Molecule** | Combination of atoms, represents a domain concept | FeedCard, FeedImageCarousel, InlineVideoPlayer, CommentTile, SettingsGroup, DarkModeSelector |
| **Organism** | Screen-level composition of molecules | (Feed composition currently lives in `presentation/widgets/` — e.g. `feed_list.dart` — because it wires providers + navigation. Core `organisms/` is intentionally empty for the single-screen Phase 1.) |

### Rules

- Atoms MUST NOT import from `domain/` or `data/`. They receive all data via constructor parameters.
- Molecules may use domain entities for type safety in their interface, but MUST NOT contain business logic.
- Organisms compose molecules and handle layout. They MAY connect to providers.
- Every component MUST handle these states where applicable:
  - **loading** — show skeleton/shimmer
  - **loaded** — show content
  - **error** — show error state with retry
  - **empty** — show empty state with message
- Component variants are defined as enum or constructor parameters, not separate widget classes.

### Required Components

The component library lives in `lib/core/widgets/`.

**Atoms**: Avatar, CountBadge (Recommend/Comment/View/Best), FeedMedia, Thumbnail, SkeletonBox, LoadingIndicator.

**Molecules**: FeedCard, FeedImageCarousel, InlineVideoPlayer, SectionHeader, SettingsGroup, SettingsTile, DarkModeSelector, StaleDataBanner, UserInfoRow.

**Organisms**: none in `core/` for Phase 1 (feed composition is in `presentation/widgets/feed_list.dart`).

**State widgets**: SkeletonFeedCard, EmptyStateView, ErrorStateView, NsfwWarningDialog.

## Accessibility Requirements

- All interactive elements have `Semantics` labels for TalkBack/VoiceOver.
- Color is never the sole indicator of state. Pair with icon, text, or shape.
- NSFW content: blur overlay by default. User opts in via settings toggle.
- Content warning on first app launch.
- Font size respects system accessibility settings where possible.

## Adding New Tokens or Components

When adding a new design token:
1. Define it in the appropriate token file under `lib/core/themes/`.
2. Write a unit test verifying the token exists and is non-null.
3. Reference the token file in this document's section.

When adding a new component:
1. Determine its level (atom / molecule / organism).
2. Define its variants and states before coding.
3. Write widget tests for all variants and states (see [TESTING_POLICY.md](TESTING_POLICY.md)).
4. Place it in the correct subdirectory under `lib/core/widgets/`.

## Reference: Code File Locations

| Concern | File |
|---------|------|
| Color tokens | `lib/core/themes/app_colors.dart` |
| Typography tokens | `lib/core/themes/app_typography.dart` |
| Spacing tokens | `lib/core/themes/app_spacing.dart` |
| Radius tokens | `lib/core/themes/app_radius.dart` |
| Size tokens | `lib/core/themes/app_sizes.dart` |
| Elevation tokens | `lib/core/themes/app_elevation.dart` |
| Motion tokens | `lib/core/themes/app_durations.dart` |
| Theme color schemes | `lib/core/themes/app_schemes.dart` |
| ThemeData assembly | `lib/core/themes/app_theme.dart` |
| Atom widgets | `lib/core/widgets/atoms/` |
| Molecule widgets | `lib/core/widgets/molecules/` |
| Organism widgets | `lib/core/widgets/organisms/` |
| State widgets | `lib/core/widgets/states/` |
