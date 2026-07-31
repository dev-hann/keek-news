# Development

Environment setup and commands.

## Prerequisites

- Flutter 3.41+ (stable channel)
- Dart 3.11+
- Android Studio (for Android) or Xcode (for iOS)
- An emulator or physical device

## Setup

```bash
flutter pub get
```

## Run

```bash
flutter run
```

## Test

```bash
flutter test                    # All tests in test/
flutter test integration_test/  # E2E (needs device/emulator)
```

For detailed test commands and coverage, see [TESTING_POLICY.md](TESTING_POLICY.md).

## Analyze

```bash
flutter analyze
```

Must pass with zero issues before committing.

## Build

```bash
flutter build apk --release       # Android APK
flutter build appbundle --release # Android App Bundle
flutter build ios --release       # iOS
```

## Project Structure

```
lib/
├── const/        design tokens, theme
├── model/        entities + failures (Equatable)
├── pages/        screens (*_view.dart)
├── provider/     Riverpod providers
├── repository/   abstract (*_repo.dart) + impl (*_impl.dart), community-grouped
├── service/      *_service.dart (abstract) + <tech>_*_service.dart (concrete) + DI
├── use_case/     business operations (*_use_case.dart)
├── utils/        pure helpers
├── widgets/      reusable UI
├── app.dart      KeekNewsApp + GoRouter
└── main.dart     entry
```

For architecture details, see [ARCHITECTURE.md](ARCHITECTURE.md).
For naming rules, see [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md).
For coding style, see [CODE_STYLE.md](CODE_STYLE.md).
For testing, see [TESTING_POLICY.md](TESTING_POLICY.md).
