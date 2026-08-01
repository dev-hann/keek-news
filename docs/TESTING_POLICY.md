# Testing Policy

Write tests for all new logic. See [AGENTS.md](../AGENTS.md) for workflow rules.

## Core Rule

Every implementation step should be followed by `flutter test`. Write a test, see it fail, implement, see it pass, refactor. For trivial data classes (entities, failures) writing the test alongside the code is acceptable.

Run `make check` before committing — the husky pre-commit hook enforces `dart format` + `flutter analyze` + `flutter test` with zero errors.

## TDD Cycle (recommended for logic)

1. **RED** — Write a failing test. Run it. Confirm it fails.
2. **GREEN** — Write the minimum implementation to pass. Run it. Confirm it passes.
3. **REFACTOR** — Clean up. Run tests again. All still pass.

Parser methods, state management, and business rules benefit most from strict per-case RED→GREEN. Data classes and interfaces do not require RED verification.

## Testing Priority

| Priority | Layer | Reason |
|----------|-------|--------|
| 1 | **UseCase** | Business logic focused, purely functional |
| 2 | **Repository** | Service composition logic |
| 3 | **Model** | Serialization, value equality (Equatable) |
| 4 | **Parser** | HTML → DTO, many edge cases |
| 5 | **Provider** | State management wiring |
| 6 | **Widget / Screen** | UI rendering, interaction |

## Test Directory Structure

Mirror the `lib/` structure:

```
test/
├── fixtures/<community>/   HTML samples
├── helpers/                shared test helpers
├── unit/
│   ├── const/              theme token tests
│   ├── model/              entity, DTO, failure tests
│   ├── pages/              view logic tests
│   ├── provider/           Riverpod provider tests
│   ├── repository/         *_impl_test.dart
│   ├── service/            datasource, adapter, network tests
│   │   └── parser/         HTML parser tests
│   ├── use_case/           *_use_case_test.dart
│   ├── utils/              pure helper tests
│   ├── widgets/            reusable widget tests
│   └── app_test.dart       app/router tests
├── widget/
│   ├── pages/              *_view_test.dart
│   └── widgets/
├── integration/
└── smoke/
```

## Test Levels

### 1. Unit Tests (`test/unit/`)

Isolated tests with dependencies mocked via `mocktail`.

| Target | What to test | Mock |
|--------|-------------|------|
| Entity / DTO | Equatable value equality, `toEntity()` | None |
| Parser | HTML string → DTO | None (pure function) |
| UseCase | Business logic, Either result | Repository |
| Datasource / Adapter | Correct parser called, error handling | HtmlClient |
| Repository impl | Mapping | Datasource |
| Provider | State management, async flow | Repository via DI |
| Widget | Rendering, interaction | Provider overrides |

Parser test pattern:
```dart
test('should return list of feed items when html contains valid rows', () {
  final html = File('test/fixtures/dogdrip/list.html').readAsStringSync();
  final result = DogdripListParser.parse(html);
  expect(result, isNotEmpty);
  expect(result.first.title, isNotEmpty);
});
```

Widget test pattern:
```dart
testWidgets('should display feed titles when data loads', (tester) async {
  when(() => mockRepo.getMergedFeed())
      .thenAnswer((_) async => Right(feed));

  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: HomeView())),
  );
  await tester.pumpAndSettle();

  expect(find.text('First Post'), findsOneWidget);
});
```

### 2. Widget Tests (`test/widget/`)

Test complete screens in isolation using `WidgetTester`. Use `ProviderScope` overrides or DI mock injection.

### 3. Integration Tests (`test/integration/`)

Wire multiple real layers together with only the external boundary mocked (real parsers + mock HtmlClient returning fixture HTML).

### 4. E2E Tests (`integration_test/`)

Full app tests on a device/emulator. Use Provider overrides to inject deterministic fake data — no real network calls.

### 5. Smoke Tests (`test/smoke/`)

Real network tests verifying parsers against live servers. Guarded by `SMOKE=1` env var (skipped by default). Run: `SMOKE=1 flutter test test/smoke/`.

## Fixture Management

- Store HTML samples in `test/fixtures/<community>/`.
- Naming: `{page_type}[_{variant}].html`
- Each parser MUST have at least one corresponding fixture.
- Commit fixtures to the repository.

## Mock Conventions

Use `mocktail`.

```dart
class MockMergedFeedRepo extends Mock implements MergedFeedRepo {}

// setUp
registerFallbackValue(CommunityId.dogdrip);

// test
when(() => mockRepo.getMergedFeed())
    .thenAnswer((_) async => Right([testFeedItem]));
```

- One mock class per test file or shared in `test/helpers/`.
- Use `registerFallbackValue` for any `any()` matcher.
- Provider tests inject mocks via `di.sl` (GetIt) with `setUp`/`tearDown` registration.

## Parser Resilience Testing

Every parser MUST be tested against:

| Case | Expected behavior |
|------|-------------------|
| Valid HTML | Returns correctly populated DTOs |
| Empty string | Returns empty list or default DTO. No crash. |
| Missing required elements | Returns empty/default. No crash. |
| Malformed structure | Returns partial results or default. No crash. |

Parsers MUST never throw — always return a valid result.

## Test Anti-Patterns

- **Mock echo**: Asserting the exact value set up in `when(...)`. Tests the mock.
- **No assertions**: A test without `expect`.
- **Tautology**: Asserting always-true conditions.
- **Code duplication**: Copying implementation logic into test code.
- **Testing private members**: Only test public API behavior.

## Commands

| Command | Purpose |
|---------|---------|
| `flutter test` | Run all tests (smoke skipped) |
| `SMOKE=1 flutter test` | All tests including smoke |
| `SMOKE=1 flutter test test/smoke/` | Only smoke tests |
| `flutter test test/unit/` | Only unit tests |
| `flutter test test/widget/` | Only widget tests |
| `flutter test test/integration/` | Only integration tests |
| `flutter test integration_test/` | E2E (requires device) |
| `flutter analyze` | Static analysis (0 errors required) |
