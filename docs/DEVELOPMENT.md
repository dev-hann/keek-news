# Development

Environment setup and commands. The app is the web app in `web/`; `shell/` is the Android project that shows it.

## Prerequisites

- Node 24 — what CI runs the checks on, and what the shell is built with. This machine manages Node versions with mise; `shell/README.md` writes its command as `mise exec node@24 -- …`.
- For the shell: JDK 17 and Android SDK platform 36. `gyo doctor` says whether both are there.
- An emulator, or a phone with USB debugging, to run the shell on it.
- The gyo CLI (`@gyo-framework/cli` 0.3.0). The command it is run with on this machine is in `shell/README.md`.

## Setup

```bash
npm install               # at the root: installs husky, which activates the git hooks
npm install --prefix web  # the app's dependencies, the gyo plugins among them
```

The root `package.json` is there for the hooks only.

## Run

The web app's dev server:

```bash
npm run dev --prefix web   # port 3000; a phone on the same network can reach it
```

The shell: with the default `development` profile, `gyo run` starts this server itself, builds a debug APK, installs it on the device and opens it. The command, the profiles (`development`, `dev-server`, `standalone`) and how to run the server and the shell separately are in [`shell/README.md`](../shell/README.md).

In a plain browser the dev server shows the screens, but nothing comes from a community: pages are fetched by the native relay, which exists only in the shell's WebView.

## Test

```bash
npm run test --prefix web   # all tests, once
make check                  # lint + format check + typecheck + tests + build
```

One test file, and the conventions the tests follow: [TESTING_POLICY.md](TESTING_POLICY.md).

## Analyze

```bash
npm run lint --prefix web          # eslint .
npm run typecheck --prefix web     # tsc -b
npm run format:check --prefix web  # prettier --check .
```

Must pass before committing. Both hooks — `.husky/pre-commit` and `.husky/pre-push` — run `make check`, which is these three, the tests and the build, so neither a commit nor a push goes through with a lint error, a type error, a failing test or a failing build. `make fix` formats and applies ESLint's fixes; `make clean` removes what a check leaves behind.

Commit messages follow Conventional Commits. `.husky/commit-msg` accepts `feat|fix|refactor|test|docs|chore|style|ci|build|perf(scope): description`.

## Build

```bash
npm run build --prefix web     # tsc -b && vite build → web/dist
npm run preview --prefix web   # serves web/dist locally
```

The Android shell is built by `gyo run` (a debug APK, for a device) and by GitHub Actions (the signed APK): `shell/README.md`, and Deploy and release below.

## Project Structure

| Path | What it is |
|------|------------|
| `web/` | The app: React 19, Vite, TypeScript, Tailwind 4, shadcn/ui, lucide-react; Vitest for the tests. Source in `web/src/`, tests in `web/test/`, page samples in `web/test/fixtures/`. |
| `web/dev/relay-check-server.ts` | The harness of the relay check, served by the dev server only. |
| `web/wrangler.jsonc` | How the web app is deployed: a Cloudflare Worker that holds `web/dist`. |
| `shell/` | The Android shell, a gyo project. `shell/gyo.config.json` has its profiles, package name, version and icon; `shell/lib` is a symlink to `../web`. |
| `docs/` | This documentation; [`AGENTS.md`](../AGENTS.md) is the index. |
| `.github/workflows/` | `deploy-web.yml` and `build-shell.yml`: the deploy of the web app and the build of the shell. |
| `Makefile` | `check`, `fix`, `clean`. |
| `.husky/` | The git hooks: `pre-commit`, `pre-push`, `commit-msg`. |
| `package.json` | Husky only. |

The layers of `web/src/` are described in [ARCHITECTURE.md](ARCHITECTURE.md).

## Deploy and Release

- **The web app is a static site.** `npm run build --prefix web` writes `web/dist`; a Cloudflare Worker holds those files and runs no code (`web/wrangler.jsonc`), answering with `index.html` where there is no file. The shell's `standalone` profile opens the deployed address, so a change to `web/` reaches every installed app without a new APK. Deploying by hand: [`web/README.md`](../web/README.md) (배포).
- **GitHub Actions does both on a push to `master`.** A change under `web/` is checked, built and deployed (`deploy-web.yml`); a change under `shell/` or to the gyo plugins builds the signed APK (`build-shell.yml`).
- **A release is a pushed `v<version>` tag.** The tag must equal `version` in `shell/gyo.config.json`, and the notes of the release are the tag's section of `RELEASE_NOTES.md`; a tag without one is not released. The Release goes to every user of the app: pushing the tag is the user's decision, not a step of development. Details: [`README.md`](../README.md) (배포) and `shell/README.md` (릴리스).

## Checking on a Device

No test reaches the native relay. After a change to `web/src/service/html_client.ts`, to the request settings of `service_locator.ts`, or to a gyo plugin, open `/relay-check` in the shell that runs against the dev server. Nothing in the app leads there: the page is opened by its address.

The page runs its checks at once and shows PASS, FAIL or PENDING for each:

- redirects followed, cookies kept per jar and across a restart, a refusal reported with its status and headers, a network failure told apart from a server's, bodies of 1500 KB and 4000 KB;
- the first list page of seven communities, read as the site answers it.

The harness behind the first group is `web/dev/relay-check-server.ts`, served under `/__relay-check` by `vite dev` only; in a build the page runs the list checks alone. From the dev server a run also writes `node_modules/.vite/relay-check-report.json`. "cookies survive a restart" passes only after the app was restarted and the page opened again. What each check does: `web/README.md` (릴레이 검사).

---

For architecture details, see [ARCHITECTURE.md](ARCHITECTURE.md).
For naming rules, see [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md).
For coding style, see [CODE_STYLE.md](CODE_STYLE.md).
For testing, see [TESTING_POLICY.md](TESTING_POLICY.md).
