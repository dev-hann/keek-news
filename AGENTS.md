# AGENTS.md

Guidelines for AI coding agents working on this project.

## Architecture & Conventions

- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 4-layer rules (Service → Repository → UseCase → Provider)
- Naming: [docs/NAMING_CONVENTIONS.md](docs/NAMING_CONVENTIONS.md) — `*_repo`/`*_impl`, `*_use_case`, `*_view`, `*_dto`
- Code style: [docs/CODE_STYLE.md](docs/CODE_STYLE.md) — Equatable models, dartz Either, parser rules
- Testing: [docs/TESTING_POLICY.md](docs/TESTING_POLICY.md)
- Product scope: [docs/PRODUCT_PLAN.md](docs/PRODUCT_PLAN.md), [docs/DESIGN.md](docs/DESIGN.md)

Current scope: **웃긴자료 (pds) board only.** Active communities: dogdrip, ppomppu, todayhumor, humoruniv, bobaedream, ruliweb, natepann. Hidden (compiled in, UI-hidden): fmkorea.

## Key Files

- `lib/service/service_locator.dart` — DI registration (GetIt: `configureDependencies()` + `sl`)
- `lib/app.dart` — `KeekNewsApp` (ShadApp.router) + inlined `appRouter` (GoRouter) + ScaffoldMessenger injection
- `lib/theme/shad_theme.dart` — `AppShadTheme.dark()` (ShadThemeData with orange color scheme)
- `lib/main.dart` — entry, boots DI
- `test/helpers/shad_harness.dart` — `shadHarness(body)` / `shadApp({home, navigatorKey})` widget test helpers

## Design System

This project uses `shadcn_ui` (^0.56.0) as its design system. See [docs/DESIGN.md](docs/DESIGN.md) for the full guide. Highlights:

- App root: `ShadApp.router` (NOT `MaterialApp`). Material ThemeData is auto-derived.
- Theme access: `ShadTheme.of(context).colorScheme.*` and `textTheme.*`.
- Icons: `LucideIcons.foo` (via `package:shadcn_ui`). No Material `Icons.*`.
- Spacing: raw literals (`EdgeInsets.all(16)`). No central spacing tokens.
- Prefer shadcn primitives (`ShadCard`, `ShadButton`, `ShadBadge`, etc.) for new widgets.
- For widget tests, use `shadHarness(body)` or `shadApp({home})` — plain `MaterialApp` lacks `ShadTheme`.

## Mandatory Checks Before Committing

Pre-commit hook (husky) enforces:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

All must pass. `flutter analyze` runs with **all severities fatal** — any info, warning, or error fails the commit. `flutter test` must show **zero skipped** (the `~N` count must be 0) — unit/widget/integration tests are never skipped. The only opt-in category is smoke (`test/smoke/`, via `make smoke`). Or use: `make check`

## Commands

| Command | Description |
|---------|-------------|
| `make check` | format check + analyze + test (run before commit) |
| `make analyze` | lint check only |
| `make test` | all tests |
| `make coverage` | tests with coverage report |
| `make e2e` | E2E tests (needs device) |
| `make smoke` | Smoke tests — real network (needs device + internet) |
| `make fix` | dart format + auto-fix lint |
| `make clean` | clean and re-fetch dependencies |

## Feature Consensus Protocol

Before implementing any screen or significant feature, load and follow the `feature-consensus` skill:

```
skill({ name: "feature-consensus" })
```

**When to use**: New screens, significant new features, refactoring that changes behavior.
**When to skip**: Bug fixes, test additions, minor copy changes, refactoring without UX/UI changes.

## Prohibited Actions

- Using `late` keyword (use nullable types or constructor injection)
- "what" comments that restate what the code already expresses (allowed: concise "why" comments for non-obvious behavior, design intent, or regression rationale; public APIs keep `///` dartdoc)
- Committing code with failing tests or analyze errors
- Skipping `make check` before committing
- Skipping tests (`skip:`, `@Skip`) in unit/widget/integration tests — every test must pass. The only opt-in category is smoke tests under `test/smoke/` (gated by `SMOKE=1`, run via `make smoke`).
- Adding a new community parser without fixture HTML + tests
- Provider calling Repository/Service directly (skip UseCase)
- Registering impl class in DI instead of abstract interface
- Widget extending `ConsumerWidget`/`ConsumerStatefulWidget` (use `StatelessWidget`/`StatefulWidget`; inject data + `on*` callbacks)
- `ref.watch`/`ref.read`/`ref.listen` or provider imports inside `lib/widgets/` or page-private widgets (provider access confined to `*_view.dart` page build)
- Additional widget classes (besides the View + State pair) in a `*_view.dart` file (extract to `lib/widgets/`)
- Non-`on*` callback names on widget constructors

## Commit Convention

Use Conventional Commits:

```
feat: add ppomppu detail parser
fix: fix EUC-KR decoding edge case
refactor: extract common parser utility
test: add post detail parser tests
docs: update architecture guide
chore: update dependencies
```

## When Adding a New Feature

1. **Feature Consensus** — run `skill({ name: "feature-consensus" })` for screens/significant features
2. **model/** — entity (`extends Equatable`) + DTO (`*_dto.dart`, `toEntity()`) + failure if needed
3. **service/parser/** — HTML parser (`*_parser.dart`, static, fixture in `test/fixtures/`)
4. **repository/** — `repository/<feature>/<feature>_repo.dart` + `<feature>_impl.dart`
5. **use_case/** — `*_use_case.dart` (`XxxUseCase` class, private deps)
6. **service/service_locator.dart** — register (abstract ← impl)
7. **provider/** — Riverpod provider
8. **pages/** — `*_view.dart`
9. **widgets/** — reusable UI if needed
10. **Tests** — mirror `lib/` under `test/`; run `flutter test`
11. **Final check** — `make check` passes, then commit
