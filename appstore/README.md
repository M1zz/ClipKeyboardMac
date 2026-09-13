# 앱스토어 스크린샷

App Store Connect ▸ 앱 스토어 ▸ 각 언어의 스크린샷 칸에 올리는 맥 스크린샷.
지금 스토어 페이지가 있는 두 언어를 여섯 장씩 냅니다.

- 한국어 — [`ko/`](ko)
- English (U.S.) — [`en/`](en)

전부 **2880 × 1800** PNG 입니다. 맥 스크린샷은 1280×800 · 1440×900 · 2560×1600 ·
2880×1800 중 하나여야 하고, **한 벌 안에서는 크기가 같아야 합니다.**

| 파일 | 무엇을 말하는가 | 찍은 화면 |
|---|---|---|
| `01-panel` | 쓰던 앱 위에 떠서, 고르면 곧바로 클립보드에 담긴다 | 빠른 붙여넣기 패널 (⌃⇧V) |
| `02-menubar` | 메뉴바에서 검색하거나 ⌘1~9 로 꺼낸다 | 메뉴바 팝오버 |
| `03-list` | 자주 쓰는 말을 카테고리로 모아 둔다 | 단축어 목록 |
| `04-clipboard` | 지나간 클립보드를 다시 꺼내 쓴다 | 클립보드 히스토리 |
| `05-shortcuts` | 패널·목록·기록을 한 손으로 연다 | 환경설정 ▸ 단축키 |
| `06-icloud` | 아이폰과 같은 단축어를 iCloud 로 잇는다 | iCloud 백업 |

## 다시 만들기

원본(`raw/<언어>/`)은 **앱을 실제로 띄워 창을 찍은 것**입니다. 합성만 다시 하려면:

```sh
python3 appstore/build.py          # ko, en 전부
python3 appstore/build.py ko       # 한 언어만
python3 appstore/build.py --html   # 브라우저로 들여다볼 HTML 만
```

말(헤드라인·서브카피)은 `build.py` 의 `SHOTS` 한 곳에만 있습니다. 한국어를
기계번역하지 않고 각 언어로 따로 썼습니다.

## 원본을 새로 찍어야 할 때

화면이 바뀌었으면 원본부터 다시 찍습니다. **실데이터에는 주민번호·카드번호·계좌번호가
들어 있어 그대로 찍으면 안 됩니다.** 비켜 두고 데모로 바꾸는 일은 스크립트가 합니다.

```sh
pkill -f ClipKeyboard.tap
python3 scripts/shoot_prepare.py backup      # 컨테이너 통째로 백업 + 체크섬
python3 scripts/shoot_prepare.py demo ko     # 데모 데이터 + 동기화 차단
open <빌드한>.app                             # 한국어. 영어는 --args -AppleLanguages '(en)'
python3 scripts/shoot_prepare.py verify      # ★ 동기화가 정말 멎었는지 확인하고 나서 촬영
#   … 창을 열어 screencapture -x -o -l <windowID> 로 raw/<언어>/ 에 저장 …
python3 scripts/shoot_prepare.py restore     # 원상복구 + 체크섬 대조
```

### ⚠️ 여기서 한 번 사고가 났다 (2026-09-09)

이 앱은 **App Sandbox** 라서, 앱이 읽는 App Group 설정은 컨테이너 안의
`Library/Preferences/group.com.Ysoup.TokenMemo.plist` 입니다. 그런데
`defaults write group.com.Ysoup.TokenMemo …` 는 `~/Library/Preferences/` 아래
**다른 파일**에 씁니다. 그걸 혼동해 "동기화를 껐다"고 믿고 데모 데이터로 앱을 띄웠고,
`MemoSyncCore.swift` 의 **"shadow 에 있는데 로컬에 없으면 삭제"** 규칙에 따라
실제 단축어 37건 전부에 삭제 표식이 생겨 iCloud 로 올라갔습니다.
(`MemoSyncCore.merge` 의 되살리기 경로로 복구했습니다.)

그래서 `shoot_prepare.py` 는 `defaults` 를 쓰지 않고 plist 를 직접 고치고,
방어를 둘 겁니다 — `memoSyncEnabled = false` 로 엔진을 재우고,
`sync.shadow` 를 비워 **만에 하나 엔진이 돌아도 삭제가 만들어질 수 없게** 합니다.
`verify` 가 통과하고 `sync.lastPushAt` 이 안 움직이는 것까지 보고 나서 촬영하세요.

## 촬영 메모 (자동화가 걸리는 자리)

- 이 앱은 `.accessory` 정책이라 **메뉴 막대가 없습니다.** `⌃⇧M` 같은 앱 단축키는
  키를 보내도 먹지 않습니다. 창은 **메뉴바 아이콘을 눌러** 엽니다.
  팝오버 하단 툴바(왼쪽부터 새 단축어 · 클립보드 · 목록, 오른쪽 끝이 환경설정),
  iCloud 백업은 아이콘 **우클릭** 메뉴에 있습니다.
- 메뉴바가 자동 숨김이면 아이콘 좌표가 `y = -27` 로 나옵니다. 마우스를 화면 위 끝에
  붙여 내려오길 기다린 뒤 누르세요. 터미널이 앞에 있으면 안 내려오는 일이 있어,
  먼저 Finder 를 활성화하면 안정적입니다.
- 전역 단축키 ⌃⇧V 는 다른 앱과 충돌하면 안 먹습니다. 패널은 팝오버 하단의
  "빠른 붙여넣기 패널" 을 눌러 여는 편이 확실합니다.
- 창 크기는 열고 나서 접근성으로 맞춥니다(`set size of window …`). 목록 창은
  이전 크기가 저장돼 있어 그대로 두면 작게 나옵니다.
