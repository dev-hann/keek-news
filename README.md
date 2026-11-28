# 킥뉴스

웃긴대학 웃긴자료 게시판을 보는 비공식 Android 앱이다. 웹 앱(`web/`, React + Vite + TypeScript)을
gyo WebView 셸(`shell/`)이 보여 준다. 백엔드는 없다: 커뮤니티 페이지는 셸의 네이티브 릴레이가
기기에서 직접 받는다.

2026-11-28까지 이 저장소는 Flutter 앱이었다. 마지막 Flutter 버전은 태그 `v3.14.3`에 있다.

## 구조

| 경로     | 내용                                                                                            |
|--------|-----------------------------------------------------------------------------------------------|
| `web/` | 웹 앱. 화면·데이터층·테스트. [`web/README.md`](web/README.md)                                           |
| `shell/` | Android 셸(gyo). [`shell/README.md`](shell/README.md)                                           |
| `docs/` | 제품 계획(`PRODUCT_PLAN.md`), 디자인(`DESIGN.md`), 개발 규칙. [`AGENTS.md`](AGENTS.md)가 색인이다. |

## 개발

```bash
npm install --prefix web   # 처음 한 번
make check                 # lint + 형식 + 타입 + 테스트 + 빌드. 커밋·푸시 전에 훅이 돈다
```

## 배포

- **웹 앱**: `master`에 `web/` 변경이 올라오면 GitHub Actions(`deploy-web.yml`)이 Cloudflare에
  배포한다. 주소는 <https://keek-news.notion-blog-proxy.workers.dev>이다. 앱이 그 주소를 열므로,
  웹 변경은 앱을 다시 설치하지 않아도 반영된다.
- **앱**: `shell/`이나 gyo 플러그인이 바뀌면 GitHub Actions(`build-shell.yml`)이 릴리스 키로 서명한
  APK를 빌드해 본다(릴리스는 하지 않는다). `v<버전>` 태그를 밀면 그 태그의 Release로 APK를 올린다.
  버전은 `shell/gyo.config.json`의 `version`·`versionCode`다. 릴리즈 노트는 `RELEASE_NOTES.md`의
  `## v<버전>` 절이고, 그 절이 없는 태그는 릴리즈되지 않는다. 웹 앱을 손으로 배포하는 법은
  `web/README.md`의 배포.
