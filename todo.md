# todo

## App Store 스크린샷 (한국어·영어) — 2026-09-09, **완료**

2880×1800 여섯 장 × 두 언어를 `appstore/{ko,en}/` 에 냈다. 만드는 법·촬영에서 걸리는
자리·사고 경위는 전부 [`appstore/README.md`](appstore/README.md) 에 있다.

- [x] 데모 데이터 생성기 `scripts/make_demo_data.py` (ko/en 각 단축어 20 · 클립 9, 실정보 0건)
- [x] 백업·차단·복구 스크립트 `scripts/shoot_prepare.py` (backup / demo / **verify** / restore)
- [x] 합성 `appstore/build.py` (HTML → 헤드리스 Chrome, 카피는 SHOTS 한 곳)
- [x] 한국어·영어 원본 6종: 빠른 붙여넣기 패널 / 메뉴바 팝오버 / 단축어 목록 /
      클립보드 히스토리 / 환경설정·단축키 / iCloud 백업
- [x] **빠른 붙여넣기 패널·메뉴바 팝오버** — 지난 회차에 못 찍었던 두 장.
      팝오버 하단 "빠른 붙여넣기 패널" 버튼과 아이콘 우클릭 메뉴로 열면 된다.
      (앱이 `.accessory` 라 `⌃⇧M` 류 앱 단축키는 키를 보내도 안 먹는다)

### ⚠️ 이 회차에 실데이터 사고가 났다 — 복구 완료
`defaults` CLI 가 **샌드박스 앱이 읽는 plist 와 다른 파일**을 건드리는 걸 몰라
동기화를 못 막은 채 데모 데이터로 앱을 띄웠다. `MemoSyncCore.swift:87` 의
"shadow 에 있는데 로컬에 없으면 삭제" 규칙으로 실제 단축어 37건에 툼스톤이 생겨
iCloud 로 올라갔다. `MemoSyncCore.merge` 의 되살리기 경로(로컬 `lastEdited` 가
원격 툼스톤보다 최신이면 로컬이 이긴다)로 37건 전부 복구했고 아이폰도 정상 확인.
- 대가: 그 37건의 `lastEdited` 가 2026-09-09 22:4x 로 바뀌었다(편집일 정렬이 달라진다).
      원래 값은 `~/ClipKeyboard-실데이터-백업-20260909-204639/container/memos.data` 에 있다.
- 재발 방지는 `shoot_prepare.py` 의 이중 방어 + `verify` 단계. 자세한 건 README.

### 스크린샷에서 새로 발견한 것
- [ ] **영어 단축키 이름의 대소문자가 섞여 있다** — 환경설정 ▸ 단축키에서
      `Quick Paste Panel` · `iCloud Backup` · `Preferences` 는 Title Case 인데
      `Open memo list` · `New memo` · `Clipboard history` 는 문장형이다.
      한 표에 나란히 서 있어 눈에 띈다. 스토어 스크린샷 `en/05-shortcuts.png` 에도 그대로 찍혔다.

## 메뉴바 팝오버에서 카테고리를 바꿔도 옛 항목이 남던 것 — 2026-09-09, **고침**

증상: `내앱`(8개)에서 `프롬프트`(2개)로 옮기면 개수는 2개로 맞는데 내용이
`내앱` 의 맨 위 두 줄(`무지개 공작소` · `욕망의 무지개`)이었다. 두 메모의 `category` 는
둘 다 `내앱` 이라 `프롬프트` 탭에 나올 이유가 없었다.

원인: `MenuBarPopoverView.swift` 의 행에 `.id(index)` 가 붙어 있었다.
`ForEach` 는 `id: \.element.id` 로 메모 id 를 키로 잡는데, **`.id()` 가 그 정체성을
위치 번호로 덮어쓴다.** 그러면 SwiftUI 에게 0·1번 행은 탭이 바뀌어도 "그대로인 같은 뷰"라,
목록이 8개에서 2개로 줄어도 그 자리의 옛 내용이 살아남는다.
`.id(index)` 가 있던 이유는 `ScrollViewReader` 가 `selectedIndex`(정수)로 `scrollTo` 하기
때문 — 정체성을 `memo.id` 로 되돌리고 스크롤 목표도 같은 id 를 쓰게 했다.

- [x] `.id(index)` → `.id(memo.id)`, `scrollTo` 는 `filtered[selectedIndex].id` (범위 검사 포함)
- [x] 같은 실수 다른 데 없는지 확인 — 나머지 `id: \.offset` 은 이미지·값 배열이고
      `.id()` 덮어쓰기가 없어 해당 없음. `MemoListView` 는 `List` + `ForEach(filteredMemos)` 라 무관.
- [x] BUILD SUCCEEDED
- [ ] **실제 클릭 검증 미완** — 앱이 Xcode 에서 돌고 있어 확인 못 했다. ⌘R 로 다시 띄워
      `내앱` → `프롬프트` 를 오가 보면 된다.

## 카테고리 설정이 기기 간에 쌓이기만 하던 것 — 2026-09-09, **고침**

증상: 아이폰에서 탭을 **끄거나 숨김을 풀어도** 맥에는 안 넘어왔다. 켠 것·숨긴 것만
넘어가서 기기를 오갈수록 설정이 쌓이기만 하는 래칫이었다.

원인은 두 자리였다.
- **받는 쪽** `CategorySnapshotStore.apply(.merge)` 가 `hiddenTabs` · `enabledBuiltIns` 를
  합집합으로만 썼다.
- **올리는 쪽** `union(local:remote:)` 이 `enabledBuiltIns` 를 합쳤다.
  (`hiddenTabs` 는 이미 안 합치고 있었다 — 그 판단이 맞았고, 기본 제공 탭도 같은 성격이다)

### 설계 — 필드마다 성격이 다르다
| 필드 | 성격 | 올릴 때 | 받을 때 |
|---|---|---|---|
| `categories` | 사용자가 **만든** 목록(재고) | 합집합 | 더하기 |
| `icons` · `colors` | 카테고리별 꾸밈 | 합집합(내 것 우선) | 더하기 |
| `hiddenTabs` | 사용자가 **치운** 것(상태) | 내 것 그대로 | **거울** |
| `enabledBuiltIns` | 사용자가 **켠** 탭(상태) | 내 것 그대로 | **거울** |
| `featureEnabled` | 기능 스위치 | OR | OR |

재고는 쌓고, **상태는 마지막에 동기화한 기기가 정하고 모두가 그리로 수렴**한다.

⚠️ `.merge` 의 뜻을 바꾸지 않았다. 가져오기(`CloudBackupView` 의 파일 가져오기)도
`.merge` 를 쓰는데, 거기서 거울로 동작하면 **파일 하나 가져왔다고 숨김 설정이 덮인다.**
그래서 동기화 전용으로 `.sync` 를 새로 두고 동기화 경로만 그걸 쓴다.

- [x] iOS: `MergeStrategy` 에 `.sync` 추가, `apply` 가 `.sync` 일 때만 두 필드를 비춤
- [x] iOS: `union` 이 `enabledBuiltIns` 를 합치지 않도록
- [x] iOS: `MemoSyncEngine` 의 적용을 `.merge` → `.sync`
- [x] iOS 테스트 5개 추가 → **41개 전부 통과 (실패 0)**
      (`testSyncMirrorsHiddenTabs` · `testSyncMirrorsEnabledBuiltIns` ·
       `testSyncStillKeepsLocalOnlyCategories` · `testMergeStillUnionsHiddenTabs` ·
       `test_기본제공_탭은_합치지_않는다`)
- [x] 맥으로 이식: `Shared/CategorySnapshot.swift` 는 iOS 원본 그대로 복사(맥 전용 분기 없음).
      `MemoSyncEngine` 은 **통째 복사 금지** — 맥 전용 `#if os(macOS)` 권한 우회(빌드 21의
      리젝 대응)가 날아간다. `makeCategoryRecord` 의 union 블록과 `.sync` 두 자리만 이식.
- [x] 맥 BUILD SUCCEEDED / Pro 게이트 우회 보존 확인
- [x] 드리프트 12건 → **11건** (`CategorySnapshot.swift` 일치). 남은 `MemoSyncEngine.swift`
      드리프트는 **의도된 것**이다 — 위 맥 전용 분기.
- [ ] 실제 기기 간 확인: 아이폰에서 탭을 껐다 켰다 해 보고 맥이 따라오는지.
      ⚠️ 처음 한 번은 **양쪽 다 새 빌드**여야 한다. 옛 빌드는 `.sync` 를 모른다.

### 남은 드리프트 11건 (이번 작업과 무관한 기존 상태)
9건은 "iOS 원본 없음" — `shared_files.sh` 의 iOS 경로가 실제와 어긋나 있다
(`ClipKeyboard/AppGroup.swift` 등). 경로를 실제에 맞춰 고쳐야 검사가 의미를 갖는다.
- [ ] `scripts/shared_files.sh` 의 iOS 경로 9건 정정

## iCloud 복구 버튼이 항상 실패하던 것 — 2026-09-09, **고침**

증상: "복구하기"를 누르면 `작업을 완료할 수 없습니다.(ClipKeyboard_tap.CloudKitError 오류 1.)`
버그 두 개가 겹쳐 있었다.

### 1) 복구 버튼은 단축어가 하나라도 있으면 성공할 수 없었다
`restoreData(forceOverwrite:)` 는 로컬에 데이터가 있으면
`restoreFailed(NSError(code: -2, "…계속하시겠습니까?"))` 를 던졌다. **이건 실패가 아니라
물음**이고, 부르는 쪽이 확인을 받아 `forceOverwrite: true` 로 다시 부르라는 뜻이었다.
그런데 `CloudBackupView.performRestore()` 는 그냥 "복구 실패"로 찍고 끝냈다.
→ `restoreWouldReplaceData(localCount:)` 케이스를 새로 두고(이미 있던
`backupWouldReduceData` 와 같은 결), `performRestore(overwrite:)` 가 그걸 잡아
확인 창을 띄운 뒤 `forceOverwrite: true` 로 다시 부른다.
(스냅샷 "되돌리기"와 자동 복원은 원래 `true` 를 넘겨서 멀쩡했다 — 큰 버튼 하나만 망가져 있었다)

### 2) 공들여 쓴 오류 문구 7개가 화면에 안 나왔다
`CloudKitError` 가 `Error` 만 채택하고 `localizedDescription` 을 **그냥 새 프로퍼티로**
정의했다. 그건 Foundation 의 `Error.localizedDescription` 을 덮지 못한다. 정적 타입이
`Error` 인 `catch` 에서는 Foundation 쪽이 잡혀 NSError 로 브리지되고, 화면엔
"작업을 완료할 수 없습니다. (오류 N.)" 만 떴다.
→ `LocalizedError` 채택 + `errorDescription` 으로 바꿨다. 백업 경로는
`catch let error as CloudKitError` 라 우연히 멀쩡했고, 복구·되돌리기·내보내기만 깨져 있었다.

⚠️ `오류 1` 은 `restoreFailed` 다. Swift 는 **페이로드 있는 케이스를 앞에** 두므로
선언 순서와 다르다: 0 backupFailed · 1 restoreFailed · 2 backupWouldReduceData ·
3 notAuthenticated · 4 noBackupFound · 5 encodingFailed · 6 decodingFailed.

- [x] `CloudKitError: LocalizedError` + `errorDescription`
- [x] `restoreWouldReplaceData(localCount:)` 추가, 확인 창 → 재호출
- [x] 새 문구 3개를 4개 언어에 등재, 안 쓰게 된 옛 문구 1개 삭제 (245개)
- [x] BUILD SUCCEEDED / 컴파일된 4개 언어 각 244개
- [ ] **아직 실제 클릭 검증은 안 했다.** 앱이 Xcode 에서 돌고 있어 이전 빌드였다.
      Xcode 에서 다시 실행(⌘R)한 뒤 "복구하기" → 확인 창이 뜨는지 볼 것.

### 곁가지로 남은 의문
- [ ] iCloud 백업 화면의 "마지막 백업: 2개월 19일 전"(`lastBackupDate` = 2026-06-21)과
      아래 스냅샷 목록의 8월 30일이 어긋난다. 표시 버그인지 자동 백업이 6월 이후
      안 도는 것인지 확인 필요.

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
