# todo

## App Store 스크린샷 (한국어·영어) — 2026-09-09, **진행 중**

목표: 2880×1800 6장 × 2개 언어. 상단 카피 + 실제 앱 창.

### 촬영 환경 (중요 — 다시 할 때 그대로)
- 실데이터에 주민번호·카드번호·계좌번호·여권번호·깃토큰이 있어 **그대로 찍으면 안 된다**.
  App Group 컨테이너(`~/Library/Group Containers/group.com.Ysoup.TokenMemo`)의
  `memos.data`·`clipboard.history.data`·`Library/Preferences/*.plist` 를 비켜두고
  데모 데이터로 촬영한 뒤 되돌리는 방식으로 진행. **이번 회차 복구 완료 검증됨**
  (메모 37개·클립 100개·`memoSyncEnabled=true`·`dev.masterMode=true`·이미지 399개).
- ⚠️ `memoSyncEnabled` 가 **켜져 있다**. 빈/데모 상태로 앱을 띄우면 아이폰 데이터를
  깎을 수 있으므로, 촬영용 컨테이너에서는 반드시 `memoSyncEnabled=false` +
  `memoSync.cloudAdopted.v1=true`(iCloud KV 가 다시 켜는 경로 차단) 로 두고 띄울 것.
- 클립보드 감시는 `startMonitoring()` 에서 `lastChangeCount` 를 먼저 잡으므로,
  **앱 시작 시점의 클립보드는 히스토리에 안 들어간다.** 시드 → 실행 → 즉시 촬영이면 깨끗하다.
  (실행 중에 사용자가 복사하면 들어오므로, 촬영본은 눈으로 확인할 것.)
- 창 캡처는 `screencapture -x -o -l <windowID>` 로 레티나 2배 원본을 얻는다.
  창을 key 상태(신호등 컬러)로 만들려면 제목표시줄을 한 번 클릭한 뒤 앱을 front 로.

### 진행 상황
- [x] 데모 데이터 생성기 (`make_demo.py` — ko/en 각 14개 단축어 + 9개 클립, 실정보 0건)
- [x] 촬영용 빌드 (5.0.5(21), BUILD SUCCEEDED)
- [x] 한국어 원본 캡처 6종: 단축어 목록 / 클립보드 히스토리 / iCloud 백업 /
      환경설정·단축키 / 환경설정·일반 / 새 단축어(템플릿 변수 하이라이트)
- [ ] **빠른 붙여넣기 패널·메뉴바 팝오버 캡처** — 배경 제어로는 못 띄운다.
      메뉴 항목이 클립보드를 건드려 차단되고, 전역 단축키 ⌃⇧V 는 화면 제어가 필요.
      → 화면 제어 승인을 받아야 찍을 수 있다. 이 앱의 핵심 화면이라 빠지면 아깝다.
- [ ] 영어 캡처 (미착수)
- [ ] 2880×1800 합성 (카피 + 창 + 배경) — 미착수

## App Store 문안 결함 2건 — 스크린샷 작업 중 발견 (2026-09-09)

### 1) 전역 단축키 표기가 틀렸다 — `docs/marketing/APP_STORE_MAC.md`
실제 등록값은 `keyCode 9(V) + control|shift` = **⌃⇧V** (`GlobalHotkeyManager.swift:27-28`).
그런데 스토어 설명 4개 언어 전부가 **⌃⌥K** 로 적고 있다(ko 39·45행, en 71·77행,
zh-Hans 103·109행, zh-Hant 135·141행). 같은 문단 안에서 패널은 ⌃⇧V, 전역 단축키는
⌃⌥K 로 갈려 있어 읽는 사람이 둘 다 눌러보게 된다. 앱 안 문구는 이미 고쳐졌는데
(2026-08-27 작업) 스토어 문안만 옛 값으로 남았다.
- [ ] 4개 언어 설명에서 ⌃⌥K / Control-Option-K → ⌃⇧V / Control-Shift-V

### 2) 스토어 설명에 Pro 문단이 그대로 남아 있다 — 이번 리젝 사유와 직결
리뷰어가 말한 "references to Pro" 는 **메타데이터도 포함**한다. 앱에서는 Pro 를
전부 걷어냈는데(빌드 21), 설명 문안에는 아직 남아 있다:
- "무료와 Pro / Free and Pro / 免费与 Pro / 免費與 Pro" 섹션 통째 (ko 59·61, en 91·93,
  zh-Hans 123·125, zh-Hant 155·157행)
- "iOS에서 Pro를 구매하셨다면 이 맥에서도 자동으로 켜집니다" (ko 53, en 85,
  zh-Hans 117, zh-Hant 149행)
이 상태로 제출하면 **같은 사유로 또 걸린다.** 맥은 유료 다운로드라 팔 것이 없다.
- [ ] 4개 언어에서 Pro 문단·문장 삭제 (문서 + App Store Connect 양쪽)
- [ ] 문서 상단의 "⚠️ 무료 한도는 코드값을…" 주석과 208~212행 '아직 안 된 것' 항목도
      Pro 제거에 맞춰 정리

## 브랜치 정리 (2026-09-09)

- [x] `origin/fix/sync-needs-consent-on-this-device` 가 main 에 **완전히 병합됨** 확인
      (`git merge-base --is-ancestor` YES, main 대비 0 commits ahead / 7 behind).
      tip = `25d4f98 chore(5.0.3): 아이폰과 버전을 맞추고, 갈라져 있던 공유 파일을 되돌린다`
- [ ] **원격 브랜치 삭제 — 권한 정책에 막혀 실행 못 함.** 직접 실행 필요:
      `git push origin --delete fix/sync-needs-consent-on-this-device && git fetch --prune`
- [ ] `stash@{0}` — 2026-08-27 자동 stash(merge 직전), 43개 파일.
      `SyncStatusView.swift` `MacCategoryStore.swift` `SyncCloudPeek.swift` 등
      **지금 main 에 없는 파일**이 들어 있어 함부로 버리지 않았다. 판단 필요.


## App Store 리젝 대응 — Guideline 2.1(b) (2026-08-31, 제출 1aa60e4d / 5.0.5(20))

리뷰 지적: "앱이 Pro 를 참조하는데 해당 IAP 가 심사에 제출되지 않았다."
실상: **맥 앱은 스토어 유료 다운로드**다. 번들 ID(`com.ysoup.TokenMemo-tap`)가 아이폰과
달라 유니버설 구매도 아니고, 이 앱 레코드에는 IAP 자체가 없다. 그런데 화면에는
아이폰 결제 키를 iCloud KV 로 받아 잠그는 Pro 게이트가 남아 있어서, **맥 앱을 제값 주고
산 사용자가 "무료 플랜 · 단축어 10개" 취급**을 받고 있었다. 심사 이슈이기 전에 버그.

- [x] `MacPreferencesView` Pro 탭 통째 삭제 (상태 카드·기능 비교표·"iOS 에서 구매하면…"·상태 새로고침)
      - 비교표 숫자(5개/20개)는 실제 한도(10개/50개)와도 어긋나 있었다
- [x] `CloudBackupView` Pro 게이트 삭제 — iCloud 백업/복구·파일 내보내기를 모든 구매자에게 개방
- [x] `MemoListView` 무료 표시 한도(`prefix(10)`)와 "N개 단축어 잠김" 배너 삭제
- [x] `MacProManager` 제거 (Models.swift) — 삭제 이유는 같은 자리에 주석으로 남김
- [x] `MemoSyncEngine` 동기화 게이트: `#if os(macOS)` 로 맥은 무조건 통과
      (맥만 산 사용자는 토글을 켜도 엔진이 조용히 거부하던 문제도 같이 해결)
- [x] `ClipKeyboardTapSpec.monetization` `.free` → `.paidUpfront`
- [x] `Localizable.xcstrings` 에서 Pro 관련 키 16개 삭제 (4개 언어 · 243개 남음)
- [x] 빌드 번호 20 → 21 (20 은 거절된 번호라 재사용 불가)
- [x] 검증: BUILD SUCCEEDED / 컴파일된 4개 언어 `Localizable.strings` 에 Pro·플랜·구매 문구 0건

### 앱 밖에서 해야 할 일 (App Store Connect)
- [ ] 앱 설명·스크린샷·프로모션 텍스트에 Pro / In-App Purchase 언급이 남아 있으면 삭제
      (리뷰어가 말한 "references to Pro" 에 메타데이터도 포함될 수 있다)
- [ ] 이 앱 레코드에 만들어 둔 IAP 상품이 있으면 삭제하거나 제출 대상에서 제외
- [ ] 리뷰 노트 회신: "이 Mac 앱은 유료 다운로드이며 앱 내 구매가 없습니다.
      5.0.5(21) 에서 Pro 관련 UI 를 모두 제거했고, 구매 시 전 기능이 열립니다."
- [ ] 빌드 21 업로드 후 심사 제출

## 영어 지역화 100% (2026-08-27)

### 1차 — 문자열 번역
- [x] stash pop 충돌 정리 — `git reset --hard HEAD`(5.0.3/빌드16), `stash@{0}` 는 보존
- [x] 리터럴 `NSLocalizedString` 키 241개 전부 카탈로그 등재 확인
- [x] `MemoAddView` 자동 변수 라벨 6개 — 동적 키라 추출이 못 잡던 것을 리터럴로 전환 + en 추가
- [x] `MemoStore.saveImage` 의 `NSError` 설명 2건 래핑 (저장 실패 토스트로 노출됨)
- [x] 빈 키 `""` 제거 / `%1$@ — %2$@ (⌃⇧V)` · `Feedback & Review` en·ko 채움 / `%@ (⌘%@)` 정리
- [x] iCloud 안내 영문 3건 — iOS 문구("Settings") → 맥 문구("System Settings")

### 2차 — "번역된 한국 앱"으로 보이지 않게
- [x] **`"기본"` 센티널이 화면에 새던 것 차단** (가장 큰 구멍)
      - 저장값 `"기본"` 은 아이폰과의 계약이라 그대로 두고, 표시만 가르는
        `MacCategoryName`(display/stored) 을 `MacCategoryTabs.swift` 의 **감시 블록 바깥**에 추가
      - 새 단축어 시트 카테고리 칸에 `기본` 이 한글로 찍히던 것 → "General"
      - `legacyTabs` 가 `custom("기본")` 탭을 만들어 탭 바에 `기본` 이 뜨던 것 → "General"
      - 렌더 지점 2곳(`MemoListView` `MenuBarPopoverView`) + 입력 2곳(`MemoAddView` `MemoEditView`)
      - 순수 로직 11건 단위 검증 통과(한국어 UI 회귀 없음), 감시 블록 2개는 HEAD 와 바이트 동일
- [x] **전역 단축키 오기 `⌃⌥K` → `⌃⇧V`** — 온보딩·ContentView 2곳.
      실제 등록은 `keyCode 9(V) + control|shift`. 나머지 10곳은 원래 `⌃⇧V` 였다.
      신규 사용자가 처음 읽는 안내가 틀린 단축키라 "눌러도 안 되는 앱"이 되던 문제.
- [x] base `CFBundleDisplayName` 을 `클립키보드` → `ClipKeyboard` (developmentRegion=en 과 일치).
      ko.lproj 가 계속 `클립키보드` 로 덮으므로 한국어 사용자에겐 변화 없음.
- [x] 빌드 검증: BUILD SUCCEEDED / `en.lproj` 253개, 영문에 한글 잔존 0건

### 확인만 하고 손대지 않은 것 (의도된 한글)
- `MacTemplateSupport` 의 `{날짜}` `{시간}` 등 19개 — 한글 **토큰 별칭**.
  아이폰에서 넘어온 템플릿 호환용. 영어 사용자는 `{date}` `{time}` 을 쓴다.
- `MacSampleSeeder` — `isKorean` 분기로 영어 샘플(Work/Personal/John Doe/Example Bank) 제공 중
- `ComboItemType.memo` rawValue `"메모"` — 직렬화 값. 참고로 `localizedName` 두 개
  (`ClipboardItemType` · `ComboItemType`) 는 **어디서도 안 쓰이는 죽은 코드**라 노출 경로가 없다.
  → 덕분에 통관번호·사번/학번 같은 한국 특화 타입 27개도 화면에 안 나온다.
- `MemoEditView` `#Preview` 픽스처

## 남은 벽 — 앱 밖 (이 레포에서 못 고침)

- [ ] **도움말 페이지가 한국어 전용.** `m1zz.github.io/ClipKeyboard/tutorial.html`
      (메뉴 `ClipKeyboard Help` · 환경설정 `View User Guide` 목적지)
      - `index.html` `tutorial.html` `privacy.html` 셋 다 한국어 본문인데 `<html lang="en">` 으로 서빙 중
      - **언어 스위처는 없다.** `tutorial-en.html` `en/tutorial.html` 등 흔한 경로 전부 404
      - 앱 안은 전부 영어인데 도움말만 한국어라, 지금은 여기가 제일 큰 이질감
      - → 별도 레포(`m1zz.github.io`) 작업 필요. `lang` 속성도 실제 언어에 맞게.
      - 영문판이 생기면 앱 쪽은 언어별 URL 분기만 넣으면 된다(2곳: `ClipKeyboard_macApp.swift`, `MacPreferencesView.swift`)
- [ ] **App Store 리스팅** — 레포에 metadata 없음(App Store Connect 직접 관리).
      영문 설명·키워드·스크린샷이 없으면 외국인은 앱을 만나기 전에 걸러진다.
- [ ] 도움말 안의 App Store 링크가 `apps.apple.com/**kr**/...` 로 한국 스토어 고정

## 그 밖 (선택)

- [ ] iCloud 안내의 **한글** 문구도 아직 iOS 표현(`설정 > [사용자 이름]`) — 키가 한글이라 소스+카탈로그 동시 수정 필요
- [ ] `CFBundleName` 이 `ClipKeyboard.tap` — 앱 메뉴에 그대로 뜬다. `ClipKeyboard` 로 다듬을 여지
- [ ] `{date}`/`{time}` 치환이 `yyyy-MM-dd` · `HH:mm:ss` 고정. 한국색은 아니지만 미국 사용자는
      `8/27/2026` · `1:00 PM` 을 기대한다. 바꾸면 기존 템플릿 결과가 변하므로 결정 필요.
- [ ] 기존에 커스텀 카테고리를 **문자 그대로 "General"** 로 만들어 둔 사용자는, 그 단축어를 다음에
      편집·저장할 때 기본 칸으로 합쳐진다. 탭 이름이 어차피 "General" 이라 화면상 차이는 없다.
- [ ] `stash@{0}` (4.4.2 시절 작업) 처리 여부 — 불필요하면 `git stash drop`
