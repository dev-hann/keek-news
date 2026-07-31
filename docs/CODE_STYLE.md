# Code Style

See [ARCHITECTURE.md](ARCHITECTURE.md) for layer boundaries. See [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md) for naming.

## Dart Style

- Run `flutter analyze` before every commit. Zero errors.
- No `late` keyword. Use nullable types or constructor injection.
- Import order: `dart:` → `package:flutter` → `package:` → relative.
- No comments unless explicitly requested.

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

Return pattern in repository:
```dart
try {
  final items = await _service.fetch();
  return Right(items);
} catch (e) {
  return Left(ServerFailure(e.toString()));
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
