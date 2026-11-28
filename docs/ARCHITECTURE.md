# Layer Architecture

The app is the web app in `web/` (React, TypeScript), shown by the Android shell in `shell/`. There is no backend: the shell's native relay fetches a community's pages on the device.

## 4-Layer Structure

```
Service → Repository → UseCase → Provider
```

| Layer | Role | State |
|------------|-----------------------------------|----------------|
| **Service** | Fetching pages through the native relay and decoding them, the newest release of the app on GitHub, parsing helpers, the page's storage, image fingerprints — and `service_locator.ts`, where the dependencies are assembled | Caches only |
| **Repository** | Reading one community's list and post pages; the stored bookmarks, blocked images and switched-on communities; saving and sharing media through the native plugin; the update of the app: what is installed, the download and the install | Caches only |
| **UseCase** | Business rules, the error boundary, asking every community that is on at once | None |
| **Provider** | The state of the screens: notifier classes on `StateNotifier`, the hooks that bind them, the actions a page hands to its widgets | **Sole holder** |

```
web/src/
├── service/        html_client.ts, html_service.ts, content_scanner.ts, storage, image hashes,
│                   and service_locator.ts
├── repository/     abstract (*_repo.ts) + impl (*_impl.ts), feature-grouped
├── use_case/       business operations (*_use_case.ts), BaseUseCase
├── provider/       notifiers (*_provider.ts), actions (*_actions.ts), hooks
├── model/          types and the functions on them (result.ts, failures.ts)
├── pages/          screens (*_view.tsx) — read providers
├── widgets/        reusable UI
├── components/ui/  shadcn/ui primitives
├── utils/          pure helpers, hooks, router.ts
└── app.tsx         the page shown for a path
```

---

## Layer Access Rules

Each layer uses only the layer below it. Pages and widgets use providers, never what providers use.

```ts
// ✅ Do
provider  → useCase.method()      // the use case comes from service_locator.ts
useCase   → repo.method()
repo      → service

// ❌ Do not
provider  → repo                        // skip UseCase
provider  → service                     // skip UseCase + Repo
useCase   → service                     // skip Repo
widget    → provider                    // a widget gets data and callbacks
```

The code steps over these rules in four places:

- `BlockImageUseCase` takes an `ImageHashService` next to its repository: `add(url)` computes the fingerprint of the image and writes both to the repository in one call.
- `InlineVideoPlayer` (`widgets/inline_video_player.tsx`) reads the playback provider itself, with `useActiveVideo()` and `feedVideoPlaybackNotifier()`: which video may play is one piece of state for every player of the app, and no page passes it down.
- `pages/relay_check_view.tsx` uses `HtmlClient` and `htmlClient()` of the service layer directly: the page tests the relay, which the layers in between hide.
- `service/service_locator.ts` imports every `*_impl.ts` and every use case. It is the one place that knows the implementations (see Dependency Wiring).

### UseCase Dependencies Must Be Private

```ts
// ✅ Do — use_case/bookmark_use_case.ts
export class BookmarkUseCase extends BaseUseCase {
  private readonly repo: BookmarkRepo;

  constructor(repo: BookmarkRepo) {
    super();
    this.repo = repo;
  }

  getAll(): Promise<Result<Bookmark[]>> {
    return this.guard(async () => this.repo.getAll());
  }
}

// ❌ Do not
export class BookmarkUseCase extends BaseUseCase {
  constructor(public readonly repo: BookmarkImpl) {
    super();
  }
}
// The impl class instead of the interface, and a field a provider can reach through.
```

---

## UseCase Rules

1. **One use case per domain concept**, named after the noun: `FeedUseCase`, `BookmarkUseCase`, `BlockImageUseCase`, `SaveMediaUseCase`, `ShareMediaUseCase`, `UpdateUseCase` (`Feed` ✅, `GetFeed` ❌).
2. **Several named methods, one per operation** — `getMergedFeed()`, `getPostDetail()` — and no `call()`. The code has one exception: the two media use cases have a single operation each, named `call(target)`, and extend nothing.
3. **A method that can fail answers a `Result`** (`model/result.ts`) — the error boundary lives here, not in the Repository.
4. **Repositories answer raw values and throw**; the use case catches with `guard()`.
5. **No state**: a use case holds its dependencies and nothing else.
6. **Dependencies are `private readonly` fields** typed by the repository interface and given in the constructor.
7. **Results only** — state belongs to the provider.

A method that cannot fail answers a plain value: `FeedUseCase.getEnabledCommunities()`, `canDisableCommunity()` and `toggleCommunity()` read and write the stored switches. `FeedUseCase.getPostDetail()` answers a `PostDetail` rather than a `Result`: an error is one of the things a post's card shows, so it travels inside the value.

```ts
// ✅ Do
export class BookmarkUseCase extends BaseUseCase {
  getAll(): Promise<Result<Bookmark[]>> {
    return this.guard(async () => this.repo.getAll());
  }

  remove(community: CommunityId, id: string): Promise<Result<void>> {
    return this.guard(async () => this.repo.remove(community, id));
  }
}
```

### Error Handling

`Result<T>` is `{ ok: true; value: T }` or `{ ok: false; failure: Failure }`. `BaseUseCase` (`use_case/base_use_case.ts`) has one method, `guard(action)`: it awaits `action()` and answers `{ ok: true, value }`, or `{ ok: false, failure }` for what `action` threw — a `Failure` as it is, anything else as `new ServerFailure(String(error))`.

| Situation | Answer |
|--------------------------|----------------------------|
| UseCase method that can fail | `Result<T>` |
| One community of several fails to answer | Its id goes into `failedSources` of the `MergedPage`; the posts of the others are returned. The answer is a failure only when every community that is on fails |
| The body of a post does not come | `PostDetail` with `status: 'error'` and the `Failure` — a value, not a rejection |
| Repository method over pages | Raw value. `HtmlClient.get()` throws `ServerFailure` or `NetworkFailure`, and the repository lets it propagate |
| Repository method over stored data | Raw value. An entry that cannot be read is skipped (`BookmarkImpl.getAll()`) |
| Repository method over the media plugin | `MediaSaveResult` (`model/media_save_failure.ts`): `{ ok: true }`, or a failure of the plugin's kinds — `network`, `permission`, `canceled`, `inProgress`, `unexpected` |
| `UpdateRepo.download()` | `DownloadOutcome` (`model/app_update.ts`): the path of the file, `cancelled`, or a `failure`. A download the page cancelled is neither a success nor a failure. The other methods of `UpdateRepo` throw |
| Failure types | `ServerFailure` (the server answered, but not with the page), `NetworkFailure` (no answer arrived), `ParseFailure` (the page came, but nothing in it could be read) — `model/failures.ts` |

`Failure` extends `Error`, and `instanceof` a subclass tells the kinds apart. `failure.http` carries what a page fetch could see about a refusal: `statusCode`, a few response `headers`, the start of the `bodySnippet`, and the `requestPath`.

---

## Provider Rules

State lives in a notifier class; React only displays it.

1. **A notifier extends `StateNotifier<State>`** (`provider/state_notifier.ts`). It holds one state, offers `getState()` and `subscribe()` for `useSyncExternalStore`, and replaces the state through a `protected` setter that tells every listener. The state is replaced, never mutated: `this.state = { ...this.state, isLoadingMore: true }`, or `this.state = new Map(this.state).set(key, entry)`.
2. **A provider file holds three things**: the `XxxNotifier` class, a function `xxxNotifier()` that makes the one instance of the app the first time a screen asks for it, and a hook `useXxx()` that returns `useNotifierState(xxxNotifier())`.
3. **A provider calls use cases only.** It gets them from the factories of `service/service_locator.ts` (`feedUseCase()`, `bookmarkUseCase()`), never from a repository or a service.
4. **A provider may use another provider**: `useMergedFeed()` reads `useSettings()`, and `post_actions.ts` calls `bookmarkNotifier()`.
5. **Branch on `result.ok`.** A failure becomes what the screen shows — an error state, or the list that was there — not an exception.
6. **A notifier is driven the way a page drives it**: its methods are `fetch()`, `fetchNextPage()`, `refresh()`, `toggle(id)`, `fetchDetail(key)`.

```ts
// ✅ Do — provider/bookmark_provider.ts
export class BookmarkNotifier extends StateNotifier<Bookmark[]> {
  private readonly useCase: BookmarkUseCase;

  constructor(useCase: BookmarkUseCase) {
    super([]);
    this.useCase = useCase;
  }

  async load(): Promise<void> {
    const result = await this.useCase.getAll();
    if (result.ok) this.state = result.value;
  }
}

let bookmarks: BookmarkNotifier | undefined;

/** The one bookmark notifier of the app, made the first time a screen asks for it. */
export function bookmarkNotifier(): BookmarkNotifier {
  bookmarks ??= new BookmarkNotifier(bookmarkUseCase());
  return bookmarks;
}

/** The posts the user saved, most recently saved first. */
export function useBookmarks(): Bookmark[] {
  return useNotifierState(bookmarkNotifier());
}

// ❌ Do not
this.state = result.value; // no check of `ok`
bookmarkNotifier().useCase.getAll(); // reaching through a notifier into its use case
new MediaSaveImpl(new Media()); // a provider making a repository
```

### The notifiers of the app

| Notifier | State | Hook |
|----------|-------|------|
| `MergedFeedNotifier` | What the feed shows, where it continues, what is loading, the error, the communities that failed | `useMergedFeed()` — loads on first use and whenever the switched-on communities change |
| `MergedDetailNotifier` | The body of each post shown, by `FeedItemKey`: loading or loaded | `useMergedDetail()` |
| `SettingsNotifier` | The communities the user has on | `useSettings()` |
| `BookmarkNotifier` | The saved posts | `useBookmarks()` |
| `BlockedImagesNotifier` | The blocked images, read again whenever the repository's `changes` stream fires | `useBlockedImages()` |
| `FeedVideoPlaybackNotifier` | The one video of the feed that may be playing | `useActiveVideo()` |
| `UpdateNotifier` | What the version row of Settings says: the status, the installed version, the release that can be installed, how far its download is. Looks on GitHub when Settings opens, and again on the way back from the system's installer | `useUpdate()` |

### Provider files without a notifier

- **`media_actions.ts` and `post_actions.ts`** hold functions that run what a widget's callback asks — copy a link, block an image, save or share media, save a post — through use cases and other providers' notifiers. They say with a toast (`sonner`) when something did or did not happen. A page imports them and hands them to its widgets.
- **`useMediaOverlays`** (`media_actions.ts`) and **`useCommentsSheet`** (`comments_sheet.ts`) are hooks that hold, with `useState`, which overlays a page has open: the image viewer, the media menu, a comment's video, the comments sheet. The feed and the bookmarks list each have their own.

---

## Widget Rules

Widgets are **dumb, reusable UI**. They never touch the state layers.

1. **A widget is a function component** in `web/src/widgets/`; its file is named after what it is.
2. **No provider import inside a widget** — nothing from `provider/`, `service/`, `repository/` or `use_case/`. The one widget that reads a provider is `InlineVideoPlayer` (see Layer Access Rules).
3. **Data is passed as props** — every value a widget needs is a prop given by the page.
4. **Actions are `on*` callbacks** — `onBack`, `onRetry`, `onToggleBookmark`, `onOpenImage(index)`. The page implements them. A callback that is not given removes the part that needs it: a `FeedCard` without `onToggleBookmark` has no save button.
5. **Provider access is confined to pages (`pages/*_view.tsx`)** — the page reads the hooks and the notifiers, transforms state, and passes data and callbacks down.
6. **Allowed inside widgets**: local UI state (`useState`, `useRef`, `useEffect`), the hooks of `utils/` (`useImageLoader`, `useLongPress`, `useHistoryBack`), other widgets, the primitives of `components/ui/`, and private helper components in the same file.
7. **A widget does not navigate** — `navigate()` is called by `app.tsx` only. A widget that is a dialog or a sheet handles the system Back for its own overlay with `useHistoryBack` (`utils/use_history_back.ts`).

```tsx
// ✅ Do — dumb widget (widgets/app_bar.tsx)
interface AppBarProps {
  title: string;
  /** Where the back arrow goes. Without it there is no back arrow. */
  onBack?: () => void;
  actions?: ReactNode;
}

/** The bar at the top of a screen: a title, and at most a back arrow and a few actions. */
export function AppBar({ title, onBack, actions }: AppBarProps) {
  return (
    <header className="…">
      {onBack && <Button aria-label="뒤로" onClick={onBack}>…</Button>}
      <h1 className="…">{title}</h1>
      {actions}
    </header>
  );
}

// The page injects everything
<AppBar title="저장함" onBack={onBack} />

// ❌ Do not
export function AppBar({ title }: AppBarProps) {
  const settings = settingsNotifier(); // a provider inside a widget
  return <h1>{settings.size}</h1>;
}

<AppBar handleBack={() => …} /> // a callback without the on prefix
```

---

## Page Structure Rules

1. **One component per page file** — a `*_view.tsx` exports the page and defines nothing else that renders: `HomeView`, `SettingsView`, `BookmarksView`, `BlockedImagesView`, `RelayCheckView`.
2. **A page's props are navigation only** — `onBack`, `onOpenSettings`, `onOpenBookmarks`, `onOpenBlockedImages` — which `app.tsx` gives it.
3. **Helper functions are allowed** inside a page file; helper components go to `widgets/`.
4. **Routing is `utils/router.ts` and `app.tsx`.** `navigate(to)` pushes the path and remembers where the page was scrolled, `usePathname()` gives the path shown, and `app.tsx` picks the page for it; a path the app does not have shows the feed. The paths are `/`, `/settings`, `/bookmarks`, `/blocked-images` and `/relay-check`.

```tsx
// ✅ Do — pages/bookmarks_view.tsx holds BookmarksView and nothing else
export function BookmarksView({ onBack }: BookmarksViewProps) {
  const bookmarks = useBookmarks();
  const details = useMergedDetail();
  …
  return (
    <div className="…">
      <AppBar title="저장함" onBack={onBack} />
      …
    </div>
  );
}

// ❌ Do not — a component beside the page in the same file
function BookmarkRow({ bookmark }: BookmarkRowProps) {
  …
} // extract → widgets/
```

---

## Repository Rules

1. **Abstract interface (`XxxRepo`) and implementation (`XxxImpl`)** are separate files in `repository/<feature>/`.
2. **The implementation uses `implements`.** A community's extends `HtmlCommunityRepo`, which implements `CommunityRepo`.
3. **Services are given in the constructor**, by the narrowest type that suffices: `LocalStorageService`, `Pick<HtmlClient, 'get'>`, or the `saveToGallery` and `share` methods of `Media`. A test passes an object with just that.
4. **Only `service_locator.ts` names an `*_impl.ts`**; everything else names the interface.
5. **Raw values out, and a failure propagates.** A repository over pages has no `try`/`catch`. Over stored data, an entry that the model's reader rejects is skipped and the rest is returned.
6. **Communities group under `repository/community/`**: the contract (`community_repo.ts`), the base class (`html_community_repo.ts`) and one folder per community with its `<community>_impl.ts`. There is no `<community>_repo.ts`: the contract is the same for every community.

| Repository | Reads or writes |
|------------|-----------------|
| `CommunityRepo` — `HumorunivImpl` | The list and the post pages of 웃대 |
| `FeedRepo` — `FeedImpl` | Which communities are switched on (`enabled_communities` in the page's storage) |
| `BookmarkRepo` — `BookmarkImpl` | The saved posts (`bookmarks`) |
| `BlockedImageRepo` — `BlockedImageImpl` | The blocked images (`blocked_images`); `changes` fires after every write |
| `MediaSaveRepo` — `MediaSaveImpl` | The native media plugin: save to the gallery, share; one download per file at a time |
| `UpdateRepo` — `UpdateImpl` | The installed version (`PackageInfo`), a download into the cache (`Downloader`), the installer of an APK (`ApkInstaller`), and — through `GitHubRemoteService` — the newest release on GitHub |

```ts
// ✅ Do
export interface BookmarkRepo {
  getAll(): Bookmark[];
}

export class BookmarkImpl implements BookmarkRepo {
  private readonly storage: LocalStorageService;

  constructor(storage: LocalStorageService) {
    this.storage = storage;
  }

  getAll(): Bookmark[] {
    …
  }
}

// ❌ Do not
export class BookmarkImpl {
  // No interface, so nothing stands between a use case and the class.
  getAll(): Bookmark[] {
    …
  }
}
```

---

## Service Rules

A service is one of two kinds:

- **a module of stateless functions**, called directly — there is nothing to inject;
- **an interface with an implementation**, given to a repository or a use case through its constructor and made in `service_locator.ts`.

A service knows `model/` and the gyo plugins (`@gyo-community/http`, `@gyo-community/media`) only. The one exception is `service_locator.ts`, which assembles everything.

| File | Kind | Role |
|---------|------|------|
| `html_client.ts` | class `HtmlClient` | Fetches the pages of one site through the native relay: retries, decodes, throws a `Failure` |
| `github_remote_service.ts` | class `GitHubRemoteService` | The newest release of the app: asks the releases API of GitHub through an `HtmlClient`, and reads the tag, the page and the APK out of the answer, or throws a `ParseFailure` |
| `community_headers.ts` | constants | The two user agents and the browser headers shared by page fetches |
| `service_locator.ts` | functions | The request settings of every known site; the factory of every use case and repository |
| `html_service.ts` | functions | `parseHtml` and the DOM helpers the parsers use: `tryParseInt`, `extractNumber`, `textOf`, `attrOf`, `statOf`, `statOfAny`, `queryFirst`, `textOfAny` |
| `content_scanner.ts` | functions | Markup to `ContentBlock[]`: `scanContentFull` for the body of a post, `scanContentCompact` for a comment |
| `media_classifier.ts` | functions | `classify(url)`, `unwrapDownloadPhp`, `extractYoutubeId` |
| `local_storage_service.ts` with `browser_local_storage_service.ts` | interface and class | Key–value storage of the page's origin; a list is kept as JSON |
| `image_hash_service.ts` | interface `ImageHashService`, class `FlutterImageHashService` | The dHash fingerprint of an image, fetched through the relay and read on a canvas |

`HtmlClient` is a class without an interface: what depends on it takes `Pick<HtmlClient, 'get'>`. A few helpers of these files are not called by the app: `media_dedup.ts` as a whole is used by nothing, and `scanContent`, `isLoadableImage` and `attrOfAny` by tests only.

Until 2026-11-28 the app was a Flutter app (its last version is the tag `v3.14.3`). The web code keeps some of what it did on purpose — the shape in which it stored things, the fingerprints it computed — which is why a comment names a Dart function and the hash service is called `FlutterImageHashService`.

---

## Dependency Wiring

There is no DI container. `web/src/service/service_locator.ts` exports one factory per object of the app:

| Factory | Makes |
|---------|-------|
| `htmlClient(id)` | An `HtmlClient` over the one relay (`Http`), with the request settings of `id` |
| `communityRepos()` | The `CommunityRepo` of every registered community, by id |
| `feedUseCase()` | `FeedUseCase` over `communityRepos()` and a `FeedImpl` |
| `bookmarkUseCase()` | `BookmarkUseCase` over a `BookmarkImpl` |
| `blockImageUseCase()` | `BlockImageUseCase` over a `BlockedImageImpl` and a `FlutterImageHashService` |
| `saveMediaUseCase()`, `shareMediaUseCase()` | The two media use cases over the one `MediaSaveImpl` |
| `updateUseCase()` | `UpdateUseCase` over an `UpdateImpl`, which holds the one relay, a `GitHubRemoteService` and the three plugins of the update |

- Each factory of a use case or a repository keeps its object in a module-level variable and makes it the first time it is asked (`??=`). `htmlClient(id)` makes a client over the one relay, which is itself made once. No object is made when the module is imported: a repository holds the relay, which exists only in the WebView.
- A factory names interfaces where it can (`Record<RegisteredCommunityId, CommunityRepo>`), and is the only code that names an impl class.
- A provider imports the factory of its use case. A page never sees a use case.
- Tests do not swap registrations. A notifier or a use case under test is constructed with fakes; a page under test gets fakes by replacing the module with `vi.doMock('../../src/service/service_locator', …)` — see [TESTING_POLICY.md](TESTING_POLICY.md).

---

## The Update of the App

The app is not in a store: the 버전 row of Settings looks for a newer release on GitHub, downloads it and hands it to the system's installer (`PRODUCT_PLAN.md` §4). It is the one feature that asks the native side about the app itself, and three things in it are not what they look like.

- **`__APP_VERSION__` is the version of the build, never the one that is installed.** The shell loads the web app from the deployed address, so a 4.0.0 shell runs a web app built later. The installed version is what the shell reads from Android (`PackageInfo` of `@gyo-community/device-info`). The constant is shown in one place only: a page in a browser, which has no shell to ask.
- **A 4.0.0 shell is told by one sentence.** `isAvailable()` of a gyo plugin says only that a native bridge exists; it is true on every shell. The bridge core answers `Bridge 'device_info' not found` when the shell has no handler for that bridge, and only a shell from before the updater has none. `UpdateImpl.getInstalledVersion()` answers `null` for that sentence and rethrows everything else. So a plugin that fails is a failed reading — `확인 실패`, never a number made up — and the 4.0.0 shell is 4.0.0, in what the row shows and in what it compares. A change to that sentence in the bridge core (`shell/android/gyo-bridge/`) is a change here.
- **A version on its way is left alone.** `UpdateNotifier` asks GitHub when Settings opens, and only from a status where nothing is on its way (`upToDate`, `available`, `checkFailed`). While a release is downloading, downloaded or waiting for the reader, the row is not looked at again, so the release does not change under the reader's hand. On the way back from the system's installer or its settings (`visibilitychange`), the installed version or the permission is read again, and GitHub is not asked.

The chain is `model/app_update.ts` → `repository/update/` (`UpdateRepo`; `UpdateImpl` over the three plugins) → `service/github_remote_service.ts` → `use_case/update_use_case.ts` → `provider/update_provider.ts` → `widgets/update_row.tsx`. A download the page cancelled is a `DownloadOutcome` of its own, not a failure. The percent is capped at 99 until the file is whole.

---

## Data Source: Community HTML Through the Native Relay

No REST API and no backend. The shell's native relay (`Http` of `@gyo-community/http`) requests a community's pages on the device. The WebView never asks for a page itself: cross-origin responses are hidden by CORS, and servers answer a WebView's own user agent or a foreign `Referer` with a redirect or a 403. Images and videos do load in the WebView, with no Referer (`web/index.html`).

One community is served: 웃대 (humoruniv), its 웃긴자료 (`pds`) board — by decision of the user (2026-11-28).

**Request settings.** `htmlClientOptions[id]` in `service_locator.ts` holds, for every community the models know: the base URL, the headers of every request (the site's user agent, the browser headers, the `Referer`), the charset, and the name of the cookie jar when the site needs one. `community_headers.ts` has the two user agents — humoruniv is read as a phone, the others as a desktop browser — and the browser headers.

**Fetch.** `HtmlClient.get(path)` asks the relay for `baseUrl + path` with those headers and that jar. A 503 is asked again after 1 s, 4 s and 10 s, or after what `Retry-After` names when that is 30 s or less; no answer at all is asked again after 0.5 s, 1 s and 2 s. A status outside 2xx throws a `ServerFailure` (`HTTP 403`) with the status, the response headers that say why (`server`, `cf-ray`, `cf-mitigated`, `retry-after`, `content-type`, `date`), the first 500 characters of the body, and the path. No answer after the retries throws a `NetworkFailure`. Anything in 2xx is decoded with the site's charset; malformed bytes become U+FFFD.

**Parse.** `HtmlCommunityRepo` (`repository/community/html_community_repo.ts`) is the base class of a community read from HTML. Its `fetchLatest()` fetches `listPath(page)`, parses the markup with `parseHtml` — a `DOMParser`, so scripts never run and nothing is loaded — takes every element that `listRowSelector()` matches, and maps each with `parseListRow(row)`, dropping those that answer `null`; `computeNextPageToken()` says where the list continues. `fetchDetail(id)` is the community's own. The parser is the methods of the community's `*_impl.ts` and the functions beside the class, over the helpers of `html_service.ts` and `content_scanner.ts`. None of it holds state, and none of it throws for markup that is missing.

`HumorunivImpl` reads the list at `/board/list.html?table=pds&pg=<page>` (`pg` is 0-based) and a post at `/board/read.html?table=pds&number=<id>`.

**Use.** `FeedUseCase.getMergedFeed()` asks every community that is on in parallel, sorts what came latest first — posts that share a date are interleaved by community, and posts without a date come first — and keeps at most 20 posts per community. `getPostDetail(community, id)` asks that community's repository, and answers a `ParseFailure` when the page has no body, no image and no comment (`looksEmpty`): nearly always a block or an interstitial, not an empty post.

### Adding a community

A community joins the app in three places that the compiler keeps in step:

1. its id in `registeredCommunityIds`, and
2. its metadata in `communities` — both in `web/src/model/community.ts`;
3. its repository in `communityRepos()` of `web/src/service/service_locator.ts`.

The feed, the settings switches and the tab bar all take `registeredCommunities`, which is made from the first two, so nothing is written per community anywhere else. This is not to be done unless the user asks: the other communities are not planned. `communityIds` and `communityBaseUrls` list every community the models know, served or not, so that saved data and links of any community still type and resolve.

---

## Adding a New Feature

In the order the layers demand:

1. **Feature Consensus** — for a screen or a significant feature, see the checklist in [AGENTS.md](../AGENTS.md).
2. **model/** — the types and the functions on them; a failure kind if one is needed.
3. **The parser**, when the feature reads something new from a page — in the community's `*_impl.ts`, written against a page sample in `web/test/fixtures/`, with the tests that read it.
4. **repository/** — `web/src/repository/<feature>/<feature>_repo.ts` and `<feature>_impl.ts`, raw values out.
5. **service/** — when a new outside thing is read or written: an interface and an implementation, or a module of functions.
6. **use_case/** — `XxxUseCase extends BaseUseCase`: private dependencies from the constructor, a `Result` back.
7. **service/service_locator.ts** — a factory that makes the use case, and what it needs, once.
8. **provider/** — `XxxNotifier extends StateNotifier`, with `xxxNotifier()` and `useXxx()` in a `*_provider.ts`.
9. **widgets/** — the new pieces of UI, with their data and `on*` callbacks.
10. **pages/** — the `*_view.tsx` that reads the provider and passes data and callbacks down. A new page also gets its path in `utils/router.ts` and its line in `app.tsx`.
11. **Tests** — each step with its test under `web/test/`; `make check` passes before the commit.
