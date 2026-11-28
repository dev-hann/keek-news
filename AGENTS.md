# AGENTS.md

Guidelines for AI coding agents working on this project.

## Architecture & Conventions

- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 4-layer rules (Service → Repository → UseCase → Provider) under `web/src/`
- Naming: [docs/NAMING_CONVENTIONS.md](docs/NAMING_CONVENTIONS.md) — `*_repo`/`*_impl`, `*_use_case`, `*_provider`, `*_view`
- Code style: [docs/CODE_STYLE.md](docs/CODE_STYLE.md) — TypeScript, `Result` instead of thrown errors, parser rules
- Testing: [docs/TESTING_POLICY.md](docs/TESTING_POLICY.md) — Vitest; tests mirror `web/src/`
- Development: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- Product scope: [docs/PRODUCT_PLAN.md](docs/PRODUCT_PLAN.md), [docs/DESIGN.md](docs/DESIGN.md)

Current scope: **웃긴자료 (pds) board only.** The app is the web app (`web/`) shown by its Android shell (`shell/`), and it serves one community, 웃대 (humoruniv), by decision of the user (2026-11-28). Until that day the app was a Flutter app: its last version is the tag `v3.14.3`, and nothing of it is in the repository any more. Do not add another community, and do not bring Flutter back, unless the user asks for it.

## Key Files

- `web/src/service/service_locator.ts` — where the dependencies are assembled (`communityRepos()`, `feedUseCase()`, …), and each site's headers, charset and cookie jar
- `web/src/model/community.ts` — the registry: `registeredCommunityIds`, `communities`
- `web/src/provider/state_notifier.tsx` — `StateNotifier` and `useNotifierState`, the base of every provider
- `web/src/utils/router.ts`, `web/src/app.tsx` — the paths, the navigation, and the page shown for a path
- `web/src/index.css` — the tokens of the theme, and the only place with a raw colour value
- `web/wrangler.jsonc` — how the web app is deployed (`web/README.md`, 배포)
- `web/test/helpers/fixtures.ts` — reads the page samples in `web/test/fixtures/`
- `shell/` — the gyo WebView shell; its `lib/` is a symlink to `../web`; `shell/gyo.config.json` holds its profiles, package name, version and icon. See `shell/README.md`
- `.github/workflows/` — `deploy-web.yml` (the web app to Cloudflare), `build-shell.yml` (the signed APK; a Release on a `v*` tag, with the notes of that tag's section of `RELEASE_NOTES.md`)

## Layers

- `service/` → `repository/` → `use_case/` → `provider/`, with `model/`, `utils/`, `pages/` and `widgets/`, all under `web/src/`. A widget's file is its description.
- Community pages are fetched through the native relay (`@gyo-community/http`), never by the WebView: CORS, the WebView's own user agent and its Referer get in the way.
- The feed, the settings switches and the tabs take every registered community, so one joins in three places that the compiler keeps in step: `registeredCommunityIds` and `communities` in `web/src/model/community.ts`, and its repository in `communityRepos()` of `web/src/service/service_locator.ts`. Write nothing per community anywhere else, and add none unless the user asks.
- A provider is a notifier class on `StateNotifier`, tested without React, and a hook next to it that binds the notifier to a screen. Only a `pages/*_view.tsx` reads providers; a widget receives data and `on*` callbacks.
- A parser lives in its community's `*_impl.ts`, written against the page sample in `web/test/fixtures/` that its tests read.

## Design System

shadcn/ui for React with Tailwind (`web/src/components/ui/`, added with the shadcn CLI) and `lucide-react` icons. [docs/DESIGN.md](docs/DESIGN.md) is the guide:

- Dark only, orange primary, semantic tokens only (`primary`, `foreground`, `mutedForeground`, `muted`, `border`, `destructive`) — no raw colour values outside `web/src/index.css`.
- 8pt grid (multiples of 4), screen padding 16, touch targets 44px, thumbnails 48/72/120.
- Color is never the only signal of a state; every interactive element has an accessible name.

## Mandatory Checks Before Committing

The pre-commit and the pre-push hooks (husky) run:

```bash
npm run check --prefix web   # lint, format check, typecheck, test, build
```

All must pass, and every test passes: none is skipped (`it.skip`, `describe.skip`, `it.todo` and `test.only` are not used). Or run `make check`. Commit messages follow Conventional Commits; the `commit-msg` hook enforces them.

## Commands

| Command                    | Description                                                                        |
|----------------------------|------------------------------------------------------------------------------------|
| `make check`               | lint + format check + typecheck + test + build of the web app (run before a commit) |
| `make fix`                 | format + auto-fix lint                                                             |
| `make clean`               | remove what a check leaves behind                                                  |
| `npm run dev --prefix web` | the dev server, on port 3000                                                       |
| `cd shell && … gyo run`    | the shell on a device: `shell/README.md`                                           |
| deploy, release            | `web/README.md` (배포), `README.md` (배포)                                         |

## Feature Consensus Protocol

Before implementing any screen or significant feature, load and follow the `feature-consensus` skill:

```
skill({ name: "feature-consensus" })
```

**When to use**: New screens, significant new features, refactoring that changes behavior.
**When to skip**: Bug fixes, test additions, minor copy changes, refactoring without UX/UI changes.

## Prohibited Actions

- "what" comments that restate what the code already expresses (allowed: concise "why" comments for non-obvious behavior, design intent, or regression rationale; public APIs keep a `/** */` doc comment)
- Committing code with failing tests, or with lint or type errors
- Skipping `make check` before committing
- Skipping tests: every test must pass
- Changing or adding a parser without the page sample in `web/test/fixtures/` and the tests that read it
- Provider calling Repository/Service directly (skip UseCase)
- Depending on an impl class where the abstract interface exists (`*_repo.ts`)
- Provider imports or provider hooks inside `web/src/widgets/` or in a page's private components (provider access is confined to `pages/*_view.tsx`)
- Additional page-level components, besides the page itself, in a `*_view.tsx` file (extract to `web/src/widgets/`)
- Non-`on*` callback names on widget props
- Raw colour values outside `web/src/index.css`
- Writing anything per community outside the three registry places
- Pushing a `v*` tag: it publishes the Release that every user of the app is offered. The user decides a release.
- Putting a secret or a private address in the repository: the release keys and the Cloudflare token are GitHub secrets, and this machine's Tailscale address stays out

## Commit Convention

Use Conventional Commits:

```
feat: add a notice for a post whose body failed
fix(parser): decode a date without a leading zero
refactor: extract the common selector helper
test: add page samples for the comment list
docs: update the architecture guide
ci: deploy the web app on a change
chore: update dependencies
```

## When Adding a New Feature

1. **Feature Consensus** — run `skill({ name: "feature-consensus" })` for screens/significant features
2. **model/** — the types in `web/src/model/`, and a failure if one is needed
3. **parser** — in the community's `*_impl.ts` (`web/src/repository/community/<id>/`), with the page sample in `web/test/fixtures/`
4. **repository/** — `web/src/repository/<feature>/<feature>_repo.ts` + `<feature>_impl.ts`
5. **use_case/** — `*_use_case.ts` (`XxxUseCase` class, private deps, a `Result` back)
6. **service/service_locator.ts** — assemble it (interface ← impl)
7. **provider/** — a notifier class on `StateNotifier`, and the hook next to it
8. **pages/** — `*_view.tsx`, the only place that reads providers
9. **widgets/** — reusable UI, if needed: data and `on*` callbacks
10. **Tests** — mirror `web/src/` under `web/test/`; run `make check`
11. **Final check** — `make check` passes, then commit
