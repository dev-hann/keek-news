# 이미지/영상 로딩 근본 원인 수정 — 전체 스윕 + 옵션 B

## 목표

"몇몇 영상이나 이미지가 똑바로 안 뜬다. 재시도해도 안 뜬다." 근본 원인을 파서 레이어에서 제거하고, 썸네일이 없는 영상은 로컬 첫 프레임 추출(옵션 B)로 폴백한다.

## 검증된 근본 원인

### Class A — mp4 URL이 imageUrls에 섞여 들어가 image 위젯이 깨짐 (사용자 가시적, 4개 파서 전무)

`FeedImageCarousel`이 `imageUrls`를 `RetryableNetworkImage`로 렌더. mp4는 디코드 실패 → 3회 재시도 소진 → "탭하여 재시도" 깨진 아이콘 영구 표시. 같은 mp4가 `VideoBlock`으로도 들어와 영상 페이지는 정상 작동 = "영상은 되는데 이미지가 안 뜬다" 현상.

| 파서 | 파일:줄 | 동작 |
|------|---------|------|
| dogdrip | `lib/data/parsers/dogdrip_detail_parser.dart:120-131` | `_extractImages`가 `<source>` mp4를 imageUrls에 add |
| ppomppu | `lib/data/parsers/ppomppu_detail_parser.dart:19` | `[...videoUrls, ...imageUrls]` mp4를 imageUrls 앞에 붙임 |
| todayhumor | `lib/data/parsers/todayhumor_detail_parser.dart:83-88` | `_extractImages`가 `<source>` mp4를 imageUrls에 add |
| humoruniv | `lib/data/parsers/board_list_parser.dart:83-90` | `_fullSizeFromThumb`이 `thumb.php?url=<mp4>`를 raw mp4로 언랩. `post.thumbnailUrl`은 현재 FeedCard에서 미렌더지만 잘못된 데이터 |

### Class B — protocol-relative URL 망가짐 (dogdrip 전용, 검증 404)

`lib/data/parsers/dogdrip_detail_parser.dart:139`
```dart
src.startsWith('/') ? 'https://www.dogdrip.net$src' : src
```
`//rc.dogdrip.net/...`도 `startsWith('/')` 참 → `https://www.dogdrip.net//rc.dogdrip.net/...` → 404.
올바른 건 `https://rc.dogdrip.net/...` (200 검증).

### Class C — 본문 스콥 누수 (dogdrip 전용)

`_findContent:113`이 `div[class*="document_"]` 선택. 이 div는 `.rhymix_content xe_content` 본문 외에 댓글·서명·UI 크롬을 감쌈. 결과:
- `/modules/board/skins/eden/.../*.svg` (카카오/네이버 브랜드 아이콘)
- `/modules/point/icons/ddcoa/*.gif` (포인트 아이콘, 88바이트)
- 2020년 인용 이미지, 댓글 서명 gif
전부 imageUrls로. 실제 본문 이미지 1장인데 20개.

### Class D — SVG 디코드 불가 (dogdrip)

`pubspec.yaml`에 `flutter_svg` 없음. dogdrip `.svg`가 200이어도 `CachedNetworkImage`가 디코드 못함 → 또 깨짐.
→ Class C 수정하면 자연히 해결(svg가 imageUrls에 안 들어옴)지만, 방어적으로 SVG 제거 필터도 추가.

### Class E — humoruniv url_enc 암호화 썸네일 (잠재)

- `lib/data/parsers/content_scanner.dart:342-358` `_commentMp4Entry`가 `<img class='comment_thumb_img'>` src(`timg.humoruniv.com/thumb.php?url_enc=...`)를 `thumbUrl`로. curl 검증: **403 Forbidden** (UA/Referer 무관, 세션 토큰이라 클라이언트 복호 불가).
- `board_list_parser.dart:84` 정규식 `thumb\.php\?url=([^&]+)`가 중첩 `thumb.php?url=//timg.../thumb.php?url_enc=...?SIZE=...` 만나면 쓰레기 URL(잠재, 현재 board list엔 url_enc 없음).

현재 `Comment.mediaBlocks`는 렌더되지 않아(Class E alone은) 사용자 가시적 아님. 하지만 댓글 미디어 렌더 추가 시 즉시 발현. 옵션 B 적용 대상.

## 아키텍처 결정

### 결정 1: imageUrls는 "CachedNetworkImage가 로드 가능한 이미지 URL"만 담는다

mp4/webm/mov/svg/url_enc/망가진 URL 전부 제외. 이게 근원. 파서가 정확하면 위젯은 방어 로직 불필요.

### 결정 2: VideoBlock.thumbnailUrl null이면 VideoThumbnail 위젯이 로컬 첫 프레임 추출 (옵션 B)

- humoruniv url_enc 댓글 mp4 → thumbnailUrl null로 드랍 → VideoThumbnail
- dogdrip `<video><source>` (썸네일 本來 없음) → VideoBlock.thumbnailUrl null → VideoThumbnail
- ppomppu/todayhumor `<video>`도 동일

지연 초기화: `VisibilityDetector`로 가시일 때만 `VideoPlayerController.networkUrl` 생성, 스크롤 벗어나면 dispose. 큰 영상은 `VideoPlayerController`의 기본 preload로 헤더+첫 프레임만.

### 결정 3: 위젯 레벨 방어 로직은 추가 안 함

파서가 정확하면 imageUrls에 mp4 안 섞임. 위젯이 URL 확장자 검사하는 건 결합도 상승. 파서 정확성이 1차 방어선.

### 결정 4: MediaClassifier 헬퍼 추가 (재사용)

`MediaClassifier.isLoadableImage(url)` 정적 메서드 추가. 각 파서가 중복 구현 안 함.
- mp4/webm/mov/m4v/avi/mkv → false
- svg → false (CachedNetworkImage 호환성)
- `url_enc=` 포함 → false
- query string 있는 URL은 ext 검사 전 `?` 전까지 자르기
- `thumb.php?url=<plaintext>` 형태는 true (서버가 PNG 생성 검증됨)
- 그 외 image 확장자 → true

## TDD 작업 순서 (AGENTS.md Tier 준수)

각 단계 RED→`flutter test`→GREEN→`flutter test`. 단계 건너뛰기 금지.

### Step 1: MediaClassifier 보강 (Tier S — 사례별)

`lib/core/utils/media_classifier.dart` + `test/unit/core/utils/media_classifier_test.dart`

사례별 RED→GREEN (한 번에 하나씩):
1. `isLoadableImage('https://x.com/a.mp4')` → false
2. `isLoadableImage('https://x.com/a.jpg?SIZE=70x40')` → true (query string 무시)
3. `isLoadableImage('https://x.com/icon.svg')` → false
4. `isLoadableImage('https://timg.humoruniv.com/thumb.php?url_enc=abc')` → false
5. `isLoadableImage('https://timg.humoruniv.com/thumb.php?url=https://x.com/a.jpg')` → true
6. `isLoadableImage('//rc.dogdrip.net/a.gif')` → true (normalize 후)
7. `isLoadableImage('https://x.com/page.html')` → false

### Step 2: dogdrip 파서 수정 (Tier S — 사례별)

`lib/data/parsers/dogdrip_detail_parser.dart` + `test/unit/data/parsers/dogdrip_detail_parser_test.dart`

새 fixture `test/fixtures/dogdrip/detail_716302509.html` (사용자 제공 URL로부터 획득 — `curl -A <desktop UA>`로 UTF-8 그대로 저장).

사례별:
1. `_extractImages`에서 mp4 제외 → RED(현재 mp4 포함) → `_extractImages`에 `MediaClassifier.isLoadableImage` 필터 → GREEN
2. `//rc.dogdrip.net/x.gif` → `https://rc.dogdrip.net/x.gif` (200) → RED(현재 `www.dogdrip.net//rc...` 404) → `src.startsWith('//')` 분기 먼저, `src.startsWith('/')` 분기는 그 다음 → GREEN
3. `.svg` 제외 → Class C/D 해결 → RED → GREEN (isLoadableImage로 자동)
4. `_findContent`를 `.rhymix_content.xe_content` 정확히 선택 → RED(현재 `/modules/` 크롬 포함) → GREEN. 본문만 스캔하면 point icons/브랜드 svg 자연 제거
5. `_buildBlocks`의 `<video><source>` → `VideoBlock(url: ..., thumbnailUrl: null)` 유지(이미 그럼). 확인용 테스트

### Step 3: ppomppu 파서 수정 (Tier S)

`lib/data/parsers/ppomppu_detail_parser.dart` + 기존 테스트.

**먼저 기존 잘못된 테스트 제거/반전**: `test/unit/data/parsers/ppomppu_video_test.dart:17-25`의 "비디오 URL이 imageUrls에 포함되어야 함" 테스트는 버그를 기대값으로 인코딩 중. 이걸 "비디오 URL이 imageUrls에 포함되지 않아야 함"으로 반전.

사례:
1. imageUrls에 mp4 없음 → RED(현재 포함) → `parse:19`의 `[...videoUrls, ...imageUrls]`에서 videoUrls 제거 → GREEN
2. videoUrls는 여전히 VideoBlock으로 들어감(기존 테스트 line 27-33 유지)

### Step 4: todayhumor 파서 수정 (Tier S)

`lib/data/parsers/todayhumor_detail_parser.dart` + 테스트.

사례:
1. imageUrls에 mp4 없음 → RED → `_extractImages:83-88`의 source mp4 루프 제거 → GREEN
2. mp4는 VideoBlock으로(`_buildBlocks` 이미 처리) — 확인 테스트

### Step 5: humoruniv board_list 파서 수정 (Tier S)

`lib/data/parsers/board_list_parser.dart` + `test/unit/data/parsers/board_list_parser_test.dart`.

사례:
1. 비디오 게시글 썸네일이 raw mp4가 아닌 `thumb.php?url=<mp4>` 형태 유지 → RED → `_fullSizeFromThumb`에서 언랩 후 URL이 비디오면 원본(thumb.php URL) 반환 → GREEN
2. 이미지 게시글은 기존대로 평문 언랩 — 회귀 테스트

### Step 6: humoruniv content_scanner 수정 (Tier S)

`lib/data/parsers/content_scanner.dart` + `test/unit/data/parsers/content_scanner_test.dart`.

사례:
1. `_commentMp4Entry`가 `url_enc=` src면 thumbUrl null → RED → src 검사 추가 → GREEN
2. 본문 이미지는 img_file_url 우선(기존) — 회귀

### Step 7: VideoThumbnail 위젯 (Tier A — 클래스별)

`lib/core/widgets/atoms/video_thumbnail.dart` (신규) + `test/unit/core/widgets/atoms/video_thumbnail_test.dart` (신규).

`inline_video_player_test.dart` 패턴 참고(video_player가 widget test에서 초기화 안 되는 점 활용).

사례(모두 RED 먼저):
1. `videoUrl` 주면 위젯 트리 깨짐 없이 렌더 — placeholder 표시
2. 미가시 상태에선 `VideoPlayerController` 생성 안 함 — VisibilityDetector 가시 전까지 controller 없음
3. 가시 되면 controller 생성 시도 — `VideoPlayerController.networkUrl` 호출
4. 에러 시 placeholder 폴백 — `_hasError` 시 ColoredBox
5. dispose 시 controller 해제

구현 요점:
- `ConsumerStatefulWidget` 불필요(프로바이더 없음) → `StatefulWidget`
- `VisibilityDetectorController.instance.updateInterval = Duration.zero` 테스트 setUp
- `VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then(...).catchError(...)`
- 초기화 중에는 `_buildPlaceholder()`, 완료 시 `VideoSurface(controller: _controller)`, 에러 시 placeholder
- `aspectRatio`: controller.value.aspectRatio, 기본 16/9
- 가시 임계치 0.4(`inline_video_player.dart:41` `_kPauseThreshold`와 일치)

### Step 8: FeedImageCarousel 연동 (Tier A)

`lib/core/widgets/molecules/feed_image_carousel.dart` + `test/unit/core/widgets/molecules/feed_image_carousel_test.dart`.

`_buildVideoPage:174-179` 수정:
```dart
if (video.thumbnailUrl != null)
  RetryableNetworkImage(imageUrl: video.thumbnailUrl!, ...)
else
  VideoThumbnail(videoUrl: video.url, ...)
```

사례:
1. VideoBlock.thumbnailUrl null → VideoThumbnail 렌더 → RED(현재 ColoredBox) → GREEN
2. VideoBlock.thumbnailUrl 있으면 기존 RetryableNetworkImage — 회귀

### Step 9: 통합 테스트

`test/integration/`에 각 파서→FeedImageCarousel 파이프라인 검증. 실제 fixture로 파싱 후 imageUrls에 mp4/svg 없음 단언, VideoBlock은 별도.

### Step 10: DI/분석

- DI 변경 불필요(VideoThumbnail은 순수 위젯, 주입 없음)
- `flutter analyze --no-fatal-infos` 통과

### Step 11: 최종 `make check`

`make check` (analyze + test) 전부 GREEN 확인 후 커밋.

## 파일 변경 요약

| 파일 | 변경 |
|------|------|
| `lib/core/utils/media_classifier.dart` | `isLoadableImage` 추가 |
| `lib/data/parsers/dogdrip_detail_parser.dart` | `_extractImages` 필터·protocol-relative 수정, `_findContent` 셀렉터 정제 |
| `lib/data/parsers/ppomppu_detail_parser.dart` | `parse` imageUrls에서 videoUrls 제거 |
| `lib/data/parsers/todayhumor_detail_parser.dart` | `_extractImages` mp4 루프 제거 |
| `lib/data/parsers/board_list_parser.dart` | `_fullSizeFromThumb` 비디오 언랩 방지 |
| `lib/data/parsers/content_scanner.dart` | `_commentMp4Entry` url_enc 드랍 |
| `lib/core/widgets/atoms/video_thumbnail.dart` | 신규 |
| `lib/core/widgets/molecules/feed_image_carousel.dart` | `_buildVideoPage` VideoThumbnail 연동 |
| 각 `*_test.dart` | 사례별 RED→GREEN |
| `test/fixtures/dogdrip/detail_716302509.html` | 신규 fixture |

## 리스크/메모

- **기존 잘못된 테스트**: `ppomppu_video_test.dart:17-25` 명시 반전 필요. TDD 관점에서 이 테스트가 버그를 굳혀온 것.
- **video_player 위젯 테스트**: 네이티브 플러그인이라 widget test에서 `initialize()` 완료 안 됨. `inline_video_player_test.dart`처럼 초기화 전 placeholder 상태 단언. 실제 프레임 렌더는 E2E/수기 확인.
- **Class E(humoruniv url_enc)는 현재 미렌더**: Comment.mediaBlocks가 home_screen 댓글 바텀시트에서 text-only. Step 6 수정은 미래 렌더 추가 대비 + data 정확성.
- **fixture 획득**: dogdrip 716302509는 사용자가 확인한 URL. 구현 단계에서 `curl -A <desktop UA> -o test/fixtures/dogdrip/detail_716302509.html` 로 획득(이미 /tmp/opencode/dogdrip.html에 있음 — 그대로 복사).
- **큰 영상 비용**: VideoThumbnail 지연 초기화로 완화하지만, pds 본문 대형 mp4(18MB)는 첫 프레임 추출 시 헤더+일부 다운로드. 본문 영상은 현재 thumbnailUrl이 thumb.php PNG로 있어(humoruniv)/dogdrip도 VideoBlock이 본문에 오면 VideoThumbnail 경유. 수용 범위.
- **pubspec flutter_svg 추가 여부**: Class C 수정로 svg가 imageUrls에 안 들어오므로 불필요. 추가 안 함.

## 커밋 분할 제안

TDD 사이큩은 단계별이지만 커밋은 논리 단위로:
1. `feat: add MediaClassifier.isLoadableImage helper`
2. `fix: exclude mp4/svg from imageUrls in dogdrip/ppomppu/todayhumor parsers`
3. `fix: dogdrip protocol-relative URL and content scope`
4. `fix: humoruniv board list video thumbnail unwrapping`
5. `fix: drop humoruniv url_enc encrypted thumbnails`
6. `feat: VideoThumbnail widget with lazy first-frame extraction`
7. `feat: use VideoThumbnail for null-thumb videos in feed carousel`

각 커밋 전 `make check` GREEN.
