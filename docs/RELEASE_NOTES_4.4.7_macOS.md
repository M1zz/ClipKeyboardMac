ClipKeyboard for Mac v4.4.7

한국어

앱 전체 화면을 읽기 좋게 다시 손봤어요. 메뉴바에서도 카테고리별로 단축어를 골라 쓸 수 있고, 어디서나 쓰는 ⌃⇧V 단축키를 이제 앱이 직접 알려줍니다.

- 모든 화면의 글자가 커졌어요, 목록·설정·백업까지 앱 곳곳에 섞여 있던 작은 글씨를 없애고 기본 본문 크기 이상으로 통일했습니다. 정보의 중요도는 글자 크기 대신 굵기와 색으로 구분해서, 작아서 안 보이던 설명들이 이제 편하게 읽혀요
- 메뉴바에서도 카테고리로 나눠 봐요, 메뉴바 목록 위에 카테고리 탭이 생겼습니다. 순서와 아이콘은 아이폰에서 정한 그대로 따라오고, 카테고리가 하나뿐이면 탭 줄은 나타나지 않아요. 검색과 함께 쓸 수 있고 ⌘1~9 단축키도 걸러진 목록 기준으로 동작합니다
- ⌃⇧V 빠른 붙여넣기를 앱이 알려줘요, 메뉴바 아이콘에 마우스를 올리거나 목록을 열면 단축키가 보입니다. 우클릭 메뉴에도 항목이 생겨서, 단축키를 모르고 있었더라도 자연스럽게 익히게 돼요. 이 패널은 지금 쓰던 앱 위에 떠서, 커서를 둔 입력칸에 바로 붙여넣습니다
- 화면 곳곳을 정리했어요, 여백과 모서리를 하나의 기준으로 맞추고 지나치게 큰 장식 아이콘과 여러 색으로 흩어져 있던 강조를 정리했습니다. 시작 화면도 맥에 어울리는 담백한 모습으로 바꿨어요
- iCloud 백업 화면이 한눈에 들어와요, 연결 상태와 마지막 백업 시각을 한 장의 카드로 묶고, 세로로 길게 늘어서던 버튼들을 iCloud와 파일 백업으로 나눠 정리했습니다

English

Every screen has been reworked for readability. You can now browse snippets by category from the menu bar, and the app tells you about the ⌃⇧V shortcut you can use anywhere.

- Larger text everywhere, the small type scattered across lists, preferences, and backup is gone — everything is at least standard body size now. Importance is conveyed through weight and color instead of size, so the notes that used to be too small to read are comfortable
- Categories in the menu bar too, category tabs now sit above the menu bar list. Order and icons follow whatever you set on iPhone, and the tab row stays hidden when there is only one category. It works alongside search, and ⌘1–9 follow the filtered list
- The app now surfaces ⌃⇧V quick paste, hover the menu bar icon or open the list and the shortcut is right there, with a matching item in the right-click menu — so you pick it up even if you never knew about it. The panel floats over whatever app you are in and pastes straight into the field your cursor is in
- A tidier look throughout, spacing and corners follow a single scale, and oversized decorative icons and scattered accent colors have been reined in. The welcome screen is now a clean, native-feeling one
- A clearer iCloud backup screen, connection status and last backup time are combined into one card, and the long column of buttons is split into iCloud and file backup groups

---

App Store 제출용 요약 (한국어)

• 앱 전체 글자 크기 확대 — 작은 글씨를 없애고 본문 크기 이상으로 통일
• 메뉴바 목록에 카테고리 탭 추가 — 아이폰에서 정한 순서·아이콘 그대로
• ⌃⇧V 빠른 붙여넣기 안내 추가 — 메뉴바 툴팁·목록·우클릭 메뉴에서 확인
• 여백·색·아이콘 정리로 화면 전반 가독성 개선, 시작 화면 새단장
• iCloud 백업 화면 정리 — 상태 카드 통합, 버튼 그룹 분리

App Store Summary (English)

• Bigger text across the app — no more small type, everything at body size or above
• Category tabs in the menu bar list — same order and icons you set on iPhone
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

ℹ️ **이번 릴리즈는 UI 전용이다.** 동기화 계약·저장 포맷·Pro 게이트는 건드리지 않았다.
새로 번역이 필요한 문자열도 없다(기존 키 재사용).
