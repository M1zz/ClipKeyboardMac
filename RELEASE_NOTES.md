# 릴리즈 노트

App Store Connect 의 '이 버전의 새로운 기능' 에 그대로 올라가는 글이다.
DeployBar 가 배포할 때 아래 `### 앱스토어` 절을 읽어 간다.

지킬 것: 글머리표·번호·이모지·마크다운 강조를 쓰지 않는다. 한 줄에 한 문장,
3~5줄, 한 줄 40자 이내. 내부 리팩터링·빌드 설정·의존성은 쓰지 않고
사용자에게 무엇이 좋아졌는지만 쓴다. 언어마다 따로 쓰되 항목 수와 순서는 맞춘다.

확인: `DeployBar --reponotes 탭클립키보드 5.1.4`

## 5.1.4

### 앱스토어 (한국어)

스포트라이트에서 앱 이름으로 찾습니다.
빠른 붙여넣기 창에 카테고리가 생겼습니다.
한 화면에 단축어가 더 많이 보입니다.
템플릿은 값을 채우는 창이 열립니다.
스택은 칸을 하나씩 골라 넣습니다.

### App Store (English)

Spotlight now finds the app by name.
The quick paste window has categories.
More snippets fit on one screen.
Templates open a window to fill in.
Stacks let you pick one step at a time.

### 앱스토어 (중국어 간체)

聚焦搜索现在能按名称找到本应用。
快速粘贴窗口新增了分类。
一屏能看到更多短语。
模板会打开填写窗口。
组合可以逐个选择步骤。

### 앱스토어 (중국어 번체)

Spotlight 現在能以名稱找到本 App。
快速貼上視窗新增了分類。
一個畫面能看到更多短語。
範本會開啟填寫視窗。
堆疊可以逐一挑選步驟。

### 개발 메모 (스토어에 올리지 않음)

5.1.4(30) 에 담긴 것:

- Spotlight 가 나라별 앱 이름을 쓰게 했다. 번들 이름(`CFBundleDisplayName`)을 파일 이름과
  맞추고 `LSHasLocalizedDisplayName` 을 새 `ClipKeyboard.tap/Info.plist` 에 넣었다. 둘 다
  맞아야 번역된 이름이 쓰인다(작은 번들로 확인). 파일 이름은 그대로 뒀다 - 바꾸면 모듈
  이름과 스킴까지 따라 바뀐다.
- 그래도 한국어 맥에서 `剪贴键盘` 으로는 앱이 안 나온다(계산기도 `计算器` 로는 안 나온다).
  그래서 앱이 실행될 때 모든 언어 이름을 키워드로 단 Core Spotlight 항목을 올린다
  (`MacSpotlightIndexer`). 누르면 단축어 목록이 열린다.
- ⌃⇧V 패널을 메뉴바 팝오버 결로 맞췄다. 제목줄(`.titled`)을 없앴다 - 투명하게 숨겨도
  28pt 띠가 남아 내용 위에 줄이 그어지고 클릭을 가로챘다. 카테고리 칩은 팝오버와 같은
  부품(`MacCategoryChipBar`)을 쓰고, 행은 한 줄로 줄여 더 많이 보인다.
- 복사하면 행 앞에 체크와 "⌘V로 붙여넣으세요" 를 0.9초 보여 준 뒤 닫는다. 직접 붙여넣지
  않는 이유(5.0.5(18) 의 Guideline 2.4.5 리젝)를 코드 주석에 남겼다.
- 템플릿·스택은 입력 창으로 간다(`MacPasteFlow`). 값 채우기 창은 포커스를 가져가므로
  열기 전 앱을 기억했다가 닫을 때 돌려준다. 스택 창은 포커스를 뺏지 않고, 복사하면
  잠깐 뒤 닫히며 다음 칸을 기억한다.
- 스택 판별을 아이폰과 맞췄다. 맥이 파일의 `isCombo` 표시만 믿어서, 표시가 false 인 스택을
  일반 단축어로 보고 대표 값만 복사했다. 이제 칸(`stackItems`)이 있으면 스택이다.
- 일반 마우스로도 카테고리 줄을 옆으로 굴릴 수 있다. 가로 스크롤이 트랙패드·매직마우스
  전용이라 넘친 칩에 닿을 길이 없었다.
- 템플릿 미리보기를 3줄까지 보여 준다. 값 채우기 창은 높이를 내용에 맞춘다 - 360 으로
  고정했더니 긴 템플릿이 한 줄로 잘려 뒤쪽 칸이 안 보였다.

## 5.1.3

### 앱스토어 (한국어)

즐겨찾기를 눌러도 단축어가 제자리에 남습니다.
비어 있는 기본과 즐겨찾기 탭은 보이지 않습니다.
탭 구성이 아이폰과 똑같아졌습니다.
새 앱 아이콘으로 바뀌었습니다.

### App Store (English)

Starring a snippet no longer moves it.
Empty General and Favorites tabs hide.
Tabs now match your iPhone exactly.
A fresh new app icon.

### 앱스토어 (중국어 간체)

收藏短语后，它会留在原来的位置。
空的基本和收藏标签不再显示。
标签的排列和 iPhone 完全一致。
换上了全新的应用图标。

### 앱스토어 (중국어 번체)

收藏短語後，它會留在原來的位置。
空的基本和收藏標籤不再顯示。
標籤的排列和 iPhone 完全一致。
換上了全新的 App 圖示。

### 개발 메모 (스토어에 올리지 않음)

5.1.3(27) 에 담긴 것:

- 아이폰 b0e028c 를 옮겼다. 별표는 단축어를 기본 칸에서 빼내지 않는다(겹쳐 보기).
  `CategoryBucketRule` 을 iOS 원본으로 다시 복사했다.
- 즐겨찾기 탭은 별이 있을 때만, 기본 탭은 받은 것이 있을 때만 선다. 기본은 다른 탭이
  없으면 비어도 선다. 세는 수는 검색을 거치지 않은 전체(`MacCategoryTabs.phoneTabs`).
- 앱 아이콘을 Icon Composer 파일(`ClipKeyboard.tap/AppIcon.icon`)로 바꾸고
  `AppIcon.appiconset` 을 지웠다. 아이폰과 같은 원본이다.
- `Shared/DefaultsKey.swift` 를 iOS HEAD 와 맞췄다. 아이폰 워킹트리에 커밋 안 된 키가
  더 있어 그쪽이 커밋되면 `sh scripts/sync_shared.sh` 를 한 번 더 돌려야 한다.

## 5.1.2

### 앱스토어 (한국어)

여러 값이 담긴 단축어에 칸 이름이 보입니다.
값을 고를 때 무엇을 고르는지 바로 압니다.
아이폰에서 지은 이름이 맥에서도 남습니다.

### App Store (English)

Multi value snippets now show slot names.
You can tell what you are picking at a glance.
Names made on iPhone stay put on your Mac.

### 앱스토어 (중국어 간체)

多值短语现在会显示每一格的名字。
选值的时候一眼就知道选的是什么。
在 iPhone 上起的名字在 Mac 上也保留。

### 앱스토어 (중국어 번체)

多值短語現在會顯示每一格的名字。
選值的時候一眼就知道選的是什麼。
在 iPhone 上起的名字在 Mac 上也保留。

### 개발 메모 (스토어에 올리지 않음)

5.1.2(25) 에 담긴 것:

- `Memo` 에 `stackItems`(칸 이름 + 값)를 더했다. **가지고 있지 않으면 맥이 저장할 때마다
  아이폰에서 지은 이름이 지워진다** - 합성 인코더가 모르는 키를 버리기 때문이다.
  맥은 이 값을 고치지 않고, 읽어서 보여 주고 그대로 다시 쓴다.
- 값 고르는 시트가 번호 대신 **칸 이름**을 세운다(`Memo.displayKey(at:)`).
  안 지은 칸은 자리로 부른다(1단계). 그 말은 그릴 때 만들어서, 언어를 바꾸면 따라온다.
- `Shared/` 를 iOS 원본과 다시 맞췄다(`AppSymbol` · `DefaultsKey`).
  드리프트 검사가 막고 있던 것이라 배포 전에 풀어야 했다.

## 5.1.0

### 앱스토어 (한국어)

iCloud 백업에서 다시 복구할 수 있습니다.
카테고리를 바꾸면 목록이 바로 바뀝니다.
아이폰에서 켜고 끈 탭이 맥에도 그대로 옵니다.

### App Store (English)

Restoring from iCloud backup now works.
Switching categories updates the list.
Tab changes on iPhone reach your Mac.

### 앱스토어 (중국어 간체)

现在可以从 iCloud 备份恢复了。
切换分类时列表会立即更新。
在 iPhone 上开关的标签会同步到 Mac。

### 앱스토어 (중국어 번체)

現在可以從 iCloud 備份回復了。
切換分類時列表會立即更新。
在 iPhone 上開關的標籤會同步到 Mac。

### 개발 메모 (스토어에 올리지 않음)

5.1.0(22) 에 담긴 것:

- iCloud 복구 버튼이 단축어가 하나라도 있으면 늘 실패하던 것 (8b9cf21).
  확인 창을 되살리고, `CloudKitError` 를 `LocalizedError` 로 바꿔 오류 문구가
  실제로 화면에 나오게 했다.
- 메뉴바 팝오버에서 카테고리를 바꿔도 맨 위 항목이 남던 것 (2d2fd9c).
  행의 `.id(index)` 가 정체성을 위치로 덮어쓰고 있었다.
- 숨김·기본 제공 탭이 기기 간에 쌓이기만 하던 것 (d73630a).
  아이폰에서 끄거나 되살린 것이 맥으로 넘어오지 않았다.

스토어 문구에 넣지 않은 것:

- Pro 게이트 제거(4be2d2e)는 5.0.5(21) 로 이미 나갔다. 지금 스토어에 있는 5.0.5 가
  그 빌드다(18·20 은 거절돼 올라가지 못했다). 다시 알릴 일이 아니다.
- LeeoKit 판올림·앱스토어 스크린샷·문서는 사용자가 체감하는 변화가 아니다.
