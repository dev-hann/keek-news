# Naming Conventions

## File Naming

| Layer | Pattern | Examples |
|-------|---------|----------|
| Service / Datasource | `*_service.dart`, `*_impl.dart` | `html_client_impl.dart`, `apk_installer_service.dart` |
| Repository (abstract) | `*_repo.dart` | `bookmark_repo.dart`, `merged_feed_repo.dart` |
| Repository (impl) | `*_impl.dart` | `bookmark_impl.dart`, `merged_feed_impl.dart` |
| UseCase | `*_use_case.dart` | `get_merged_feed_use_case.dart`, `check_for_update_use_case.dart` |
| Provider | `*_provider.dart` | `merged_feed_provider.dart` |
| Model (entity) | singular noun | `feed_item.dart`, `post_detail.dart` |
| Model (DTO) | `*_dto.dart` | `feed_item_dto.dart` |
| Model (failure) | `failures.dart` | `failures.dart` |
| Parser | `*_parser.dart` | `dogdrip_list_parser.dart` |
| Screen (view) | `*_view.dart` | `home_view.dart` |
| Widget | descriptive, no suffix | `feed_card.dart` |
| Test | `*_test.dart` | `dogdrip_list_parser_test.dart` |
| Fixture | `*.html` | `dogdrip_list.html` |

### Subdirectories within Layers

```
lib/
  repository/<feature>/    # <feature>_repo.dart + <feature>_impl.dart together
  service/parser/          # HTML parsers
  model/                   # entities + DTOs + failures flat
```

Each feature gets its own folder under `repository/` (interface + impl together).

---

## Class Naming

| Layer | Abstract Class | Implementation Class | Notes |
|-------|---------------|---------------------|-------|
| Repository | `XxxRepo` | `XxxImpl` | Use `implements` (not `extends`) |
| UseCase | — | `XxxUseCase` | Suffix `UseCase` (e.g. `GetMergedFeedUseCase`) |
| Provider | — | `XxxNotifier` / `XxxProvider` | Riverpod Notifier/AsyncNotifier |
| Model (entity) | — | `Xxx` | `extends Equatable` |
| Model (DTO) | — | `XxxDto` | `extends Equatable`, has `toEntity()` |
| Failure | `Failure` (abstract) | `ServerFailure`, `NetworkFailure`, ... | `extends Failure` |
| Parser | — | `XxxListParser`, `XxxDetailParser` | Stateless static methods |
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
