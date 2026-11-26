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

`gyo run`과 `gyo build`는 빌드 전에 설치된 gyo 플러그인(`web/node_modules/@gyo-framework/*`)의
Kotlin 소스를 `android/app/src/main/java/` 아래로 복사하고 등록 코드를 만든다.
그래서 `android/`에는 커밋되지 않는 `gyo-config.json`과 `.gyo-plugins`가 생긴다.

복사는 플러그인 목록이나 버전이 바뀌었을 때만 다시 된다. 같은 버전에서 플러그인 소스를 고쳤다면
`.gyo-plugins`를 지우고 실행해야 반영된다.

## 패키지 이름

개발용은 `com.keek_news.app.webdev`다. 정식 앱(`com.keek_news.app`)과 같은 폰에 나란히
설치되도록 분리해 두었으며, 정식으로 전환할 때 바꾼다.

이름은 `android/app/build.gradle`의 `applicationId`에 있다. `gyo.config.json`의
`packageName`은 `gyo create`가 프로젝트를 만들 때만 쓰이고 `gyo run`·`gyo build`는 다시
적용하지 않으므로, 둘을 같게 유지한다.

## 의존하는 gyo

`web/package.json`은 형제 저장소 `../../gyo/plugins/*`에서 gyo 플러그인을 연결한다.
플러그인이 npm에 올라가면 버전 범위로 바꾼다.
