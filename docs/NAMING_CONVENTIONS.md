# Naming Conventions

## File Naming

| Layer | Pattern | Examples |
|-------|---------|----------|
| Service (abstract) | `*_service.dart` | `html_service.dart`, `apk_installer_service.dart`, `bookmark_local_service.dart` |
| Service (concrete) | `<tech>_*_service.dart` | `dio_html_service.dart`, `method_channel_apk_installer_service.dart`, `prefs_bookmark_local_service.dart` |
| Repository (abstract) | `*_repo.dart` | `bookmark_repo.dart`, `community_repo.dart` |
| Repository (impl) | `*_impl.dart` | `bookmark_impl.dart`, `humoruniv_impl.dart` |
| UseCase | `*_use_case.dart` | `feed_use_case.dart`, `update_use_case.dart` |
| Provider | `*_provider.dart` | `merged_feed_provider.dart` |
| Model (entity) | singular noun | `feed_item.dart`, `post_detail.dart` |
| Model (failure) | `failures.dart` | `failures.dart` |
| Screen (view) | `*_view.dart` | `home_view.dart` |
| Widget | descriptive, no suffix | `feed_card.dart` |
| Test | `*_test.dart` | `dio_html_service_test.dart` |
| Fixture | `*.html` | `dogdrip_list.html` |

### Subdirectories within Layers

```
lib/
  repository/community/          # base contract (community_repo.dart) + shared HTML scraping base (html_community_repo.dart)
    <community>/                 # <community>_impl.dart per community (e.g. dogdrip/dogdrip_impl.dart)
  model/                         # entities + failures flat
```

Community scraping code groups under `repository/community/`. Each community has its own subfolder with `<community>_impl.dart` extending `HtmlCommunityRepo` (abstract HTML scraping base). Add `<community>_repo.dart` only when community-specific contract methods are needed.

---

## Class Naming

| Layer | Abstract Class | Implementation Class | Notes |
|-------|---------------|---------------------|-------|
| Service | `XxxService` | `<Tech>XxxService` | e.g. `HtmlService`/`DioHtmlService`, `ApkInstallerService`/`MethodChannelApkInstallerService` |
| Repository | `XxxRepo` | `XxxImpl` | Use `implements` (not `extends`) |
| UseCase | — | `XxxUseCase` | Domain-facade: noun prefix (`FeedUseCase`, `BookmarkUseCase`), extends `BaseUseCase`, multiple named methods (no `call()`) |
| Provider | — | `XxxNotifier` / `XxxProvider` | Riverpod Notifier/AsyncNotifier |
| Model (entity) | — | `Xxx` | `extends Equatable`; persisted entities own `toJson`/`fromJson` directly |
| Failure | `Failure` (abstract) | `ServerFailure`, `NetworkFailure`, ... | `extends Failure` |
| Widget/Screen | — | `XxxView` (screens), `Xxx` (widgets) | Screen classes end in `View` |

---

## General Naming

- Classes: `PascalCase`
- Variables, functions, methods: `camelCase`
- Private members: `_camelCase`
- Files, directories: `snake_case`
- Constants: `camelCase` (Dart convention)

### Method Naming

| Action | Pattern | Examples |
|--------|---------|----------|
| Fetch data | `fetch*` / `get*` / `load*` | `getMergedFeed()`, `fetchLatest()` |
| Request | `request*` | `requestPermission()` |
| Initialize | `init*` | `init()` |
| Update state | `update*` | `updateTheme()` |

### Widget Callback Naming

All action callbacks exposed by a widget use the `on*` prefix. The page implements them and wires them to providers.

| Callback | Used for |
|----------|----------|
| `onTap` / `onPressed` | generic taps |
| `onBookmarkTap` | bookmark toggle |
| `onImageTap(int index)` | image/video carousel item tap |
| `onCommentsTap` | open comments |
| `onCopyTap` | copy link |

```dart
// ✅ Do
FeedCard(onBookmarkTap: () => ref.read(bookmarkProvider.notifier).toggle(b));

// ❌ Do not — non-on prefix or imperative handle* name
FeedCard(handleBookmark: () => ...);
```
