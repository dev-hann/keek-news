# keek-news 웹 앱

Android 셸(`../shell`)이 보여 주는 웹 앱이다. React + Vite + TypeScript.

## 구조

- `src/service/` — 페이지 가져오기 계층. Flutter 앱 `lib/service/`의 옮긴 것이다.
  - `html_client.ts`: 사이트 페이지를 네이티브 릴레이로 받아 디코딩한다. 503과 네트워크 오류는
    재시도하고, 실패는 진단을 담은 `ServerFailure` 또는 `NetworkFailure`로 돌려준다.
  - `service_locator.ts`: 커뮤니티별 요청 설정(주소·헤더·인코딩·쿠키 jar).
- `src/model/` — 도메인 타입.
- `src/pages/` — 화면: 홈(`/`), 설정(`/settings`), 저장함(`/bookmarks`), 차단 이미지(`/blocked-images`),
  릴레이 검사(`/relay-check`).
- `dev/relay-check-server.ts` — `vite dev`에서만 켜지는 검사용 엔드포인트.
- `test/` — `src/`와 같은 구조의 Vitest 테스트.

## 명령

```bash
npm install
npm run dev   # 개발 서버, 포트 3000, 같은 네트워크의 기기에서 접근할 수 있다
npm run check # lint + 형식 + 타입 + 테스트 + 빌드. 커밋 전에 `make check-web`으로 돈다
```

## 배포

서버 코드가 없는 정적 사이트다. Cloudflare의 Worker 하나가 빌드 파일을 그대로 들고 있고 코드는
실행하지 않는다(`wrangler.jsonc`: `dist/`만, 없는 경로에는 `index.html`). 커뮤니티 페이지는 셸의
네이티브 릴레이가 받으므로 웹 앱 쪽에는 서버가 필요 없다.

```bash
npx wrangler login    # 처음 한 번. 브라우저를 자동으로 열 수 없는 환경이면 `--device`
npm run build && npx wrangler deploy
```

주소는 https://keek-news.notion-blog-proxy.workers.dev 이고, 셸의 `standalone` 프로필이 이 주소를
연다. `master`에 `web/` 변경이 올라오면 GitHub Actions(`deploy-web.yml`)이 이 절차를 밟는다. 파일은
항상 재검증되므로(`max-age=0`) 다시 배포하면 바로 보인다.

## 릴레이 검사

`/relay-check`를 열면 릴레이 검사가 바로 돈다: 리다이렉트 추적, jar별 쿠키, 재시작 후 쿠키 유지, 거절 응답의
상태·헤더, 네트워크 실패 분류, 1500 KB와 4000 KB 본문, 커뮤니티 목록 7개. 결과는 화면과
`node_modules/.vite/relay-check-report.json`에 남는다.

"cookies survive a restart"는 앱을 재시작한 뒤 다시 열어야 PASS가 된다. 처음에는 PENDING이다.

## gyo 플러그인

페이지는 `@gyo-community/http`(npm)로 받는다. 이 플러그인의 peer 의존성인 `@gyo-framework/bridge`는
npm이 함께 설치한다. 플러그인을 더 쓰게 되면 여기서 설치하고, 셸이 빌드 전에 Android 모듈을
포함한다(`shell/README.md` 참고).
