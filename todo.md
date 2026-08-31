# todo

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
