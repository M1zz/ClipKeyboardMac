# todo

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
