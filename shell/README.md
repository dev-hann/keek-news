# keek-news Android 셸

웹 앱(`../web`)을 Android WebView에 담는 gyo 프로젝트다. `lib/`는 `../web`으로 향한
심링크다. 저장소 루트를 문서와 도구가 차지하고 있어 `shell/`에 있다.

## 실행

폰을 USB 또는 무선 디버깅으로 연결한 뒤:

```bash
cd shell
mise exec node@24 -- node ~/Documents/gyo/cli/dist/index.js run
```

`web`의 개발 서버(`vite dev`, 포트 3000)를 띄우고 디버그 APK를 빌드해 설치하고
실행한다. 멈추려면 `Ctrl+C`.

빌드에는 Node 24, JDK 17, SDK platform 36이 필요하다. `gyo doctor`로 확인할 수 있다.

### 프로필

`gyo.config.json`의 `profiles`가 셸이 열 주소이고, `-p <프로필>`로 고른다. gyo가 빌드 때 그 주소를
`gyo-config.json`에 구워 넣는다.

| 프로필 | 주소 | 쓸 때 |
|---|---|---|
| `development` (기본) | `http://localhost:3000` | `gyo run`이 개발 서버를 직접 띄운다. localhost는 빌드 때 이 PC의 LAN 주소로 바뀐다. |
| `dev-server` | `http://localhost:3000` | 개발 서버가 이미 떠 있고 셸만 설치한다. |
| `standalone` | 배포된 웹 앱 | PC도 개발 서버도 없이 앱을 받아 본다. 릴리즈 빌드도 이 프로필이다. |

폰이 어느 네트워크에서도 개발 서버에 닿게 하려면 `development`·`dev-server`의 주소를 이 PC의
Tailscale 주소로 바꾸면 된다(폰도 Tailscale에 연결돼 있어야 한다). 그 주소는 사적 네트워크의
주소이므로 저장소에 올리지 않는다.

### 서버를 따로 띄워 두고 셸만 설치하기

`gyo run`이 띄운 서버는 그 `gyo run`과 함께 죽는다. 서버를 오래 살려 두려면 따로 띄우고
`dev-server` 프로필로 셸만 빌드해 설치한다. `gyo run`이 서버를 직접 띄우는 것은
`development` 프로필일 때뿐이다.

```bash
cd ../web && setsid nohup npx vite > /tmp/opencode/vite.log 2>&1 &
cd ../shell && ANDROID_SERIAL=emulator-5554 mise exec node@24 -- \
  node ~/Documents/gyo/cli/dist/index.js run -p dev-server -d emulator-5554
```

`-d`는 *실행*과 로그가 갈 기기만 고른다. 설치(`installDebug`)는 연결된 모든 기기에 가므로,
폰을 건드리지 않으려면 `ANDROID_SERIAL`로 한 기기를 정한다.

## 패키지 이름, 버전, 아이콘

패키지 이름은 `com.keek_news.app`이다. 2026-11-28까지 이 이름은 Flutter 앱의 것이었고 그 앱은
같은 릴리스 키로 서명됐다. 그래서 이 셸의 릴리즈 APK는 Flutter 앱을 지우지 않고 그 위에 설치된다.

이 이름은 세 곳에 있다: `android/app/build.gradle`의 `namespace`와 `applicationId`, 그리고
`MainActivity.kt`의 패키지(`android/app/src/main/java/com/keek_news/app/`). 셋이 같아야
한다. gyo가 앱을 `<applicationId>/.MainActivity`로 실행하기 때문이다.

`gyo.config.json`의 `packageName`은 `gyo create`가 프로젝트를 만들 때만 쓰이고 `gyo run`·`gyo build`는
다시 적용하지 않는다. 그래서 셸을 새 템플릿으로 다시 만들 때는 위 세 곳을 직접 맞춰야 한다.

버전과 아이콘은 gyo가 빌드마다 `gyo.config.json`에서 APK로 옮긴다. `version`이 `versionName`,
`platforms.android.versionCode`가 `versionCode`다. `versionCode`는 10000×major + 100×minor + patch
으로 정한다: Flutter 앱의 마지막 버전은 3.14.3+72였고, 그 위에 설치되려면 더 커야 한다.

런처 아이콘은 `platforms.android.icon`이 가리키는 `icon/launcher.png`다. 앱 아이콘 `icon/icon.png`을
192px로 줄인 것이다.

디버그 빌드는 이 PC의 디버그 키로 서명되므로, 릴리즈 APK가 설치된 기기에는 `gyo run`으로 덮어쓸 수
없다. 개발은 릴리즈 앱이 없는 기기(에뮬레이터)에서 한다.

## 릴리스

릴리즈는 GitHub Actions가 빌드한다. 저장소 루트 `README.md`의 배포.

## 플러그인

gyo 플러그인은 npm에서 받는다(`web/package.json`의 `@gyo-community/http`, `@gyo-community/media`).
플러그인의 `android/`는 Gradle 라이브러리 모듈이라서, `gyo run`·`gyo build`·`gyo install`은 그
모듈을 앱 빌드에 포함하고 등록 코드를 만든다. 소스를 앱으로 복사하지는 않으므로 플러그인을
바꾸면 빌드에 바로 반영된다. 플러그인을 추가한 뒤에는 셸을 다시 빌드해야 한다.

- 커밋되는 것: `android/gyo.settings.gradle`, `android/app/gyo.build.gradle`,
  `android/app/src/main/java/gyo/plugins/bridge/PluginRegistry.kt`. 셋 다 gyo가 다시 쓴다.
- 커밋되지 않는 것: `.gyo-plugins`(마지막 동기화 기록), `android/app/src/main/assets/gyo-config.json`,
  `local.properties`.

권한은 앱의 매니페스트에 직접 적는다(`android/app/src/main/AndroidManifest.xml`). gyo는
플러그인이 요구하는 권한이 거기 있는지만 살펴보고 없으면 경고한다. 갤러리 저장이 쓰는
`WRITE_EXTERNAL_STORAGE`는 Android 9 이하에서만 필요하므로 `maxSdkVersion="28"`과 함께 있다.
