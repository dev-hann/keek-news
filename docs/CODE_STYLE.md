# Code Style

See [ARCHITECTURE.md](ARCHITECTURE.md) for layer boundaries. See [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md) for naming.

## Dart Style

- Run `flutter analyze` before every commit. Zero errors.
- No `late` keyword. Use nullable types or constructor injection.
- Import order: `dart:` → `package:flutter` → `package:` → relative.
- No comments unless explicitly requested.

## Model Rules

1. All entities/DTOs/failures MUST `extends Equatable`
2. All fields MUST be `final` (immutability)
3. DTOs MUST have `toEntity()` returning the corresponding entity
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

Return pattern in repository/datasource:
```dart
try {
  final dto = await _datasource.fetch();
  return Right(dto.toEntity());
} on ServerException {
  return Left(ServerFailure('...'));
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

## Parser Rules

Parsers live in `service/parser/`. Convert raw HTML strings into typed DTOs.

- Stateless classes with static methods.
- Input: `String html` → Output: `Dto` or `List<Dto>`.
- DOM selector failures MUST NOT crash — return empty/default values.
- One parser per HTML page structure per community.
- Each parser MUST have corresponding fixture HTML in `test/fixtures/`.

Pattern:
```dart
class DogdripListParser {
  static List<FeedItemDto> parse(String html) {
    if (html.isEmpty) return [];
    final doc = html_parser.parse(html);
    return doc.querySelectorAll(rowSelector)
        .map(parseRow)
        .whereType<FeedItemDto>()
        .toList();
  }
}
```

## DTO Rules

- DTOs live in `model/` with `_dto` suffix.
- Each DTO MUST have a `toEntity()` method returning the corresponding entity.
- DTOs `extends Equatable`.
- DTOs are the parsing boundary type (HTML ↔ typed data).

## Riverpod Provider Rules

- Providers call use cases, never repositories or datasources directly.
- Use `AsyncNotifierProvider` or `NotifierProvider` for state.
- Provider file names match the feature: `merged_feed_provider.dart`.
- Sole state holder — branch on UseCase results with `fold()`.

## Lint Rules

Base: `very_good_analysis` (see `analysis_options.yaml`).

Run `make fix` to auto-format and apply safe lint fixes.
