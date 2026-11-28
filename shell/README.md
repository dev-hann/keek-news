# keek-news 웹 셸

웹 앱(`../web`)을 Android WebView에 담는 gyo 프로젝트다. `lib/`는 `../web`으로 향한
심링크다. Flutter 앱이 저장소 루트를 차지하고 있어 gyo 관례(루트에 `lib/`)를 쓸 수
없어 `shell/`에 있다. 마이그레이션이 끝나면 루트로 올린다.

## 실행

폰을 USB 또는 무선 디버깅으로 연결한 뒤:

```bash
cd shell
mise exec node@24 -- node ~/Documents/gyo/cli/dist/index.js run
```

`web`의 개발 서버(`vite dev`, 포트 3000)를 띄우고 디버그 APK를 빌드해 설치하고
실행한다. 멈추려면 `Ctrl+C`.

빌드에는 Node 24, JDK 17, SDK platform 36이 필요하다. `gyo doctor`로 확인할 수 있다.

`development` 프로필의 `serverUrl`은 이 PC의 Tailscale 주소(`100.71.158.16`)다. 폰이 어느
네트워크에 있어도 개발 서버에 닿게 하기 위해서라서, 폰도 Tailscale에 연결돼 있어야 한다. 같은
와이파이에서만 쓴다면 `http://localhost:3000`으로 두면 gyo가 PC의 LAN 주소를 찾아 쓴다.

### 서버를 따로 띄워 두고 셸만 설치하기

`gyo run`이 띄운 서버는 그 `gyo run`과 함께 죽는다. 서버를 오래 살려 두려면 따로 띄우고
`standalone` 프로필로 셸만 빌드해 설치한다. `gyo run`이 서버를 직접 띄우는 것은
`development` 프로필일 때뿐이다.

```bash
cd ../web && setsid nohup npx vite > /tmp/opencode/vite.log 2>&1 &
cd ../shell && ANDROID_SERIAL=emulator-5554 mise exec node@24 -- \
  node ~/Documents/gyo/cli/dist/index.js run -p standalone -d emulator-5554
```

`-d`는 *실행*과 로그가 갈 기기만 고른다. 설치(`installDebug`)는 연결된 모든 기기에 가므로,
폰을 건드리지 않으려면 `ANDROID_SERIAL`로 한 기기를 정한다.

## 플러그인

gyo 플러그인은 npm에서 받는다(`web/package.json`의 `@gyo-community/http`, `@gyo-community/media`).
플러그인의 `android/`는 Gradle 라이브러리 모듈이라서, `gyo run`·`gyo build`·`gyo install`은 그
모듈을 앱 빌드에 포함하고 등록 코드를 만든다. 소스를 앱으로 복사하지는 않으므로 플러그인을
바꾸면 빌드에 바로 반영된다. 플러그인을 추가한 뒤에는 셸을 다시 빌드해야 한다.

- 커밋되는 것: `android/gyo.settings.gradle`, `android/app/gyo.build.gradle`,
  `android/app/src/main/java/gyo/plugins/bridge/PluginRegistry.kt`. 셋 다 gyo가 다시 쓴다.
- 커밋되지 않는 것: `.gyo-plugins`(마지막 동기화 기록), `gyo-config.json`,
  `local.properties`.

권한은 앱의 매니페스트에 직접 적는다(`android/app/src/main/AndroidManifest.xml`). gyo는
플러그인이 요구하는 권한이 거기 있는지만 살펴보고 없으면 경고한다. 갤러리 저장이 쓰는
`WRITE_EXTERNAL_STORAGE`는 Android 9 이하에서만 필요하므로 `maxSdkVersion="28"`과 함께 있다.

## 패키지 이름

개발용은 `com.keek_news.app.webdev`다. 정식 앱(`com.keek_news.app`)과 같은 폰에 나란히
설치되도록 분리해 두었으며, 정식으로 전환할 때 바꾼다.

이 이름은 세 곳에 있다: `android/app/build.gradle`의 `namespace`와 `applicationId`, 그리고
`MainActivity.kt`의 패키지(`android/app/src/main/java/com/keek_news/app/webdev/`). 셋이 같아야
한다. gyo가 앱을 `<applicationId>/.MainActivity`로 실행하기 때문이다.

`gyo.config.json`의 `packageName`은 `gyo create`가 프로젝트를 만들 때만 쓰이고 `gyo run`·
`gyo build`는 다시 적용하지 않는다. 그래서 셸을 새 템플릿으로 다시 만들 때는 위 세 곳을
직접 맞춰야 한다.
