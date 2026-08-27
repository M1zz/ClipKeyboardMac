ClipKeyboard for Mac v5.0.4

영어로 쓰는 사람에게 이 앱이 "한국 앱"으로 보이던 자리를 걷어냅니다.
(빌드 번호는 전역 단조 증가라 16 다음인 17 입니다)

한국어

번역이 빠진 곳도 있었지만, 더 큰 문제는 **번역할 수 없는 자리에 한글이 박혀 있던 것**이었습니다.

- **카테고리 칸에 `기본` 이 한글로 찍히던 것을 고쳤어요**, `"기본"` 은 번역어가 아니라 아이폰과 주고받는 저장값입니다. 그런데 이 값이 화면까지 그대로 흘러나와서, 영어로 앱을 쓰는 사람이 단축어를 하나 만들 때마다 한글이 적힌 칸을 봐야 했습니다. 탭 바에도 `기본` 탭이 섰습니다. 저장값은 그대로 두고 — 그래야 아이폰에서 같은 칸에 들어갑니다 — 화면에 보이는 이름만 "General" 로 가릅니다
- **자동 변수 이름이 한글로 남아 있던 것을 고쳤어요**, 단축어를 쓸 때 눌러서 넣는 `날짜`·`시간`·`타임존`·`통화`·`인사`·`도시` 여섯 개입니다. 앱이 이 이름을 다른 방식으로 불러오는 바람에 번역 목록에 아예 잡히지 않았고, 그래서 어떤 언어로 켜도 한글이었습니다
- **전역 단축키 안내가 틀렸던 것을 고쳤어요**, 처음 켰을 때 나오는 안내와 홈 화면이 `⌃⌥K` 라고 알려 주는데 실제로 동작하는 건 `⌃⇧V` 였습니다. 앱 안의 다른 열 군데는 전부 맞게 적혀 있었고 이 두 곳만 틀렸습니다. 처음 쓰는 사람이 가장 먼저 읽는 문장이라, 눌러도 아무 일이 없으면 앱이 고장 난 것으로 보입니다
- **이미지 저장에 실패했을 때 뜨는 문구가 한글로 남아 있던 것도 고쳤어요**
- 아이클라우드 안내에 적힌 경로가 아이폰 기준("Settings")이었습니다. 맥 기준("System Settings")으로 고쳤습니다
- 앱 이름의 기본값이 한글이었습니다. 기본값을 영문으로 두고 한국어일 때 `클립키보드` 로 덮도록 바꿨습니다. 한국어로 쓰는 분께는 달라지는 것이 없습니다

English

Some strings were simply untranslated. The bigger problem was **Korean sitting in places translation could not reach.**

- **Fixed: the Category field showed `기본` in Korean**, `"기본"` is not a word to translate — it is the value this app and the iPhone app store and exchange. But it leaked all the way to the screen, so anyone using the app in English saw Korean characters every time they made a snippet, and a `기본` tab appeared in the tab bar. The stored value stays as it is, so snippets still land in the same place on iPhone; only the displayed name is now "General"
- **Fixed: the auto-variable names stayed in Korean**, the six chips you tap to insert Date, Time, Time Zone, Currency, Greeting, and City. The app looked these names up in a way the translation tooling could not see, so they were never collected for translation and stayed Korean in every language
- **Fixed: the global shortcut was documented wrong**, the welcome screen and the home screen said `⌃⌥K`, but the shortcut that actually works is `⌃⇧V`. Ten other places in the app already said `⌃⇧V`; only these two were wrong. It is the first thing a new user reads, and when nothing happens the app looks broken
- **Fixed: the message shown when saving an image fails was still in Korean**
- The iCloud guidance pointed at the iPhone path ("Settings"). It now points at the Mac one ("System Settings")
- The app's default name was Korean. The default is now the English name, with `클립키보드` applied when the app runs in Korean. Nothing changes if you use the app in Korean

---

App Store 제출용 요약 (한국어)

• 영어로 쓸 때 카테고리 칸과 탭에 한글이 보이던 문제 해결
• 자동 변수 이름(날짜·시간 등)이 번역되지 않던 문제 해결
• 전역 단축키 안내가 ⌃⌥K 로 잘못 적혀 있던 문제 해결 (실제는 ⌃⇧V)
• 이미지 저장 실패 문구와 아이클라우드 안내 문구 정리

App Store summary (English)

• Fixed Korean text appearing in the category field and tab bar when using the app in English
• Fixed the auto-variable names (Date, Time, and so on) never being translated
• Fixed the welcome screen showing the wrong global shortcut (⌃⇧V, not ⌃⌥K)
• Cleaned up the image-save error and iCloud guidance wording

---

배포 메모

- 버전 5.0.4, 빌드 17. 새 권한이나 엔타이틀먼트 없음
- **빌드 번호는 절대 리셋하지 않는다.** 5.0.4 라고 (1)로 돌리면 4.4.7 때처럼
  "must contain a higher version than [16]" 으로 업로드가 거절된다
- `MacCategoryName`(`ClipKeyboard.tap/MacCategoryTabs.swift`) 이 새로 생겼다.
  카테고리 이름의 **저장값 ↔ 표시값**을 가르는 유일한 자리다.
  ⚠️ 같은 파일의 `enum BuiltInCategory` · `enum CategoryTab` 은 드리프트 감시 블록이라
  건드리지 않았다. 헬퍼는 두 블록 **바깥**에 있다
- `"기본"` 저장값은 그대로다. 아이폰과의 계약이라 바꾸면 안 된다
- 커스텀 카테고리를 문자 그대로 "General" 로 만들어 둔 사용자는, 그 단축어를 다음에
  편집·저장할 때 기본 칸으로 합쳐진다. 탭 이름이 어차피 "General" 이라 화면상 차이는 없다
- 실기기에서 밟을 것: 시스템 언어를 영어로 두고 ① 단축어 새로 만들기(카테고리 칸이 "General")
  ② 탭 바에 `기본` 이 없는지 ③ 단축어 편집 화면의 카테고리 칸 ④ 자동 변수 칩 여섯 개
  ⑤ 온보딩의 단축키 안내가 ⌃⇧V 인지. 그다음 한국어로 바꿔 같은 자리에 회귀가 없는지
- 배포 전 `sh scripts/check_shared_drift.sh` 가 통과해야 한다
- **남은 것: 도움말 페이지가 아직 한국어 전용이다.** 앱 안은 전부 영어인데
  `ClipKeyboard Help` · `View User Guide` 를 누르면 한국어 페이지가 뜬다.
  `m1zz.github.io/ClipKeyboard` 레포 작업이라 이 릴리스에 포함되지 않았다
