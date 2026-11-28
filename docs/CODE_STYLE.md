# Code Style

See [ARCHITECTURE.md](ARCHITECTURE.md) for layer boundaries and [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md) for naming. The look of the app — shadcn/ui, semantic tokens, the 8pt grid — is [DESIGN.md](DESIGN.md).

## TypeScript Style

The tools enforce the style, as configured in `web/` and run by `npm run check --prefix web`:

- **The compiler** (`tsc -b`, `tsconfig.app.json`): `strict`, `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch`, `verbatimModuleSyntax`, `erasableSyntaxOnly`.
  - `verbatimModuleSyntax`: what is only a type is imported as one — `import type { … }`, or `type X` inside the braces.
  - `erasableSyntaxOnly`: no `enum`, no `namespace`, no constructor parameter property. A set of names is a union of string literals (`type FailureKind = 'ServerFailure' | 'NetworkFailure' | 'ParseFailure'`); a class declares its fields and assigns them in its constructor.
- **ESLint** (`eslint.config.js`): the recommended rules of `@eslint/js`, of `typescript-eslint` (the ones that need no type information) and of `eslint-plugin-react-hooks`. Errors include `@typescript-eslint/no-explicit-any`, unused variables, `@typescript-eslint/ban-ts-comment` (`@ts-ignore` and `@ts-nocheck`), and the rules of hooks — `rules-of-hooks` and the React Compiler's `purity`, `refs`, `immutability`, `set-state-in-effect`, `static-components`. `react-hooks/exhaustive-deps` and `react-refresh/only-export-components` are warnings; the latter is off in `src/components/ui/`, where a variant is exported next to its component.
- **Prettier** (`.prettierrc.json`): semicolons, single quotes, trailing commas, a width of 100, 2 spaces, LF — over everything in `web/` but `dist`, `coverage`, `package-lock.json` and `test/fixtures`.

Nothing else is configured: there is no import order, no naming rule and no rule about the layout of a file.

There is no `eslint-disable`, `@ts-ignore` or `@ts-expect-error` in the code; do not add one. `make fix` runs Prettier `--write` and ESLint `--fix`; `make check` runs everything above, the tests and the build.

## Model Rules

1. A model is an `interface` or a `type` in `web/src/model/`. No classes, no methods, no equality code. A model file may also hold the functions that belong to its type: `feedItemKey(item)`, `bookmarkToJson(bookmark)`, `resolveAbsolute(community, url)`.
2. Two values are the same thing by key, not by comparison. A post is `${community}:${id}` — `FeedItemKey`, made by `feedItemKey(item)` or `bookmarkKey(bookmark)`; a video is `${postKey}#${index}` — `VideoId`. Look things up by key (a `Map<FeedItemKey, …>`, a React `key`) and compare keys, never objects.
3. Values are replaced, never mutated: `{ ...comment, replies }`, `new Map(state).set(key, entry)`, `[...items, ...fresh]`.
4. A variant is told by one field — `ok` on a `Result`, `status` on a `PostDetail` (`'loaded'` or `'error'`), `type` on a `ContentBlock`. Narrow before reading: `if (result.ok)`, `detail?.status === 'loaded'`.
5. What is stored keeps its stored shape in the model file, with its reader and its writer: `BookmarkJson` with `bookmarkFromJson` and `bookmarkToJson` in `bookmark.ts`, and `BlockedImageJson` likewise in `blocked_image.ts`. The shape is the one the Flutter app wrote, so that what it saved can be moved over unchanged. A reader takes `unknown`, checks every field and throws on a malformed entry; the repository catches that and skips the entry.

## Error Handling

A use case answers a failure; it does not throw to a provider.

```ts
// Model: what a use case answers
export type Result<T> = { ok: true; value: T } | { ok: false; failure: Failure };

// Repository: the raw value; a failure propagates
async fetchLatest(options?: { pageToken?: string | null }): Promise<CommunityListResult> {
  const html = await this.htmlClient.get(this.listPath(page)); // throws ServerFailure or NetworkFailure
  …
}

// UseCase: guard() makes the Result
getAll(): Promise<Result<Bookmark[]>> {
  return this.guard(async () => this.repo.getAll());
}

// Provider: branch on `ok`
const result = await this.useCase.getAll();
if (result.ok) this.state = result.value;
```

- `throw` belongs to the layers below a use case: `HtmlClient.get()` throws a `Failure`, and a model's `fromJson` throws a `TypeError`. `guard()` turns what is thrown into a failure; what it catches that is not a `Failure` becomes a `ServerFailure` carrying the error's text.
- A failure says what is known: `new ServerFailure('HTTP 403', { statusCode: 403, headers, bodySnippet, requestPath })`.
- A `catch` keeps what it caught and loses nothing else: skip one bad stored entry and answer the rest (`BookmarkImpl.getAll()`), answer `null` for an image whose bytes cannot be fetched (`ImageHashService.hashFor`), try the next way (`copyText`).
- What the user has to know is said: a toast for an action (`media_actions.ts`, `post_actions.ts`), an error card for a post whose body did not come (`FeedErrorCard`), `role="alert"` on the message.

## Service and Parser Rules

- A service is stateless functions, or a small class behind an interface. It knows `model/` and the gyo plugins only.
- `parseHtml(html)` uses `DOMParser`: scripts never run and nothing is loaded.
- A parser does not throw for what is missing. `textOf(null)` is `''`, `extractNumber` answers `0`, `parseListRow` answers `null` for a row without a number, `extractDate` answers the epoch, and an empty page gives an empty list.
- When a site's markup comes in more than one shape, the selectors are offered in order: `textOfAny(root, selectors)`, `statOfAny`, `queryFirst`.
- A parser leaves an absent value out of the object rather than setting it to `undefined`: `...(author === '' ? {} : { author })`.
- A rule that is not obvious from the markup says why in a comment, with the page sample or the date it was verified against (`// … (fixture 1429732)`, `// verified 2026-10: …`).
- A parser changes together with the page sample in `web/test/fixtures/` and the tests that read it.

## Provider Rules

- The state machine of a screen is a class on `StateNotifier`, separate from React. A hook binds it to the screen; a component only displays it.
- Replace the state (`this.state = { ...this.state, error: null }`); never mutate it.
- A request that would be repeated is stopped in the notifier: `fetch()` joins a first page that is already loading, and `fetchDetail(key)` asks once for a post.
- A promise that is started and not awaited is marked `void`: `void notifier.fetch()`.

## Widget Rules

- A widget is a function component with its props destructured, and an `interface XxxProps` above it that is not exported.
- Its props are data and `on*` callbacks, nothing else. When an optional callback is not given, the part of the UI that needs it is not rendered.
- What belongs to the widget's own behaviour is its local state (`useState`, `useRef`); what the app knows is passed in.
- Every interactive element has an accessible name — `aria-label` when it shows only an icon — and a state is never told by colour alone (`aria-pressed`, `aria-selected`, `role`).
- The text a user reads is Korean (`'링크 복사'`, `'게시글을 불러오는 중'`).

## Comments Policy

- Every exported class, function and constant that other files use has a `/** … */` comment: one or two sentences that say what it does and, when it matters, what it answers — `/** The one feed use case of the app, made the first time a provider asks for it. */`.
- A field of a props interface has a doc comment when its meaning is not its name.
- A `//` comment says why: what is not obvious from the code, a design decision, the regression a line prevents.
- Never a "what" comment that restates the code.
- A behaviour kept from the Flutter app says so where it is kept (`// Dart's int is signed: …`, `as the Flutter app names them`). The app was Flutter until 2026-11-28 (its last version is the tag `v3.14.3`); the shape in which it stored things and the fingerprints it computed are kept, so that its data can be moved over and the same picture keeps its fingerprint.

## Never Done

- `any`; an unused variable or parameter.
- `enum`, `namespace`, a constructor parameter property.
- `eslint-disable`, `@ts-ignore`, `@ts-expect-error`; an empty `catch` block.
- A provider that calls a repository or a service other than the use-case factories of `service_locator.ts`.
- A dependency on an `*_impl` class in `web/src/` outside `service_locator.ts`.
- A provider import in a widget (`InlineVideoPlayer` is the one the code has; see [ARCHITECTURE.md](ARCHITECTURE.md)); a second component in a `*_view.tsx`.
- A widget callback whose name does not start with `on`.
- A use case that throws to its caller, or a `catch` that hides an error.
- A parser changed without its page sample and its tests.
- A skipped test — `it.skip`, `describe.skip`, `it.todo` — or a `test.only` left in.
