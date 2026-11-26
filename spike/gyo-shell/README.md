# gyo 셸 스파이크

keek-news를 "웹 앱 + WebView 셸"으로 옮기기 전에, 실기기에서만 확인되는 리스크를
가장 작은 비용으로 검증하는 일회용 프로젝트입니다. `lib/`과 `android/`는 제품 코드가
아니며, 결정이 끝나면 삭제합니다.

배경: keek-news는 백엔드 없이 기기가 커뮤니티 HTML을 직접 받습니다. 브라우저와
WebView는 CORS 때문에 다른 사이트를 직접 받을 수 없으므로, HTML은 셸이 대신 받아
전달(릴레이)해야 합니다. 미디어는 Referer를 보내지 않으면 CDN이 허용합니다.

## 확인하는 것

| 항목 | 질문 | 통과 기준 |
|---|---|---|
| A | 문서가 `no-referrer`일 때 WebView가 CDN 이미지를 직접 받는가 | 이미지 5개 이상, 4개 사이트 이상 |
| B | 셸의 릴레이가 헤더(UA·Referer)를 그대로 보내는가 | 6개 사이트 모두 200 |
| C | 웹이 받은 바이트를 직접 디코딩·파싱할 수 있는가 | 뽐뿌 EUC-KR 한글 정상, 웃대 게시글 10건 이상 |
| D | 큰 페이지의 릴레이 왕복이 견딜 만한가 | 사이트 응답 위에 0.5초 미만 |
| E | 동영상 재생·전체화면 | 직접 눌러서 확인 |

대조(참고): 뽐뿌는 Referer 없이 요청하면 curl로는 403입니다(클라이언트에 따라
다름). 루리웹·네이트판n은 UA에 `wv`가 있으면 302로 돌려보냅니다. WebView가 직접
요청하면 이 조합들에서 막힙니다.

## 구성

- `lib/` — 의존성 없는 정적 페이지(`index.html`, `app.js`)와 Node 내장 모듈만 쓰는
  서버(`server.js`).
- `android/` — gyo 템플릿 + 릴레이 핸들러 `HttpBridge` + 디버그 전용 cleartext 설정.
- `HttpBridge` — `http.request({ url, headers })` → OkHttp GET →
  `{ status, contentType, bodyBase64, elapsedMs }`. 바이트를 그대로 돌려주어 웹이
  디코딩과 파싱을 맡습니다. 사이트별 분기는 없습니다.

## 실행

### 폰

USB 디버깅으로 연결한 뒤:

```bash
cd spike/gyo-shell
mise exec node@24 -- node ~/Documents/gyo/cli/dist/index.js run
```

`gyo run`이 개발 서버 → LAN URL → 디버그 빌드 → 설치 → 실행까지 잇습니다. 폰과
PC가 같은 네트워크에 있어야 합니다. gyo CLI는 전역 설치하지 않고 저장소의 빌드물을
씁니다.

### 데스크톱 (네이티브 브리지 없이 페이지 로직만)

```bash
cd spike/gyo-shell/lib
SPIKE_DEV_RELAY=1 node server.js     # http://localhost:3000
```

`/__relay`는 `HttpBridge`와 같은 계약의 개발용 릴레이입니다. 스파이크 밖에서는
켜지 마세요. 헤드리스 Chromium의 기본 UA(`HeadlessChrome`)는 커뮤니티 CDN에 봇으로
차단되니, 실제 기기의 UA를 덮어써서 열어야 합니다.

## 스파이크 중 발견한 gyo 문제

1. **실기기에서 `gyo run`이 페이지를 못 엽니다.** 템플릿의
   `network_security_config.xml`이 cleartext를 `localhost`·`10.0.2.2`만 허용하는데,
   실기기는 PC의 LAN IP(`http://192.168.x.x:3000`)로 받습니다. 여기서는 디버그
   소스 세트에 cleartext를 허용하는 설정을 덮어썼습니다.
2. **하이픈이 있는 프로젝트명은 무효한 패키지명을 만듭니다.** `gyo create gyo-shell`은
   `gyo.config.json`에 `com.example.gyo-shell`을 쓰지만 코드는 `com.example.gyoshell`
   입니다. 여기서는 설정을 고쳤습니다.
3. **`webview` 설정이 적용되지 않습니다.** `gyo.config.json`의 `userAgent`·
   `allowFileAccess`는 셸 코드가 읽지 않습니다.
4. **브리지 런타임이 페이지 로드 뒤에 주입됩니다.** 페이지 스크립트는
   `window.gyo`가 생길 때까지 기다려야 합니다(`app.js`의 `waitForNativeBridge`).

## 결과

### 데스크톱 (헤드리스 Chromium, WebView UA, 개발용 릴레이)

2026-11-26. 네이티브 브리지가 아니므로 참고용입니다.

- A PASS — 이미지 9/9, 6개 사이트.
- B PASS — 6개 사이트 모두 200. 대조: 루리웹·네이트판n은 WebView UA로 302.
- C PASS — 뽐뿌 한글 986자, 깨진 문자 0, 제목 30개. 웃대 게시글 20건.
- D PASS — 사이트 응답 1799 ms, 릴레이 오버헤드 3 ms, 최대 프레임 간격 17 ms.

### Android WebView

(기기 실행 뒤 채움)
