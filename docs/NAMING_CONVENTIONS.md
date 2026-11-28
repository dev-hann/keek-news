# Naming Conventions

Files and folders are `snake_case`, as they were in the Dart app the web app was ported from. Identifiers follow TypeScript.

## File Naming

| Layer | Pattern | Examples |
|-------|---------|----------|
| Service (functions) | `*_service.ts`, or what it is | `html_service.ts`, `content_scanner.ts`, `media_classifier.ts`, `media_dedup.ts`, `community_headers.ts` |
| Service (interface) | `*_service.ts` | `local_storage_service.ts`, `image_hash_service.ts` |
| Service (class) | `<tech>_*_service.ts`, or `*_client.ts` | `browser_local_storage_service.ts`, `html_client.ts` |
| Composition root | `service_locator.ts` | `service/service_locator.ts` |
| Repository (interface) | `*_repo.ts` | `bookmark_repo.ts`, `community_repo.ts`, `feed_repo.ts` |
| Repository (impl) | `*_impl.ts` | `bookmark_impl.ts`, `humoruniv_impl.ts` |
| Repository (base class) | `html_community_repo.ts` | `HtmlCommunityRepo` |
| UseCase | `*_use_case.ts` | `feed_use_case.ts`, `base_use_case.ts` |
| Provider | `*_provider.ts` | `merged_feed_provider.ts`, `state_notifier.ts` |
| Provider actions | `*_actions.ts` | `media_actions.ts`, `post_actions.ts` |
| Provider hook | what it is | `comments_sheet.ts` |
| Model | a noun, or what the file builds | `feed_item.ts`, `post_detail.ts`, `failures.ts`, `result.ts`, `url_builder.ts`, `video_id.ts` |
| Screen (view) | `*_view.tsx` | `home_view.tsx` |
| App root | `app.tsx`, `main.tsx` | |
| Widget | its description, no suffix | `feed_card.tsx`, `app_bar.tsx`, `settings_tile.tsx` |
| UI primitive | `components/ui/<name>.tsx` | `button.tsx`, `card.tsx` |
| Utility | what it does; a hook is `use_*.ts` | `time_ago.ts`, `router.ts`, `use_image_loader.ts`, `use_history_back.ts` |
| Test | `<file>.test.ts`, `<file>.test.tsx` | `feed_use_case.test.ts`, `feed_card.test.tsx` |
| Test helper | `test/helpers/*.ts` | `fixtures.ts` |
| Fixture | `<board>_<post number>.html` | `pds_1415455.html` |

### Subdirectories within Layers

```
web/src/
  repository/community/     # the contract (community_repo.ts) + the HTML base (html_community_repo.ts)
    <community>/            # <community>_impl.ts per community (humoruniv/humoruniv_impl.ts)
  repository/<feature>/     # <feature>_repo.ts + <feature>_impl.ts
  model/                    # flat
web/test/                   # the same folders as web/src/, plus fixtures/, helpers/ and integration/
```

A community's scraping code is one file, `repository/community/<community>/<community>_impl.ts`, a class that extends `HtmlCommunityRepo`. There is no `<community>_repo.ts`: `CommunityRepo` is the contract of every community.

The tests of the pages and of `app.tsx` are in `web/test/widgets/`, beside the tests of the widgets they are made of. `web/src/components/` and `web/src/lib/` have no tests.

---

## Class Naming

| Layer | Interface | Implementation Class | Notes |
|-------|---------------|---------------------|-------|
| Service | `XxxService` | `<Tech>XxxService` | `LocalStorageService` / `BrowserLocalStorageService`, `ImageHashService` / `FlutterImageHashService`. `HtmlClient` is a class without an interface |
| Repository | `XxxRepo` | `XxxImpl` | `implements`; a community's `<Community>Impl extends HtmlCommunityRepo` |
| UseCase | — | `XxxUseCase` | Named after the noun; `extends BaseUseCase`; methods named after the operation |
| Provider | — | `XxxNotifier` | `extends StateNotifier<State>`; lives in a `*_provider.ts` |
| Model | `interface Xxx`, `type Xxx` | — | `FeedItem`, `PostDetail`, `Result<T>`; no classes besides `Failure` |
| Failure | `Failure` (abstract class) | `ServerFailure`, `NetworkFailure`, `ParseFailure` | `extends Failure` |
| Widget | `XxxProps` | function `Xxx` | `FeedCardProps` / `FeedCard`; the props interface is not exported |
| Screen | `XxxViewProps` | function `XxxView` | `HomeViewProps` / `HomeView` |

The name `FlutterImageHashService` says what it is: the service computes the fingerprint the way the Flutter app did — the app was Flutter until 2026-11-28, and its last version is the tag `v3.14.3` — so that the same picture has the fingerprint it had there.

---

## General Naming

- Types, interfaces, classes, components: `PascalCase`
- Variables, functions, methods: `camelCase`; a hook starts with `use` (`useMergedFeed`, `useImageLoader`)
- Files, folders: `snake_case`
- Module-level constants: both `camelCase` (`maxRetryAfterMs`, `legacyAttachmentPattern`) and `UPPER_SNAKE_CASE` (`STORAGE_KEY`, `CONTROLS_HIDE_AFTER`) occur; follow the file you are in
- Private members: the TypeScript `private` and `protected` keywords, `readonly` where nothing reassigns — no `_` prefix
- A type-only import: `import type { … }`, or `type X` inside the braces (`verbatimModuleSyntax` is on)
- A set of names: a union of string literals (`type FailureKind = 'ServerFailure' | 'NetworkFailure' | 'ParseFailure'`), never an `enum`
- A screen ends in `View`. Two widgets do too (`EmptyStateView`, `ErrorStateView`), so the folder tells a screen from a widget.

### Function Naming

| What | Pattern | Examples |
|------|---------|----------|
| The one instance of a provider | `xxxNotifier()` | `mergedFeedNotifier()`, `bookmarkNotifier()`, `settingsNotifier()` |
| A factory of the locator | `xxxUseCase()`, `xxxRepo()` | `feedUseCase()`, `mediaSaveRepo()`, `communityRepos()` |
| A hook that reads a provider | `useXxx()` | `useMergedFeed()`, `useSettings()` |
| An action a page hands to a widget | a verb | `copyPostLink()`, `toggleBookmark()`, `blockImage()` |

### Method Naming

| Action | Pattern | Examples |
|--------|---------|----------|
| Fetch data | `fetch*` / `get*` | `fetchLatest()`, `fetchDetail(id)`, `getMergedFeed()`, `getAll()` |
| Ask again | `refresh()` / `retry*` | `refresh()`, `retryDetail(key)` |
| Change a setting | `toggle*` | `toggleCommunity(id)`, `toggle(bookmark)` |
| Ask a condition | `is*` / `can*` / `has*` | `isBookmarked()`, `canDisable(id)`, `cursorHasMore()` |
| Convert | `to*` / `from*` / `parse*` | `bookmarkToJson()`, `feedItemFromBookmark()`, `parseFeedItemKey()` |
| The one operation of a media use case | `call(target)` | `SaveMediaUseCase.call()` |

### Widget Callback Naming

Every action callback a widget takes has the `on*` prefix. The page implements the callback and wires it to providers. A prop that is data is a noun: `post`, `detail`, `comments`, `images`, `bookmarked`. (The one callback without the prefix in the code is `run` of `PendingRow`, a private helper inside `media_action_sheet.tsx`.)

| Callback | Used for |
|----------|----------|
| `onBack` | go back |
| `onOpenSettings`, `onOpenBookmarks`, `onOpenBlockedImages` | open another page (a page's props) |
| `onRetry` | ask again for what failed |
| `onCopyLink`, `onCopyError(error)` | copy the link of a post; the report of why its body failed |
| `onToggleBookmark` | save or unsave |
| `onOpenComments`, `onOpenImage(index)`, `onOpenVideo(id, block)` | open the comments, an image full screen, a video |
| `onMore(target)` | open the media action sheet |
| `onSelect(id)` | pick a tab |
| `onRefresh` | pull to refresh |
| `onClose` | close a sheet or a dialog |

```tsx
// ✅ Do
<FeedCard
  post={item}
  bookmarked={saved}
  onToggleBookmark={() => void toggleBookmark(item)}
/>

// ❌ Do not — non-on prefix or imperative handle* name
<FeedCard handleBookmark={() => …} />
```

---

## Test Naming

- A test file is the source file's name with `.test.ts` or `.test.tsx`, in the folder of `web/test/` that mirrors `web/src/`: `src/use_case/feed_use_case.ts` → `test/use_case/feed_use_case.test.ts`. A test of one aspect of a file says what it is about: `html_service_candidates.test.ts`, `html_community_repo_date.test.ts`.
- A suite is named after what it tests: `describe('FeedUseCase')`, `describe('MergedFeedNotifier.refresh')`, `describe('FeedCard')`.
- A case is a sentence that states the behaviour: `it('keeps the items shown when the refresh fails')`.
- A builder in a test is the noun (`post()`, `detail()`, `comment()`); a fake is what it stands for (`relay()`, `fake`).
- A page sample is `<board>_<post number>.html`: `pds_1415455.html` is post 1415455 of the `pds` board.
