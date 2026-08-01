# Code Style

See [ARCHITECTURE.md](ARCHITECTURE.md) for layer boundaries. See [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md) for naming.

## Dart Style

- Run `flutter analyze` before every commit. Zero errors.
- No `late` keyword. Use nullable types or constructor injection.
- Import order: `dart:` → `package:flutter` → `package:` → relative.
- No "what" comments (restating code). Concise "why" comments allowed for non-obvious behavior, design intent, or regression rationale. Public APIs keep `///` dartdoc.

## Model Rules

1. All entities/failures MUST `extends Equatable`
2. All fields MUST be `final` (immutability)
3. Entities that need persistence (e.g. `Bookmark`, `AppRelease`) own `toJson`/`fromJson` directly — no separate DTO layer
4. Override `props` with all identity fields

```dart
// ✅ Do
class FeedItem extends Equatable {
  const FeedItem({required this.id, required this.title, ...});
  final String id;
  final String title;

  @override
  List<Object?> get props => [id, title, ...];
}
```

> Note: For fields that are `Map` or `Set`, spread/convert them into a `List` inside `props` (Equatable deep-compares lists of Equatables, not maps/sets).

## Error Handling

Use `Either<Failure, T>` from dartz throughout.

Failure hierarchy (`model/failures.dart`):
```dart
abstract class Failure extends Equatable implements Exception {
  const Failure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure { ... }
class NetworkFailure extends Failure { ... }
class ParseFailure extends Failure { ... }
```

Error boundary lives in UseCase — repos return raw types and throw on failure:

```dart
// Repository: raw return, no try-catch
class BookmarkImpl implements BookmarkRepo {
  @override
  Future<List<Bookmark>> getAll() => _dataSource.getAll(); // throws on error
}

// UseCase: extends BaseUseCase, wraps with guard()
class BookmarkUseCase extends BaseUseCase {
  Future<Either<Failure, List<Bookmark>>> getAll() => guard(_repo.getAll);
}
```

Process in Provider via `fold()`:
```dart
final either = await useCase(params);
either.fold(
  (failure) => /* error state */,
  (value) => /* success state */,
);
```

## Service Rules

- `HtmlService` (concrete: `DioHtmlService`) is the single HTML service — owns HTTP fetch + charset decode + DOM parsing utilities (extractNumber, textOf, statOf, scanContent, etc.).
- All service files follow `*_service.dart` naming (abstract) / `<tech>_*_service.dart` (concrete).
- Services are constructor-injected into Repositories.

## Riverpod Provider Rules

- Providers call use cases, never repositories or services directly.
- Use `AsyncNotifierProvider` or `NotifierProvider` for state.
- Provider file names match the feature: `merged_feed_provider.dart`.
- Sole state holder — branch on UseCase results with `fold()`.

## Lint Rules

Base: `very_good_analysis` (see `analysis_options.yaml`).

Run `make fix` to auto-format and apply safe lint fixes.

## shadcn_ui Style Rules

- App root is `ShadApp.router` (`lib/app.dart`), not `MaterialApp`. Material `ThemeData` is derived automatically by `ShadApp` so legacy Material widgets keep working.
- `ScaffoldMessenger` is NOT auto-provided by `ShadApp` (it uses `WidgetsApp`). The app's `builder` callback wraps the child in `ScaffoldMessenger` to support snackbars.
- Theme tokens come from `ShadTheme.of(context)`:
  - `colorScheme.foreground` / `mutedForeground` — text
  - `colorScheme.muted` — neutral/skeleton
  - `colorScheme.primary` / `primaryForeground` — brand
  - `colorScheme.border` — dividers
  - `colorScheme.accent` — hover/pressed
- Text styles use shadcn semantic names: `textTheme.p` (body), `textTheme.small`, `textTheme.h4`, etc. Material `Theme.of(context).textTheme.*` still works for legacy code.
- Icons use `LucideIcons.foo` (re-exported via `package:shadcn_ui/shadcn_ui.dart`). No Material `Icons.*`.
- Spacing is raw literals (`EdgeInsets.all(16)`), no central spacing tokens.
- For new widgets, prefer shadcn primitives (`ShadCard`, `ShadButton`, `ShadBadge`, `ShadAvatar`, `ShadAlert`, `ShadSeparator`, `ShadIconButton`, `ShadSheet`, `ShadDialog`, `ShadTabs`). Compose multiple primitives when no 1:1 match exists.
- For widget tests, use `shadHarness(body)` or `shadApp({home, navigatorKey})` from `test/helpers/shad_harness.dart`. Plain `MaterialApp` will not provide `ShadTheme`.
