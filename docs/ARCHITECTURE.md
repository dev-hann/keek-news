# Layer Architecture

## 4-Layer Structure

```
Service → Repository → UseCase → Provider
```

| Layer | Role | State |
|------------|-----------------------------------|----------------|
| **Service** | HTTP/DOM parsing, SDK wrapping, persistence | None |
| **Repository** | Service composition + community-specific parsing | None |
| **UseCase** | Business logic + error handling + multi-source fan-out | None |
| **Provider** | State management (Riverpod) | **Sole holder** |

```
lib/
├── service/      datasources + HtmlService + DI (service_locator.dart)
├── repository/   abstract (*_repo.dart) + impl (*_impl.dart), feature-grouped
├── use_case/     business operations (*_use_case.dart)
├── provider/     Riverpod providers (Notifier/AsyncNotifier)
├── model/        entities + failures (Equatable, pure data)
├── pages/        screens (*_view.dart) — consume providers
├── widgets/      reusable UI
├── const/        design tokens, theme
└── utils/        pure helpers
```

---

## Layer Access Rules

Each layer may only reference the layer directly below. Skipping is prohibited.

```dart
// ✅ Do
provider  → useCase.method()
useCase   → repo.method()
repo      → service.method()

// ❌ Do not
provider  → repo                          // skip UseCase
provider  → service                       // skip UseCase + Repo
useCase   → service                       // skip Repo
provider  → useCase._repo                 // access internal field (private too)
```

### UseCase Dependencies Must Be Private

```dart
// ✅ Do
class GetMergedFeedUseCase {
  GetMergedFeedUseCase({required this.repos});
  final Map<CommunityId, CommunityRepo> repos;
}

// ❌ Do not
class GetMergedFeedUseCase {
  GetMergedFeedUseCase({required this.repos});
  final Map<CommunityId, CommunityRepo> repos;   // public is acceptable for collections; private preferred for single deps
}
```

---

## UseCase Rules

1. **Domain-facade pattern**: one UseCase per domain concept (`FeedUseCase`, `BookmarkUseCase`, `CacheUseCase`, `UpdateUseCase`). Noun prefix, NOT verb (`Feed` ✅, `GetFeed` ❌).
2. Extend `BaseUseCase` (`lib/use_case/base_use_case.dart`) — provides `guard()` / `guardUnit()` error wrappers
3. UseCase methods return `Either<Failure, T>` (dartz) — error boundary lives here, NOT in Repository
4. Repos return **raw types** and throw on failure; UseCase catches via `guard()`
5. Multiple named methods per domain — **no `call()` method** (e.g. `getMergedFeed()`, `getPostDetail()`, not `call()`)
6. No internal state holding (`_field`, `_cache`)
7. Dependencies declared as `_` prefix private fields
8. Return results only; state managed by Provider

```dart
// ✅ Do
class BookmarkUseCase extends BaseUseCase {
  BookmarkUseCase(this._repo);
  final BookmarkRepo _repo;

  Future<Either<Failure, List<Bookmark>>> getAll() => guard(_repo.getAll);
  Future<Either<Failure, Unit>> add(Bookmark b) => guardUnit(() => _repo.add(b));
}
```

### Error Handling

| Situation | Return Type |
|--------------------------|----------------------------|
| UseCase method returns a value | `Either<Failure, T>` (dartz) |
| Repository method | raw `T` — throws on failure, UseCase catches via `guard()` |
| Failure types | `ServerFailure`, `NetworkFailure`, `ParseFailure` (see `model/failures.dart`) |

---

## Provider Rules (Riverpod)

1. Sole state holder (Riverpod `Notifier` / `AsyncNotifier`)
2. Branch on UseCase results with `fold()`
3. `Either<L, R>` → `fold(left=error, right=success)`
4. Call UseCase methods only; accessing UseCase internal fields (Repo, Service) is prohibited

```dart
// ✅ Do
final either = await getMergedFeedUseCase(params);
either.fold(
  (failure) => state = AsyncValue.error(failure, StackTrace.current),
  (page) => state = AsyncValue.data(page),
);

// ❌ Do not
final page = await getMergedFeedUseCase(params);   // no fold()
getMergedFeedUseCase._repo.fetch();                // access UseCase internal
ServiceLocator.sl<CommunityRepo>();                // Provider fetching Repo directly
```

---

## Widget Rules

Widgets are **dumb, reusable UI**. They never touch state layers directly.

1. **`StatelessWidget` / `StatefulWidget` only** — `ConsumerWidget` / `ConsumerStatefulWidget` are prohibited in `lib/widgets/` and in page-private widget classes.
2. **No `ref.watch` / `ref.read` / `ref.listen` inside widgets** — no provider imports either.
3. **Data is constructor-injected** — every value a widget needs is a `final` constructor param passed from the page.
4. **Actions are `on*` callbacks** — taps, presses, and all interactions are exposed as `onTap`, `onBookmarkTap`, etc. The page implements them and wires them to providers.
5. **Provider access is confined to pages (`*_view.dart`)** — the page `build` watches providers, transforms state, and passes data + callbacks down.
6. **Allowed inside widgets**: pure UI logic only — formatting, animation, local interactive state (expand/collapse), and `context`-based navigation (`Navigator.push`, `showModalBottomSheet`, `Clipboard`). These use `BuildContext`, not providers.

```dart
// ✅ Do — dumb widget
class FeedCard extends StatelessWidget {
  const FeedCard({required this.item, required this.onBookmarkTap, super.key});
  final FeedItem item;
  final VoidCallback onBookmarkTap;

  @override
  Widget build(BuildContext context) { /* render only */ }
}

// Page injects everything
FeedCard(
  item: item,
  isBookmarked: ref.watch(bookmarkProvider).any((b) => b.id == item.id),
  onBookmarkTap: () => ref.read(bookmarkProvider.notifier).toggle(bookmark),
)

// ❌ Do not
class FeedCard extends ConsumerWidget {
  Widget build(context, ref) {
    final item = ref.watch(feedProvider);          // provider in widget
    onTap: () => ref.read(bookmarkProvider)        // action in widget
  }
}
```

### When a widget needs scoped state (e.g. single-active-video coordination)

If a widget needs reactive state that cannot be plain constructor data (e.g. coordinating which inline video is playing), inject an **abstract controller** (`VideoPlaybackController`) via constructor. The page resolves it from a provider and passes it down. The widget depends on the abstraction only — never on `ref`.

---

## Page Structure Rules

1. **One widget per page file** — a `*_view.dart` contains exactly one widget (the `View` + its `State` pair counts as one). No additional widget classes in the same file.
2. **Private widget classes (`_Xxx extends ...Widget`) in a page file are prohibited** — extract them to `lib/widgets/` as public widgets with injected data + `on*` callbacks.
3. **Build helper methods** (`Widget _buildX()`) are allowed — they are methods, not classes.

```dart
// ✅ Do — home_view.dart contains only HomeView + _HomeViewState
class HomeView extends ConsumerStatefulWidget { ... }
class _HomeScreenState extends ConsumerState<HomeView> { ... }

// ❌ Do not — extra widget classes co-located
class _CommunityTabBar extends StatelessWidget { ... }   // extract → widgets/
class _FeedCard extends ConsumerWidget { ... }            // delete; page owns provider wiring
```

---

## Repository Rules

1. Abstract class (`XxxRepo`) + implementation (`XxxImpl`) separated
2. Implementation uses `implements`
3. Services injected via constructor
4. Feature-grouped: `repository/<feature>/<feature>_repo.dart` + `<feature>_impl.dart`
5. Community scrapers group under `repository/community/<community>/`; each `<community>_impl.dart` extends `HtmlCommunityRepo` (abstract HTML scraping base). Add a per-community `_repo.dart` only when community-specific contract methods are needed.
6. Repos return **raw types** and throw on failure — NO try-catch, NO Either. Error handling is UseCase's responsibility (via `BaseUseCase.guard()`).

```dart
// ✅ Do
abstract class BookmarkRepo {
  Future<List<Bookmark>> getAll();
}

class BookmarkImpl implements BookmarkRepo {
  BookmarkImpl(this._localService);
  final BookmarkLocalService _localService;

  @override
  Future<List<Bookmark>> getAll() => _localService.getAll();
}

// ❌ Do not
class BookmarkImpl {                              // no abstract separation
  BookmarkImpl(this.httpClient);                  // direct external call
}
```

### DI Registration

```dart
// ✅ Do — register abstract, not impl
sl.registerLazySingleton<BookmarkRepo>(() => BookmarkImpl(sl()));

// ❌ Do not
sl.registerLazySingleton<BookmarkImpl>(...);      // register impl, not abstract
```

---

## Service Rules

1. Single responsibility (own role only)
2. Stateless (instance methods, no shared state)
3. Constructor-injected into Repository
4. File naming: `*_service.dart` (abstract) / `<tech>_*_service.dart` (concrete)

| Service | Role |
|---------|------|
| `HtmlService` / `DioHtmlService` | HTTP fetch + charset decode + DOM parsing utilities + content scanning |
| `ApkInstallerService` / `MethodChannelApkInstallerService` | Android system install via MethodChannel |
| `ApkDownloadService` / `DioApkDownloadService` | File download via Dio |
| `GitHubRemoteService` / `DioGitHubRemoteService` | GitHub API calls via Dio |
| `ImageCacheService` / `DefaultImageCacheService` | flutter_cache_manager wrapping |
| `BookmarkLocalService` / `PrefsBookmarkLocalService` | SharedPreferences-backed bookmark persistence |

---

## Dependency Injection

All dependencies registered in `service/service_locator.dart` using GetIt.

- Register interfaces mapped to implementations (abstract, not impl).
- Singletons for stateless services.
- UseCases resolved via `sl<XxxUseCase>()`.
- Provider tests may swap registrations via `di.sl` in `setUp`/`tearDown`.

---

## Data Source: Multi-Community HTML Parsing

No REST API. The app fetches HTML pages from multiple communities and parses them.

Supported communities (웃긴자료/pds board): **dogdrip, ppomppu, todayhumor, humoruniv**.

- `HtmlService` (concrete `DioHtmlService`) handles HTTP + charset decoding + DOM utilities (parsing helpers + content scanning).
- Per-community Repositories (`repository/<community>/`) orchestrate: fetch → parse → return entities. Each Repo holds community-specific selectors + parsing logic inline.
- `GetMergedFeedUseCase` fans out across all 4 community Repos in parallel, merges results into a unified `MergedPage` (sorted by publishedAt, interleaved by community).
- `GetPostDetailUseCase` dispatches to the correct community Repo for detail fetch.

## Adding a New Feature

See the checklist in [AGENTS.md](../AGENTS.md).
