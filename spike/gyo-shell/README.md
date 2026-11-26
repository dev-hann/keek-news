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

- `lib/` — 의존성 없는 정적 페이지(`index.html`, `app.js`)와 대조용 문서
  (`control.html`), Node 내장 모듈만 쓰는 서버(`server.js`).
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

### 에뮬레이터 (이 머신)

USB 디버깅 폰 대신 에뮬레이터로 돌릴 수 있습니다. 결과는 CDP로 읽습니다. 이
에뮬레이터(ATD 이미지, `-no-window`)는 `adb screencap`이 검은 화면만 돌려주므로
화면 캡처는 되지 않습니다.

```bash
SDK=$HOME/development/android-sdk
$SDK/emulator/emulator -avd gyo-spike -no-window -no-audio -no-boot-anim \
  -gpu swiftshader_indirect -no-snapshot -memory 2048 &
adb wait-for-device   # 부팅까지 기다리기
cd spike/gyo-shell && mise exec node@24 -- node ~/Documents/gyo/cli/dist/index.js run &
sock=$(adb shell cat /proc/net/unix | tr -d '\r' | grep -o 'webview_devtools_remote_[0-9]*')
adb forward tcp:9222 "localabstract:$sock"
curl -s localhost:9222/json   # 페이지 타깃의 webSocketDebuggerUrl로 CDP 접속
```

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
5. **전체화면이 안 됩니다.** `MainActivity`에 `onShowCustomView`가 없어서
   `requestFullscreen()`이 "Fullscreen is not supported"로 거절됩니다.
6. **`gyo run`이 실행될 때마다 작업 트리를 더럽힙니다.** 감지한 LAN URL을 추적 중인
   `gyo.config.json`에 쓰고, `android/app/src/main/assets/gyo-config.json`을 만듭니다.
   둘 다 이 머신 전용 값이라 여기서는 되돌리거나 무시합니다.
7. **`gyo run`이 남기는 것들.** 종료해도 개발 서버와 `adb logcat`이 남습니다. 포트가
   아직 점유된 채 다시 실행하면 "Local server running"까지 출력한 뒤 서버만
   `EADDRINUSE`로 죽고, 앱은 그대로 설치되어 "Webpage not available"이 뜹니다.

## 결과

### Android WebView (에뮬레이터)

2026-11-26. `gyo run`으로 네이티브 브리지를 거쳐 실행했습니다. Android 14 (API 34),
WebView Chromium 113입니다. 폰이 아니라 에뮬레이터이고, 이 에뮬레이터는 `screencap`이
검은 화면만 돌려주어 실제 화면이 그려지는지는 확인하지 못했습니다. 결과는 CDP로
페이지에서 직접 읽었습니다.

- **A PASS** — 이미지 9/9, 6개 사이트가 WebView에서 직접 로드되었습니다.
  대조: 같은 이미지를 공개 주소 Referer로 요청하면 403, Referer 없이는 200.
  사설 IP Referer(`http://192.168.x.x`)는 CDN이 허용합니다.
- **B PASS** — 6개 사이트 모두 200 (네이티브 요청 58~659 ms). 대조: WebView의 UA로
  루리웹·네이트판n을 요청하면 302.
- **C PASS** — 뽐뿌 한글 997자, 깨진 문자 0, 제목 30개. 웃대 게시글 20건.
- **D PASS** — 웃대 상세 146KB: 사이트 응답 113~132 ms, 릴레이 오버헤드 13~38 ms,
  최대 프레임 간격 17 ms.
- **E** — 인라인 재생은 동작합니다(`play()` 성공). 전체화면은
  "Fullscreen is not supported"로 실패합니다. 셸에 전체화면 콜백이 없습니다.

### 데스크톱 (헤드리스 Chromium, WebView UA, 개발용 릴레이)

같은 날. 네이티브 브리지가 아니므로 참고용입니다. A·B·C·D 모두 PASS.
D는 사이트 응답 1799 ms, 릴레이 오버헤드 3 ms.

### 폰에서 남은 확인

- 화면이 실제로 그려지는지. 에뮬레이터에서는 캡처가 되지 않았습니다.
- E의 재생·전체화면 버튼을 손으로 눌러서.
