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

1. Plain class with `UseCase` suffix (`GetMergedFeedUseCase`)
2. Repo calls return `Either<Failure, T>` (dartz) — wrap fallible operations
3. No internal state holding (`_field`, `_cache`)
4. Dependencies declared as `_` prefix private fields
5. Return results only; state managed by Provider

```dart
// ✅ Do
class CheckForUpdateUseCase {
  CheckForUpdateUseCase(this._repo, {required this.currentVersion});
  final UpdateRepo _repo;
  final String currentVersion;

  Future<Either<Failure, UpdateCheckResult>> call() async {
    return _repo.getLatestRelease().then(
      (either) => either.flatMap(
        (release) => Right(
          UpdateCheckResult(
            type: _isNewer(release.version, currentVersion)
                ? UpdateStatusType.updateAvailable
                : UpdateStatusType.upToDate,
            release: release,
          ),
        ),
      ),
    );
  }
}
```

### Error Handling

| Situation | Return Type |
|--------------------------|----------------------------|
| Method returns a value | `Either<Failure, T>` (dartz) |
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

## Repository Rules

1. Abstract class (`XxxRepo`) + implementation (`XxxImpl`) separated
2. Implementation uses `implements`
3. Services injected via constructor
4. Feature-grouped: `repository/<feature>/<feature>_repo.dart` + `<feature>_impl.dart`
5. Community repos (`HumorunivRepo`, `DogdripRepo`, ...) bundle list + detail + community-specific HTML parsing logic

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
