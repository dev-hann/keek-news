# 킥뉴스

한국 유머 커뮤니티 4곳의 웃긴자료 게시판을 하나의 피드로 모아보는 비공식
Flutter 모바일 앱입니다. 별도 백엔드 서버 없이, 각 커뮤니티의 모바일 페이지
HTML을 직접 가져와 디코딩(EUC-KR 포함)·파싱하여 하나의 시간순 피드로 보여줍니다.

## 지원 커뮤니티

| 커뮤니티 | 사이트 | 게시판 |
|----------|--------|--------|
| 웃긴대학 | [humoruniv.com](https://m.humoruniv.com) | 웃긴자료 (pds) |
| 오늘의유머 | [todayhumor.co.kr](https://www.todayhumor.co.kr) | 웃긴자료 |
| 개드립 | [dogdrip.net](https://www.dogdrip.net) | dogdrip |
| 뽐뿌 | [ppomppu.co.kr](https://www.ppomppu.co.kr) | 웃긴자료 (pds) |

각 커뮤니티 파서는 `lib/repository/<커뮤니티>/` 폴더에 독립적으로 존재합니다.

## 주요 기능

- **통합 피드**: 여러 커뮤니티의 게시물을 하나의 시간순 피드로 인스타그램 스타일 카드로 인라인 렌더링.
- **인라인 미디어**: 이미지 캐러셀, 전체화면 뷰어, 인카드 동영상 플레이어.
- **로컬 북마크**: SharedPreferences 기반 게시물 저장 (`저장함` 화면).
- **앱 자가 업데이트**: 설정 화면 진입 시 GitHub Releases를 확인, 새 버전이 있으면 APK를 다운로드해 시스템 설치터로 전달.
- **이미지 캐시 관리**: 캐시 용량 표시 및 수동 삭제.
- **당겨서 새로고침 / 무한 스크롤**: ID 기반 중복 제거로 안정적인 페이지네이션.
- **오프라인 대응**: 캐시된 콘텐츠를 우선 표시, 빈 화면 없음.
- **게시물 링크 복사**: 피드 카드에서 클립보드로 URL 복사.

## 작동 방식

백엔드 서버가 없습니다. Data 레이어가 커뮤니티별로 HTML을 가져와 EUC-KR을
UTF-8로 디코딩(해당 커뮤니티만)하고 DOM을 파싱해 구조화된 Dart 객체를
반환합니다. 나머지 앱은 이를 일반 API처럼 다룹니다. 아키텍처는
Service → Repository → UseCase → Provider 4계층으로 의존성 방향이 고정되어
있습니다. 자세한 규칙은 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)를
참고하세요.

## 기술 스택

- **Flutter 3.41** / Dart 3.11
- **flutter_riverpod** — 상태 관리
- **go_router** — 라우팅
- **get_it** — 의존성 주입
- **dio** — HTTP 클라이언트
- **html** — HTML DOM 파싱
- **charset_converter** — EUC-KR 디코딩 (네이티브)
- **dartz** — Either 기반 에러 처리
- **equatable** — 값 동등성 모델
- **cached_network_image** — 이미지 캐싱
- **video_player** — 인라인 동영상 재생
- **webview_flutter** — 임베디드 웹뷰
- **package_info_plus** / **url_launcher** / **path_provider** / **shared_preferences**
- **mocktail** — 테스트 목킹

## 다운로드

최신 릴리스 APK는 [GitHub Releases](https://github.com/dev-hann/happy-news/releases)에서
받을 수 있습니다. 앱 내 설정 화면에서도 자동으로 업데이트를 확인합니다.

## 시작하기

### 사전 요구사항

- Flutter 3.41+ (stable 채널)
- Dart 3.11+
- Android Studio(Android) 또는 Xcode(iOS)
- 에뮬레이터 또는 실기기

### 설치 및 실행

```bash
flutter pub get
flutter run
```

### 명령어 (Makefile)

| 명령어 | 설명 |
|--------|------|
| `make check` | 포맷 검사 + 정적 분석 + 테스트 (커밋 전 실행) |
| `make analyze` | 정적 분석만 |
| `make test` | 전체 테스트 |
| `make coverage` | 커버리지 리포트와 함께 테스트 |
| `make e2e` | E2E 테스트 (기기 필요) |
| `make smoke` | 스모크 테스트 — 실제 네트워크 (기기 + 인터넷 필요) |
| `make fix` | dart format + 린트 자동 수정 |
| `make clean` | 클린 및 의존성 재설치 |

## 빌드

```bash
flutter build apk --release       # Android APK
flutter build appbundle --release # Android App Bundle
flutter build ios --release       # iOS
```

릴리스 서명은 `android/key.properties`와 키스토어가 필요합니다.
자세한 건 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)를 참고하세요.

## 프로젝트 구조

```
lib/
├── const/        디자인 토큰, 테마
├── model/        엔티티 + 실패 (Equatable)
├── pages/        화면 (*_view.dart)
├── provider/     Riverpod 프로바이더
├── repository/   추상 (*_repo.dart) + 구현 (*_impl.dart), 커뮤니티별 그룹
├── service/      *_service.dart (추상) + <tech>_*_service.dart (구현) + DI
├── use_case/     비즈니스 연산 (*_use_case.dart)
├── utils/        순수 헬퍼
├── widgets/      재사용 UI
├── app.dart      KeekNewsApp + GoRouter
└── main.dart     진입점
```

## 문서

| 문서 | 설명 |
|------|------|
| [AGENTS.md](AGENTS.md) | AI 에이전트 규칙, 계층 접근 권한, 금지 행동 |
| [docs/PRODUCT_PLAN.md](docs/PRODUCT_PLAN.md) | 제품 정의, 페르소나, UX 스펙, 기능 로드맵 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 4계층 아키텍처 (Service → Repository → UseCase → Provider) |
| [docs/DESIGN.md](docs/DESIGN.md) | 디자인 시스템 규칙, 토큰, 컴포넌트, 접근성 |
| [docs/NAMING_CONVENTIONS.md](docs/NAMING_CONVENTIONS.md) | 파일/클래스 명명 규칙 (`*_repo`, `*_impl`, `*_use_case`, `*_view`) |
| [docs/CODE_STYLE.md](docs/CODE_STYLE.md) | Equatable 모델, dartz Either, 파서 패턴, 린트 |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | 환경 설정, 명령어, 빌드 방법 |
| [docs/TESTING_POLICY.md](docs/TESTING_POLICY.md) | 테스트 레벨, 픽스처 관리, 목킹 규칙 |

## 라이선스 / 면책

비공식 팬 프로젝트입니다. 모든 콘텐츠의 저작권은 각 커뮤니티와 작성자에게
있습니다. 본 앱은 콘텐츠를 수정하거나 생성하지 않으며, 기존 모바일 페이지를
더 나은 UX로 보여주는 뷰어 역할만 합니다.
