# Testing Policy

Write tests for all new logic. Tests are Vitest and live under `web/test/`. See [AGENTS.md](../AGENTS.md) for workflow rules.

## Core Rule

Every implementation step is followed by the tests of what it touched: `npx vitest run <file>` from `web/` for one file, `npm run test --prefix web` for all of them. Write a test, see it fail, implement, see it pass, refactor. For a type or a constant, the test written beside the code is enough.

`make check` runs lint, format check, typecheck, tests and the build. Both hooks run it, the pre-commit and the pre-push hook, so no commit and no push goes through with a failing test.

### No-Skip Rule (enforced)

**Every test passes, and none is skipped.** `it.skip`, `describe.skip`, `it.todo` and `test.only` are used nowhere under `web/test/`. The end of `npm run test --prefix web` says that every test passed.

If a test is broken or flaky, **fix it** — do not skip it. A skipped test is a red flag equivalent to a failing test during code review.

There is no gated category and no smoke folder. No test reaches the network: what a page fetch answers is a page sample or a fake. The native relay is the one part no test stands in for; it is checked by hand on a device with `/relay-check` (see Real-Network Checks).

## TDD Cycle (recommended for logic)

1. **RED** — Write a failing test. Run it. Confirm it fails.
2. **GREEN** — Write the minimum implementation to pass. Run it. Confirm it passes.
3. **REFACTOR** — Clean up. Run tests again. All still pass.

Parser functions, notifiers, and business rules benefit most from strict per-case RED→GREEN. Types, constants and interfaces do not require RED verification.

## Testing Priority

| Priority | Layer | Reason |
|----------|-------|--------|
| 1 | **UseCase** | Business logic: fake repositories in, a `Result` out |
| 2 | **Repository** | The community's pages read from the page samples; stored data read and written |
| 3 | **Service** | Parsing helpers and classifiers: pure functions, many edge cases |
| 4 | **Provider** | The state machine of a screen, driven without React |
| 5 | **Model** | Keys, the JSON readers and writers |
| 6 | **Widget / Screen** | What is rendered, what a tap does |

## Test Directory Structure

Tests mirror `web/src/` under `web/test/`:

```
web/test/
├── fixtures/              page samples, read with readFixture
├── helpers/               fixtures.ts
├── setup.ts               what Vitest runs before every test file
├── integration/           several real layers together
├── model/                 model tests
├── provider/              *_provider.test.ts, *_actions.test.ts
├── repository/            <feature>/<feature>_impl.test.ts, community/humoruniv/humoruniv_impl.test.ts
├── service/               html_client.test.ts, content_scanner.test.ts, service_locator.test.ts, …
├── use_case/              *_use_case.test.ts
├── utils/                 helper tests, hooks included (router.test.tsx)
└── widgets/               widget tests, and the tests of the pages and of app.tsx (home_view.test.tsx, app.test.tsx)
```

- `src/pages/` has no folder of its own: a page's test is in `test/widgets/`, beside the tests of the widgets it is made of. `src/components/` and `src/lib/` have no tests.
- Vitest finds `test/**/*.test.ts` and `test/**/*.test.tsx` (`vite.config.ts`), and loads `test/setup.ts` in every test file; it unmounts what a test rendered after each test (`cleanup()`).
- A test file runs in Node. A file that parses markup, touches the browser's storage or renders starts with `// @vitest-environment jsdom`.

## Test Levels

### 1. Unit Tests (`test/model/`, `test/service/`, `test/repository/`, `test/use_case/`, `test/utils/`)

Isolated tests with every dependency a plain object of `vi.fn()`s.

| Target | What to test | Double |
|--------|-------------|--------|
| Model | Keys, `fromJson` / `toJson` | None |
| Parser (a community's `*_impl.ts`) | Page sample → model | A client with only `get` |
| Service (`html_client.ts`, `content_scanner.ts`, …) | Function → value; a retry schedule with `vi.useFakeTimers()` | A fake relay: `{ request: vi.fn() }` |
| Repository impl | Stored data read and written | A fake `LocalStorageService` |
| UseCase | Business logic, the `Result` | An object of `vi.fn()`s that `satisfies XxxRepo` |

Parser test pattern:

```ts
// @vitest-environment jsdom
const repo = new HumorunivImpl(fixtureClient({ 'read.html': read('pds_1415455.html') }));

const detail = await repo.fetchDetail('1415455');

expect(detail.title).toBe('26일 어제, 태풍때문에 난리난 오사카');
```

Use case test pattern:

```ts
function repo(communityId: CommunityId) {
  return {
    communityId,
    fetchLatest: vi.fn<(options?: { pageToken?: string | null }) => Promise<CommunityListResult>>(),
    fetchDetail: vi.fn<(id: string) => Promise<LoadedPostDetail>>(),
  } satisfies CommunityRepo;
}

humoruniv.fetchLatest.mockRejectedValue(new ServerFailure('humoruniv down'));
dogdrip.fetchLatest.mockResolvedValue(list([item('dogdrip', '1')]));

const result = await useCase.getMergedFeed();

expect(result.ok && result.value.failedSources.has('humoruniv')).toBe(true);
```

### 2. Provider Tests (`test/provider/`)

Drive the notifier class as a page does, with no React: call its methods, read `getState()`, and subscribe a listener to see that it is told. The use case is an object of `vi.fn()`s. The functions of an actions file are called after their modules were replaced (see Widget Tests).

```ts
const getMergedFeed = vi.fn().mockResolvedValue({ ok: true, value: page });
const notifier = new MergedFeedNotifier({ getMergedFeed } as unknown as FeedUseCase);

await notifier.fetch();

expect(notifier.getState().items.map((entry) => entry.id)).toEqual(['1']);
```

### 3. Widget Tests (`test/widgets/`)

Render with Testing Library (`@testing-library/react`) in jsdom. Find by role and name, fire an event, and assert on the DOM and on the callbacks. A widget is given its data and its callbacks as props.

```tsx
// @vitest-environment jsdom
const onCopyLink = vi.fn();

render(<FeedCard post={post()} onCopyLink={onCopyLink} />);
fireEvent.click(screen.getByRole('button', { name: '링크 복사' }));

expect(onCopyLink).toHaveBeenCalledTimes(1);
```

- A widget is rendered bare: nothing provides a theme, as there is none to provide. Styling is Tailwind classes on the elements, which jsdom does not compute, so a test asserts structure, text, roles, names and attributes — never colour or layout.
- What jsdom does not have — `Image`, `ResizeObserver`, `IntersectionObserver`, sizes, media elements — is replaced in the test with `vi.stubGlobal` or `vi.spyOn`, and put back in `afterEach` with `vi.unstubAllGlobals()` or `vi.restoreAllMocks()`.
- A hook is tested through a small component that uses it, rendered the same way; `renderHook` is not used.
- A page (`pages/*_view.tsx`) and `app.tsx` read providers, so their tests replace the modules they read: `vi.resetModules()` first, then `vi.doMock(…)` for each module, then `await import(…)` of the page.

```ts
vi.resetModules();
vi.doMock('../../src/service/service_locator', () => ({ feedUseCase: () => fake }));
vi.doMock('../../src/provider/bookmark_provider', () => ({
  bookmarkNotifier: () => ({ isBookmarked: () => false, toggle: async () => false }),
  useBookmarks: () => [],
}));
const { HomeView } = await import('../../src/pages/home_view');
```

A state the test changes while the page is shown is a small class on `StateNotifier` that the test owns; the replaced hook reads it with `useNotifierState`.

### 4. Integration Tests (`test/integration/`)

Several real layers wired the way the app wires them, with only the outside replaced. `bookmark_integration.test.ts` runs `BookmarkNotifier → BookmarkUseCase → BookmarkImpl → BrowserLocalStorageService` over jsdom's `window.localStorage`, without the locator: `new BookmarkNotifier(new BookmarkUseCase(repository))`.

### 5. End-to-End Tests — none

No test drives the app on a device or in a browser. The shell's Gradle project has one Kotlin test (`gyo-bridge`); `make check` does not run it.

### 6. Real-Network Checks — by hand

No test fetches a live page. A change to what reaches the relay — `html_client.ts`, the request settings of `service_locator.ts`, a gyo plugin — is checked on a device with `/relay-check` ([DEVELOPMENT.md](DEVELOPMENT.md)). A change to a parser is verified against a fresh page by saving that page as a page sample and running the parser's tests.

## Fixture Management

- Page samples are in `web/test/fixtures/`, read with `readFixture(name)` from `web/test/helpers/fixtures.ts`, and committed.
- A sample is the page as the site sent it — markup, encoding, line endings, odd characters. It is never reformatted, re-indented, trimmed or re-encoded; `web/.prettierignore` keeps Prettier off the folder.
- Naming: `<board>_<post number>.html` (`pds_1415455.html`). The board is the site's `table` name, and the number is the id the site's link carries.
- A parser is written against a sample, and its tests read it by name. A test for a new shape of page gets a new sample; an existing one is not edited.
- The samples are post pages of 웃대. The list parser has no sample: its tests use a few rows of markup written in the test file.
- The samples were captured while the app was Flutter (until 2026-11-28; its last version is the tag `v3.14.3`). A comment in a test that says "as Dart did" explains an assertion kept from that app's tests.
- A test that needs a response body the way the relay gives it encodes it itself: `Buffer.from(text, 'utf8').toString('base64')`.

## Mock Conventions

There is no mocking library: Vitest's `vi`, and plain objects.

```ts
// A dependency is an object of vi.fn()s, typed by what they stand for
const relay = () => ({ request: vi.fn<(request: HttpRequest) => Promise<HttpResponse>>() });
getAll = vi.fn<BookmarkUseCase['getAll']>();

// …answered per call, or per test
humoruniv.fetchLatest.mockResolvedValue(list([item('humoruniv', '1')]));
useCase = { getMergedFeed: vi.fn(), getPostDetail: vi.fn(), ...overrides } as unknown as FeedUseCase;
```

- A small interface is met with `satisfies`; a partial fake of a big one is cast (`as unknown as FeedUseCase`).
- A module is replaced with `vi.doMock`, never with the hoisted `vi.mock`, which the tests do not use: `vi.resetModules()` in the test (or its `beforeEach`), `vi.doMock(path, factory)` for each module, then the dynamic `await import(…)` of the code under test. The reset makes the module run again, so the singletons the providers and the locator keep start empty for every test.
- The modules replaced in the tests are `service_locator` (a fake use case), the providers a test steers (a hook that answers a fixed value), `sonner`, `utils/clipboard` and, in a few tests, `model/community` (to serve a second community) or a widget that plays a video. The parsers and the rest of `model/` and `utils/` run for real.
- `vi.clearAllMocks()` forgets the calls between tests; `vi.restoreAllMocks()` and `vi.unstubAllGlobals()` in `afterEach` undo spies and stubs.
- Time is `vi.useFakeTimers()` with `vi.advanceTimersByTimeAsync(ms)`, and `vi.useRealTimers()` after.

## Parser Resilience Testing

A parser is tested against what its page can be:

| Case | Expected behavior |
|------|-------------------|
| A page sample | The values the page has: title, author, date, counts, comments, media |
| Markup of one shape is missing | The next selector answers (`textOfAny`), or the default: `''`, `0`, the epoch |
| A row without a number | `parseListRow` answers `null`, and the row is left out |
| A page without a body container | No blocks; the use case turns that into a `ParseFailure` (`looksEmpty`) |
| An empty page | An empty list |
| A malformed stored entry | `fromJson` throws, and the repository skips the entry |

Parsers never throw for missing markup.

## Test Anti-Patterns

- **Skipping tests** (`it.skip`, `describe.skip`, `it.todo`), or a `test.only` left in — banned by the No-Skip Rule. Fix or delete; never gate out.
- **Reaching the network**: a test depends on a live site.
- **Mock echo**: Asserting the exact value set up in `mockResolvedValue`. Tests the mock.
- **No assertions**: A test without `expect`.
- **Tautology**: Asserting always-true conditions.
- **Code duplication**: Copying implementation logic into test code.
- **Testing private members**: Only test public API behavior.
- **A stub left behind**: A `vi.stubGlobal` or `vi.spyOn` with no `afterEach` to undo it.

## Commands

| Command | Purpose |
|---------|---------|
| `make check` | Lint, format check, typecheck, all tests and the build — what the hooks run |
| `npm run test --prefix web` | All tests once (`vitest run`) |
| `npx vitest run test/widgets/feed_card.test.tsx` (from `web/`) | One test file |
| `npx vitest run test/provider` (from `web/`) | One folder |
| `npm run lint --prefix web`, `npm run format:check --prefix web`, `npm run typecheck --prefix web`, `npm run build --prefix web` | The checks one by one |
| `make fix` | Format, and apply ESLint's fixes |

There is no coverage report: no coverage provider is installed and no target produces one.
