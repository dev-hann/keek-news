# keek-news 웹 앱

Android 셸(`../shell`)이 보여 주는 웹 앱이다. React + Vite + TypeScript.

## 구조

- `src/service/` — 페이지 가져오기 계층. Flutter 앱 `lib/service/`의 옮긴 것이다.
  - `html_client.ts`: 사이트 페이지를 네이티브 릴레이로 받아 디코딩한다. 503과 네트워크 오류는
    재시도하고, 실패는 진단을 담은 `ServerFailure` 또는 `NetworkFailure`로 돌려준다.
  - `service_locator.ts`: 커뮤니티별 요청 설정(주소·헤더·인코딩·쿠키 jar).
- `src/model/` — 도메인 타입.
- `src/pages/` — 화면. 지금은 릴레이 검사(`relay_check_view.tsx`) 하나다.
- `dev/relay-check-server.ts` — `vite dev`에서만 켜지는 검사용 엔드포인트.
- `test/` — `src/`와 같은 구조의 Vitest 테스트.

## 명령

```bash
npm install
npm run dev   # 개발 서버, 포트 3000, 같은 네트워크의 기기에서 접근할 수 있다
npm run check # lint + 형식 + 타입 + 테스트 + 빌드. 커밋 전에 `make check-web`으로 돈다
```

## 릴레이 검사

`/`를 열면 릴레이 검사가 바로 돈다: 리다이렉트 추적, jar별 쿠키, 재시작 후 쿠키 유지, 거절 응답의
상태·헤더, 네트워크 실패 분류, 1500 KB와 4000 KB 본문, 커뮤니티 목록 7개. 결과는 화면과
`node_modules/.vite/relay-check-report.json`에 남는다.

"cookies survive a restart"는 앱을 재시작한 뒤 다시 열어야 PASS가 된다. 처음에는 PENDING이다.

## gyo 플러그인 연결

`@gyo-framework/http`와 `@gyo-framework/bridge`는 형제 저장소 `../../gyo/plugins/`에서 가져온다.
`.npmrc`의 `install-links=true` 때문에 심링크가 아니라 **복사본**으로 설치된다. gyo가 심링크로
연결된 플러그인은 찾지 못하기 때문이다.

복사본이므로 플러그인 소스를 고친 뒤에는 패키지 이름을 지정해 다시 설치해야 반영된다. 이름 없는
`npm install`은 그대로 둔다.

```bash
npm install @gyo-framework/http@file:../../gyo/plugins/http
```

플러그인이 npm에 올라가면 버전 범위로 바꾸고, 이 절차는 없어진다.
