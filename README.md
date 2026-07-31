# 킥뉴스

A multi-community Korean humor feed aggregator. No backend server — the app
fetches HTML directly from each community's mobile site, decodes the encoding
(EUC-KR where needed), parses the DOM, and renders a single merged feed.

## Supported Communities

| Community | Site | Board |
|-----------|------|-------|
| 웃긴대학 | [humoruniv.com](https://m.humoruniv.com) | 웃긴자료 (pds) |
| 오늘의유머 | [todayhumor.co.kr](https://www.todayhumor.co.kr) | 웃긴자료 |
| DogDrip | [dogdrip.net](https://www.dogdrip.net) | dogdrip |
| 뽐뿌 | [ppomppu.co.kr](https://www.ppomppu.co.kr) | 웃긴자료 (pds) |

## How It Works

There is no backend. The Data layer fetches HTML per community, decodes EUC-KR
to UTF-8 (where applicable), parses the DOM, and returns structured Dart
objects. The rest of the app treats it like a normal API. Each community has
its own parser under `lib/repository/<community>/`.

## Features

- Merged chronological feed across all communities, Instagram-style inline cards.
- Inline media: image carousel, fullscreen viewer, inline video player.
- Local bookmarks (SharedPreferences).
- In-app self-update: checks GitHub Releases on settings entry, downloads the
  APK and hands off to the system installer.
- Image cache with manual clearing.
- Pull-to-refresh and infinite scroll.
- Offline resilience with cached content.

## Tech Stack

- **Flutter 3.41** / Dart 3.11
- **flutter_riverpod** — state management
- **go_router** — navigation
- **get_it** — dependency injection
- **dio** — HTTP client
- **html** — HTML DOM parsing
- **charset_converter** — EUC-KR decoding
- **dartz** — Either-based error handling
- **equatable** — value-equality models
- **cached_network_image** — image caching
- **video_player** — inline video playback
- **webview_flutter** — embedded web views
- **package_info_plus** / **url_launcher** / **path_provider** / **shared_preferences**
- **mocktail** — test mocking

## Quick Start

```bash
flutter pub get
flutter run
```

Commands (via Makefile):

| Command | Description |
|---------|-------------|
| `make check` | format check + analyze + test (run before commit) |
| `make analyze` | lint check only |
| `make test` | all tests |
| `make coverage` | tests with coverage report |
| `make e2e` | E2E tests (needs device) |
| `make smoke` | smoke tests — real network (needs device + internet) |
| `make fix` | dart format + auto-fix lint |
| `make clean` | clean and re-fetch dependencies |

For detailed setup, see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Documentation

| Document | Description |
|----------|-------------|
| [AGENTS.md](AGENTS.md) | AI agent rules, layer access rules, prohibited actions |
| [docs/PRODUCT_PLAN.md](docs/PRODUCT_PLAN.md) | Product definition, personas, UX specs, feature roadmap |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 4-layer architecture (Service → Repository → UseCase → Provider) |
| [docs/DESIGN.md](docs/DESIGN.md) | Design system rules, tokens, components, accessibility |
| [docs/NAMING_CONVENTIONS.md](docs/NAMING_CONVENTIONS.md) | File and class naming (`*_repo`, `*_impl`, `*_use_case`, `*_view`) |
| [docs/CODE_STYLE.md](docs/CODE_STYLE.md) | Equatable models, dartz Either, parser patterns, lint |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Environment setup, commands, build instructions |
| [docs/TESTING_POLICY.md](docs/TESTING_POLICY.md) | Test levels, fixture management, mock conventions |

## License

Unofficial fan project. All content belongs to the respective communities and
their users.
