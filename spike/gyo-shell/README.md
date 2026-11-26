# gyo 셸 스파이크

keek-news를 "웹 앱 + WebView 셸"으로 옮기기 전에, 실기기에서만 확인되는 리스크를
가장 작은 비용으로 검증하는 일회용 프로젝트입니다. `lib/`과 `android/`는 제품 코드가
아니며, 결정이 끝나면 삭제합니다.

배경: keek-news는 백엔드 없이 기기가 커뮤니티 HTML을 직접 받습니다. 브라우저와
WebView는 CORS 때문에 다른 사이트를 직접 받을 수 없으므로, HTML은 셸이 대신 받아
전달(릴레이)해야 합니다. 미디어는 Referer를 보내지 않으면 CDN이 허용합니다.

`android/`는 gyo 저장소 `fix/shell-hardening` 브랜치의 CLI로 생성한 셸입니다. 그
브랜치를 머지하기 전에는, 거기서 빌드한 CLI로만 이 스파이크가 제대로 돌아갑니다.

## 확인하는 것

| 항목 | 질문 | 통과 기준 |
|---|---|---|
| A | 문서가 `no-referrer`일 때 WebView가 CDN 이미지를 직접 받는가 | 이미지 5개 이상, 4개 사이트 이상 |
| B | 셸의 릴레이가 헤더(UA·Referer)를 그대로 보내는가 | 6개 사이트 모두 200 |
| C | 웹이 받은 바이트를 직접 디코딩·파싱할 수 있는가 | 뽐뿌 EUC-KR 한글 정상, 웃대 게시글 10건 이상 |
| D | 큰 페이지의 릴레이 왕복이 견딜 만한가 | 사이트 응답 위에 0.5초 미만 |
| E | 동영상 재생·전체화면 | `play()`와 `requestFullscreen()`이 성공 |

대조(참고): 뽐뿌는 Referer 없이 요청하면 curl로는 403입니다(클라이언트에 따라
다름). 루리웹·네이트판n은 UA에 `wv`가 있으면 302로 돌려보냅니다. WebView가 직접
요청하면 이 조합들에서 막힙니다.

## 구성

- `lib/` — 의존성 없는 정적 페이지(`index.html`, `app.js`)와 대조용 문서
  (`control.html`), Node 내장 모듈만 쓰는 서버(`server.js`).
- `android/` — gyo 템플릿 그대로 + 릴레이 핸들러 `HttpBridge`와 그 등록 한 줄.
  템플릿을 손으로 고친 부분은 없습니다.
- `HttpBridge` — `http.request({ url, headers })` → OkHttp GET →
  `{ status, contentType, bodyBase64, elapsedMs }`. 바이트를 그대로 돌려주어 웹이
  디코딩과 파싱을 맡습니다. 사이트별 분기는 없습니다.
- 페이지는 `window.androidBridge`를 바로 씁니다. 셸이 페이지 로드 뒤에 주입하는
  `window.gyo`는 브리지 패키지가 쓰지 않으므로 기다리지 않습니다.

## 실행

### 폰

USB 디버깅으로 연결한 뒤:

```bash
cd ~/Documents/gyo && mise exec node@24 -- npm run build:cli   # fix/shell-hardening
cd ~/Documents/keek-news/spike/gyo-shell
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

## 스파이크로 발견한 gyo 문제

"고침"은 gyo의 `fix/shell-hardening` 브랜치에서를 뜻합니다.

| # | 문제 | 상태 |
|---|---|---|
| 1 | 디버그 빌드가 LAN 주소의 http를 열지 못해 실기기에서 `gyo run`이 페이지를 못 엽니다 | 고침. 디버그 빌드만 cleartext 허용 |
| 2 | 하이픈이 있는 프로젝트명이 무효한 패키지명(`com.example.gyo-shell`)을 만듭니다 | 고침. `com.example.gyo_shell` |
| 3 | `gyo.config.json`의 `webview` 설정을 셸이 읽지 않습니다 | 고침 |
| 4 | 페이지가 `window.gyo`가 생길 때까지 기다려야 한다고 봤습니다 | **내가 틀렸음.** `window.androidBridge`는 페이지 시작부터 있습니다 |
| 5 | `requestFullscreen()`이 "Fullscreen is not supported"로 거절됩니다 | 고침. `onShowCustomView` 구현 |
| 6 | `gyo run`이 실행될 때마다 LAN 주소를 `gyo.config.json`에 쓰고 생성물을 무시하지 않습니다 | 고침 |
| 7 | `gyo run`을 멈춘 뒤 개발 서버와 `adb logcat`이 남고, 포트가 묶인 채 재실행하면 "Local server running" 뒤에 서버만 죽습니다 | 고침. CLI를 실행한 프로세스가 사라지면 종료, 포트 사용 중이면 즉시 실패 |
| 8 | `gyo build`가 `lib/package.json`에 `build` 스크립트가 없으면 실패합니다. 셸은 그 산출물을 쓰지 않습니다 | 열림. 이 스파이크는 `gyo run`만 쓰므로 영향 없음 |
| 9 | 기기 E2E 테스트가 깨져 있어 기기가 있어도 전부 건너뛰었습니다 | 고침 |

## 결과

### Android WebView (에뮬레이터)

2026-11-26. `gyo run`으로 네이티브 브리지를 거쳐 실행했습니다. Android 14 (API 34),
WebView Chromium 113입니다. 폰이 아니라 에뮬레이터이고, 이 에뮬레이터는 `screencap`이
검은 화면만 돌려주어 실제 화면이 그대로 그려지는지는 확인하지 못했습니다. 결과는
CDP로 페이지에서 직접 읽었습니다.

첫 실행은 수정 전 템플릿에 손으로 우회한 것으로 돌려 E의 전체화면이 실패했고, 그
결과로 gyo를 고쳤습니다. 아래는 이 저장소의 스파이크 그대로 다시 돌린 결과입니다.

- **A PASS** — 이미지 9/9, 6개 사이트가 WebView에서 직접 로드되었습니다.
  대조: 같은 이미지를 공개 주소 Referer로 요청하면 403, Referer 없이는 200.
  사설 IP Referer(`http://192.168.x.x`)는 CDN이 허용합니다.
- **B PASS** — 6개 사이트 모두 200 (네이티브 요청 296~656 ms). 대조: WebView의 UA로
  루리웹·네이트판n을 요청하면 302.
- **C PASS** — 뽐뿌 한글 987자, 깨진 문자 0, 제목 30개. 웃대 게시글 20건.
- **D PASS** — 웃대 상세 115KB: 사이트 응답 224 ms, 릴레이 오버헤드 21 ms,
  최대 프레임 간격 17 ms.
- **E PASS** — `play()` 성공, `requestFullscreen()` 성공.

추가로, 서명하고 R8로 축소한 릴리스 빌드에서도 브리지가 동작했습니다(릴레이 로그로
확인). 단, 릴리스는 cleartext를 막으므로 `http://` 개발 서버 주소로는 페이지가
열리지 않습니다. 에뮬레이터에서는 `adb reverse tcp:3000 tcp:3000`과
`localhost` 프로필로 우회해 확인했습니다.

### 데스크톱 (헤드리스 Chromium, WebView UA, 개발용 릴레이)

2026-11-26. 네이티브 브리지가 아니므로 참고용입니다. A·B·C·D 모두 PASS.
D는 사이트 응답 1799 ms, 릴레이 오버헤드 3 ms.

### 폰에서 남은 확인

- 화면이 실제로 그려지는지. 에뮬레이터에서는 캡처가 되지 않았습니다.
- E의 재생·전체화면 버튼을 손으로 눌러서. 에뮬레이터에서는 CDP의 사용자 제스처
  시뮬레이션으로만 확인했습니다.
