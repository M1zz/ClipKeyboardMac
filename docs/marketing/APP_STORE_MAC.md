# 맥 앱 스토어 문안 (한국어 · English · 简体 · 繁體)

App Store Connect 의 맥 앱 레코드에 넣을 값입니다. 로케일마다 **따로** 등록합니다.

- 이름 30자, 부제 30자, 키워드 100자, 프로모션 텍스트 170자, 설명 4000자.
- 이름 규칙과 아이폰 앱과의 관계는 [`../APP_STORE_NAMING.md`](../APP_STORE_NAMING.md).
- ⚠️ 아이폰 앱 문안은 아이폰 레포의 `docs/marketing/APP_STORE_ZH.md` 와
  `ASO_2026-07.md` 에 있습니다. **두 앱은 서로 다른 레코드**라 값을 공유하지 않습니다.

⚠️ 무료 한도는 코드값을 적었습니다(`Models.swift` 의 `freeMemoLimit = 10`,
   `freeClipboardLimit = 50`). 앱 환경설정 화면은 **5개·20개로 잘못 적고 있습니다**.
   스토어에 앱보다 후한 숫자를 적을 수는 없으니, 화면 쪽을 코드에 맞춰 고칠 것.

---

## 이름 · 부제

| 언어 | 이름 | 부제 |
| --- | --- | --- |
| 한국어 | `클립키보드: 빠른 붙여넣기` (14) | `메뉴바와 단축키로 어디서나` (14) |
| English | `ClipKeyboard: Quick Paste` (25) | `One shortcut, paste anywhere` (28) |
| 简体中文 | `ClipKeyboard - 菜单栏快捷粘贴` (21) | `常用语·模板·剪贴板，一点即贴上` (16) |
| 繁體中文 | `ClipKeyboard - 選單列快捷貼上` (21) | `常用語·範本·剪貼簿，一點即貼上` (16) |

⚠️ 중국어 이름의 브랜드를 **라틴 `ClipKeyboard`** 로 둔 것은 아이폰 앱을 따른 것입니다.
   아이폰 쪽에서 `剪貼鍵盤` 이 이미 선점돼 거절됐고, 간체·번체 모두 라틴 브랜드로 갔습니다
   (기록: 아이폰 레포 `docs/marketing/APP_STORE_ZH.md`). 두 앱의 브랜드가 갈리면
   같은 제품으로 안 보이므로 맥도 같은 형태로 맞춥니다.

---

## 설명

### 한국어 (888/4000자)

```
저장해 둔 말을 메뉴바에서 한 번에 붙여넣습니다.

계좌번호, 주소, 자기소개, 메일 첫 문장. 하루에도 몇 번씩 다시 치는 것들은 한 번만 저장해 두면 됩니다. 글을 쓰다가 ⌃⌥K를 누르고 하나를 고르면 커서 자리에 그대로 들어갑니다.

할 수 있는 일

메뉴바 상주: Dock을 차지하지 않고, 필요할 때 메뉴바 아이콘에서 엽니다.
빠른 붙여넣기 패널: ⌃⇧V를 누르면 지금 쓰던 앱 위에 뜹니다. 단축어를 클릭하면 방금까지 입력하던 텍스트 필드에 곧바로 들어갑니다. 포커스를 잃지 않습니다.
전역 단축키: ⌃⌥K는 어느 앱에서든 단축어 목록을 불러냅니다.
템플릿: 매번 달라지는 자리를 빈칸으로 두고 쓸 때 채웁니다. 날짜, 시간, 타임존, 통화, 인사말, 도시는 자동으로 채워집니다.
콤보: 값 여러 개를 한 단축어에 담고 화살표로 골라 씁니다.
클립보드 히스토리: 복사한 것이 자동으로 남습니다. 아까 그 문장을 다시 찾아 헤매지 않아도 됩니다.
이미지 단축어: 명함이나 영수증 같은 이미지도 저장해 두고 한 번에 복사합니다.

아이폰과 함께

단축어, 카테고리, 정렬 순서가 iCloud로 동기화됩니다. 맥에서 맞춘 순서가 아이폰 키보드에도 그대로 섭니다. iOS에서 Pro를 구매하셨다면 이 맥에서도 자동으로 켜집니다. 다시 사지 않으셔도 됩니다.

개인정보

작성하신 내용은 이 기기에만 저장됩니다. iCloud 백업을 켜면 본인의 iCloud에 암호화된 상태로 저장됩니다. 단축어 내용은 수집하지 않으며 서드파티 분석 도구를 쓰지 않습니다.

무료와 Pro

무료로 단축어 10개와 클립보드 기록 50개를 쓸 수 있습니다. Pro는 개수 제한을 풀고 클립보드를 100개까지 남기며 iCloud 백업을 제공합니다.

한국어, 영어, 중국어 간체, 중국어 번체를 지원합니다.
```

### English (1739/4000자)

```
Paste what you saved, straight from the menu bar.

Account numbers, addresses, your introduction, the opening line of an email. The things you retype several times a day only need to be saved once. Press Control-Option-K while you are writing, pick one, and it lands at the cursor.

What it does

Lives in the menu bar: it does not take a Dock slot. Open it from the menu bar icon when you need it.
Quick paste panel: Control-Shift-V floats it above the app you are in. Click a snippet and the text goes straight into the field you were typing in, without losing focus.
Global shortcut: Control-Option-K brings up your snippets from any app.
Templates: leave the parts that change as blanks and fill them in as you go. Date, time, time zone, currency, greeting and city fill themselves.
Combos: keep several values in one snippet and pick between them with the arrow.
Clipboard history: what you copy is kept automatically, so you are not hunting for that sentence from ten minutes ago.
Image snippets: business cards, receipts and other images can be saved and copied in one click.

With your iPhone

Snippets, categories and their order sync over iCloud. The order you set on the Mac is the order in your iPhone keyboard. If you bought Pro in the iOS app, it turns on here automatically. You do not pay twice.

Privacy

What you write stays on your device. If you turn on iCloud backup, it is stored encrypted in your own iCloud. We do not collect the contents of your snippets and we use no third-party analytics.

Free and Pro

Free covers 10 snippets and 50 clipboard entries. Pro removes the limits, keeps up to 100 clipboard entries, and adds iCloud backup.

Available in Korean, English, Simplified Chinese and Traditional Chinese.
```

### 简体中文 (614/4000자)

```
存好的话，从菜单栏一点就贴进去。

账号、地址、自我介绍、邮件开头，这些每天要重打好几遍的内容，存一次就够了。之后在写字的地方按 ⌃⌥K，选一条，内容就到了光标那里。

能做什么

菜单栏常驻：不占用 Dock，需要的时候从菜单栏图标打开。
快速粘贴面板：⌃⇧V 会浮在当前 App 之上。点一条短语，内容直接进你正在打字的输入框，焦点不会跑掉。
全局快捷键：⌃⌥K 在任何 App 里都能叫出短语列表。
模板：每次会变的地方留成空位，用的时候填上。日期、时间、时区、货币、问候语、城市可以自动填。
组合：几个值放在同一条短语里，用箭头挑着用。
剪贴板历史：复制过的内容自动留下，找回刚才那一段不用再翻。
图片短语：名片、收据这类图片也能存下来，一点就复制。

和 iPhone 一起用

短语、分类、排列顺序都通过 iCloud 同步。在 Mac 上排好的顺序，iPhone 的键盘里也是那个顺序。在 iOS 买过 Pro 的话，这台 Mac 上会自动生效，不用再买一次。

关于隐私

你写的内容只保存在你自己的设备上。开启 iCloud 备份时，会以加密状态存进你自己的 iCloud。我们不收集短语的内容，也不使用任何第三方分析工具。

免费与 Pro

免费版可以存 10 个短语和 50 条剪贴板记录。Pro 解除上限，剪贴板留到 100 条，并提供 iCloud 备份。

界面提供简体中文、繁体中文、韩语和英语。
```

### 繁體中文 (614/4000자)

```
存好的話，從選單列一點就貼進去。

帳號、地址、自我介紹、郵件開頭，這些每天要重打好幾遍的內容，存一次就夠了。之後在寫字的地方按 ⌃⌥K，選一條，內容就到了光標那裡。

能做什麼

選單列常駐：不佔用 Dock，需要的時候從選單列圖標開啟。
快速貼上面板：⌃⇧V 會浮在當前 App 之上。點一條短語，內容直接進你正在打字的輸入框，焦點不會跑掉。
全域快速鍵：⌃⌥K 在任何 App 裡都能叫出短語列表。
範本：每次會變的地方留成空位，用的時候填上。日期、時間、時區、貨幣、問候語、城市可以自動填。
組合：幾個值放在同一條短語裡，用箭頭挑著用。
剪貼簿歷史：複製過的內容自動留下，找回剛才那一段不用再翻。
圖片短語：名片、收據這類圖片也能存下來，一點就複製。

和 iPhone 一起用

短語、分類、排列順序都透過 iCloud 同步。在 Mac 上排好的順序，iPhone 的鍵盤裡也是那個順序。在 iOS 買過 Pro 的話，這台 Mac 上會自動生效，不用再買一次。

關於隱私

你寫的內容只儲存在你自己的裝置上。開啓 iCloud 備份時，會以加密狀態存進你自己的 iCloud。我們不收集短語的內容，也不使用任何第三方分析工具。

免費與 Pro

免費版可以存 10 個短語和 50 條剪貼簿記錄。Pro 解除上限，剪貼簿留到 100 條，並提供 iCloud 備份。

介面提供簡體中文、繁體中文、韓語和英語。
```

---

## 키워드

이름·부제에 든 낱말은 뺐습니다. 애플이 세 칸을 함께 훑기 때문에 같은 말을 두 번 넣으면
그만큼 자리를 버립니다. 중국어는 **번역하지 않고 지역에서 실제로 검색하는 말**로 골랐습니다.

| 언어 | 키워드 |
| --- | --- |
| 한국어 | `클립보드,복사,붙여넣기,복붙,자동입력,상용구,템플릿,계좌번호,카드번호,이메일서명,자기소개,반복입력,생산성,메모` |
| English | `clipboard,paste,autofill,boilerplate,template,macro,hotkey,copy,canned reply,signature,text` |
| 简体中文 | `剪切板,粘贴板,剪贴板历史,快捷回复,文字替换,复制粘贴,短语库,签名,快捷输入,效率,菜单栏` |
| 繁體中文 | `剪貼簿,罐頭訊息,快速回覆,文字捷徑,複製貼上,短語庫,簽名檔,常用句,片語,效率,選單列` |

---

## 프로모션 텍스트 (170자, 심사 없이 수시 변경 가능)

| 언어 | 문안 |
| --- | --- |
| 한국어 | 중국어를 넣었습니다. 간체와 번체 두 벌이고 앱 이름도 함께 바뀝니다. 처음 켤 때 드리는 예시 단축어도 이제 기기 언어를 따라갑니다. |
| English | Chinese is in, both Simplified and Traditional, and the app name follows. The starter snippets now match your device language too. |
| 简体中文 | 加入了简体中文和繁体中文，App 名字也跟着变。第一次打开时的示例短语现在也跟着设备语言走。 |
| 繁體中文 | 加入了簡體中文和繁體中文，App 名字也跟著變。第一次開啟時的示例短語現在也跟著裝置語言走。 |

---

## 로케일별 링크

아이폰 앱과 **같은 페이지**를 씁니다. 페이지가 두 앱을 함께 다루고 있어 따로 만들지 않습니다.

| 로케일 | 개인정보 처리방침 | 지원 · 마케팅 |
| --- | --- | --- |
| ko | `https://m1zz.github.io/ClipKeyboard/privacy.html?lang=ko` | `https://m1zz.github.io/ClipKeyboard/tutorial.html?lang=ko` |
| en | `.../privacy.html?lang=en` | `.../tutorial.html?lang=en` |
| zh-Hans | `.../privacy.html?lang=zh-Hans` | `.../tutorial.html?lang=zh-Hans` |
| zh-Hant | `.../privacy.html?lang=zh-Hant` | `.../tutorial.html?lang=zh-Hant` |

⚠️ `?lang=` 을 반드시 붙입니다. 없으면 페이지가 **보는 사람의 브라우저 언어**를 따라가서,
   심사자 기기가 영어면 중국어 처리방침 대신 영어가 뜹니다.

⚠️ 페이지는 아이폰 레포의 `main` 브랜치 `docs/` 에서 나갑니다. 문구를 고쳤으면
   `main` 에 올라갔는지 확인하고 링크를 등록할 것.

---

## 아직 안 된 것

- **스크린샷이 한국어·영어뿐입니다.** 로케일마다 따로 올려야 하고, 글자가 박힌
  마케팅 이미지는 언어별로 다시 만들어야 합니다.
- 환경설정의 무료 한도 표기(5개·20개)를 코드값(10개·50개)에 맞추는 일이 남았습니다.
