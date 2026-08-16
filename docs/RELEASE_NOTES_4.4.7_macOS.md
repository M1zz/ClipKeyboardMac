ClipKeyboard for Mac v4.4.7

한국어

앱 전체 화면을 읽기 좋게 다시 손봤어요. 메뉴바에서도 카테고리별로 단축어를 골라 쓸 수 있고, 어디서나 쓰는 ⌃⇧V 단축키를 이제 앱이 직접 알려줍니다.

- 모든 화면의 글자가 커졌어요, 목록·설정·백업까지 앱 곳곳에 섞여 있던 작은 글씨를 없애고 기본 본문 크기 이상으로 통일했습니다. 정보의 중요도는 글자 크기 대신 굵기와 색으로 구분해서, 작아서 안 보이던 설명들이 이제 편하게 읽혀요
- 아이폰과 똑같은 카테고리를 맥에서도 써요, 메뉴바 목록과 단축어 창의 카테고리가 아이폰에서 설정한 그대로입니다 — 기본·즐겨찾기·템플릿 같은 기본 제공 카테고리와 직접 만든 카테고리가 같은 순서로 서고, 숨긴 탭은 맥에서도 숨겨져요. 그동안 맥은 단축어가 들어 있는 카테고리만 보여주고 즐겨찾기·템플릿 같은 탭은 아예 없었습니다. 검색과 함께 쓸 수 있고 ⌘1~9 단축키도 걸러진 목록 기준으로 동작해요
- ⌃⇧V 빠른 붙여넣기를 앱이 알려줘요, 메뉴바 아이콘에 마우스를 올리거나 목록을 열면 단축키가 보입니다. 우클릭 메뉴에도 항목이 생겨서, 단축키를 모르고 있었더라도 자연스럽게 익히게 돼요. 이 패널은 지금 쓰던 앱 위에 떠서, 커서를 둔 입력칸에 바로 붙여넣습니다
- 화면 곳곳을 정리했어요, 여백과 모서리를 하나의 기준으로 맞추고 지나치게 큰 장식 아이콘과 여러 색으로 흩어져 있던 강조를 정리했습니다. 시작 화면도 맥에 어울리는 담백한 모습으로 바꿨어요
- iCloud 백업 화면이 한눈에 들어와요, 연결 상태와 마지막 백업 시각을 한 장의 카드로 묶고, 세로로 길게 늘어서던 버튼들을 iCloud와 파일 백업으로 나눠 정리했습니다

English

Every screen has been reworked for readability. You can now browse snippets by category from the menu bar, and the app tells you about the ⌃⇧V shortcut you can use anywhere.

- Larger text everywhere, the small type scattered across lists, preferences, and backup is gone — everything is at least standard body size now. Importance is conveyed through weight and color instead of size, so the notes that used to be too small to read are comfortable
- The same categories you set on iPhone, now on Mac, the menu bar list and the snippet window show exactly the categories you configured on iPhone — General, Favorites, and built-ins like Templates alongside your own, in the same order, with hidden tabs hidden here too. Until now the Mac only showed categories that already had snippets in them, and tabs like Favorites and Templates were missing entirely. It works alongside search, and ⌘1–9 follow the filtered list
- The app now surfaces ⌃⇧V quick paste, hover the menu bar icon or open the list and the shortcut is right there, with a matching item in the right-click menu — so you pick it up even if you never knew about it. The panel floats over whatever app you are in and pastes straight into the field your cursor is in
- A tidier look throughout, spacing and corners follow a single scale, and oversized decorative icons and scattered accent colors have been reined in. The welcome screen is now a clean, native-feeling one
- A clearer iCloud backup screen, connection status and last backup time are combined into one card, and the long column of buttons is split into iCloud and file backup groups

---

App Store 제출용 요약 (한국어)

• 앱 전체 글자 크기 확대 — 작은 글씨를 없애고 본문 크기 이상으로 통일
• 아이폰에서 설정한 카테고리를 맥에서 그대로 — 기본·즐겨찾기·기본 제공 카테고리까지 동일한 구성
• ⌃⇧V 빠른 붙여넣기 안내 추가 — 메뉴바 툴팁·목록·우클릭 메뉴에서 확인
• 여백·색·아이콘 정리로 화면 전반 가독성 개선, 시작 화면 새단장
• iCloud 백업 화면 정리 — 상태 카드 통합, 버튼 그룹 분리

App Store Summary (English)

• Bigger text across the app — no more small type, everything at body size or above
• The categories you set on iPhone, mirrored on Mac — including General, Favorites, and built-ins
• ⌃⇧V quick paste is now discoverable — menu bar tooltip, list, and right-click menu
• Cleaner spacing, color, and icons throughout, plus a refreshed welcome screen
• Tidier iCloud backup screen — status combined into one card, buttons grouped

---

## 메모 (배포 담당자용, 스토어 제출 X)

⚠️ **빌드번호를 4.4.7(1)로 지정했다 — 요청에 따른 것이지만 4.4.3 노트의 경고와 충돌한다.**
이전 노트에 "빌드번호는 전역 단조 증가, (1)로 리셋했다가 업로드가 거절된 적이 있다"고
적혀 있다. 직전 제출 빌드는 4.4.3(13)이므로, App Store Connect가 같은 규칙을 적용하면
이 빌드는 업로드 단계에서 거절될 수 있다. 거절되면 `Version.xcconfig` 의
`CURRENT_PROJECT_VERSION` 만 14 이상으로 올려 다시 아카이브하면 된다.

📌 **버전은 이제 `Version.xcconfig` 한 곳에서만 관리된다.**
그동안 `project.pbxproj` 타겟 설정에 `CURRENT_PROJECT_VERSION` 이 박혀 있어 xcconfig 값을
덮어쓰고 있었다(xcconfig 12 / 실제 빌드 13). 이번에 pbxproj 쪽 하드코딩을 제거했으므로
fastlane bump 레인이 정상 동작한다.

⚠️ **4.4.3 노트의 프로비저닝 이슈가 해결됐는지 확인할 것.**
`iCloud.com.Ysoup.FeedbackHub` 컨테이너가 맥 App ID 프로파일에 없으면 서명 빌드가
여전히 실패한다. 이번 릴리즈에서 손댄 부분이 아니다.

ℹ️ **동기화 계약·저장 포맷·Pro 게이트는 건드리지 않았다.** 카테고리는 이미 동기화되던
`CategorySnapshot`(categories·icons·hiddenTabs·enabledBuiltIns·featureEnabled)을 **읽는 쪽만**
아이폰 규칙에 맞췄다.

📌 **탭 구성 규칙이 iOS 와 한 벌로 묶였다.** `BuiltInCategory`·`CategoryTab` 두 선언을 iOS
`ClipKeyboardListViewModel.swift` 에서 글자 그대로 옮겨 `MacCategoryTabs.swift` 에 두고,
`CategoryBucketRule.swift` 는 `Shared/` 로 이식했다. drift-guard 매핑에 3건 추가했으므로
**iOS 를 고치면 맥도 같이 고쳐야 배포 게이트를 통과한다.**

⚠️ **맥에서 "전체" 탭이 없어졌다.** iOS 가 없앤 탭이라 맞춘 것이고, 대신 "기본" 탭이
어느 탭에도 속하지 않는 단축어를 전부 받는다(숨긴 카테고리·고아 단축어 포함).

⚠️ **아이폰에서 막 만든 빈 카테고리는 아직 맥에 안 올 수 있다.** `CategorySnapshotStore.syncable`
이 "비샘플 메모가 붙은 카테고리"만 동기화하기 때문이다(기기 언어별 이름 중복 방지). 맥이 아는
카테고리는 메모가 없어도 탭으로 서지만, 애초에 안 넘어온 카테고리는 탭도 없다 — 의도된 동작이다.

⚠️ **공유 파일 10개가 iOS 와 어긋나 있다(이번 작업과 무관, 기존 상태).** `AppGroup`·`AppLog`·
`AppSymbol`·`DefaultsKey`·`AppNotification`·`StorageFile`·`CategorySnapshot`·`RemoteFlagsService`·
`MemoSyncCore`·`MemoSyncEngine`. iOS 가 앞서 나간 것이라 배포 전 `check_shared_drift.sh` 가 막는다.
단순 재복사는 과거에 빌드를 깼으므로(ee5a04c) 별도 작업으로 다뤄야 한다.
