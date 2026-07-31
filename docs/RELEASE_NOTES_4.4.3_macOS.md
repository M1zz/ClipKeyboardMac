ClipKeyboard for Mac v4.4.3

한국어

맥과 아이폰을 함께 쓸 때 모르는 단축어가 섞이던 문제를 고쳤어요. 앱에서 바로 의견을 보낼 수 있는 창구도 생겼습니다.

- 맥과 아이폰의 단축어가 더 이상 섞이지 않아요, 첫 실행 때 만들어지는 예시 단축어는 기기 언어에 맞춰 새로 만들어집니다. 그동안은 이 예시까지 기기 간에 오가서, 영어로 쓰는 맥과 한국어로 쓰는 아이폰을 함께 쓰면 모르는 단축어가 목록에 나타났어요. 이제 예시는 각 기기에만 남고 직접 만든 단축어만 오갑니다
- 여러 값이 담긴 단축어를 맥에서도 골라 써요, 값이 여러 개인 단축어를 누르면 목록이 떠서 원하는 값 하나만 복사할 수 있어요
- 앱에서 바로 의견을 보낼 수 있어요, 환경설정에 피드백 창구가 생겼습니다. 메일 앱 없이도 바로 보내지고, 불편했던 점이나 필요한 기능을 알려주시면 다음 업데이트에 반영해요
- 새 단축어 화면을 다듬었어요, 아이콘과 버튼 크기를 통일하고 내용 입력 힌트를 정리해 처음 쓰는 분도 헤매지 않게 했어요
- 익명 사용 통계 수집을 시작해요, 어떤 기능이 실제로 쓰이는지 알아야 다음에 무엇을 고칠지 정할 수 있어서예요. 보내는 건 기능 사용 횟수 같은 숫자와 기능 이름뿐이고, 단축어 내용·클립보드·이미지는 절대 보내지 않아요

English

Fixed unfamiliar snippets showing up when you use Mac and iPhone together. You can also send feedback right from the app now.

- Mac and iPhone snippets no longer mix, the example snippets created on first launch are generated in your device's language. Until now those examples travelled between devices too, so using an English Mac alongside a Korean iPhone made unfamiliar snippets appear in your list. Examples now stay on the device that made them — only snippets you created are shared
- Pick a value from multi-value snippets on Mac, tapping a snippet that holds several values opens a list so you can copy just the one you want
- Send feedback from inside the app, a feedback form is now in Preferences. It sends directly without a mail app — tell us what got in your way or what you need next
- A tidier new-snippet screen, unified icon and button sizes with clearer content hints, so it's easier the first time
- Anonymous usage statistics start with this version, knowing which features actually get used is how we decide what to fix next. We only send counts (how often a feature was used) and feature names — never your snippet contents, clipboard, or images

---

App Store 제출용 요약 (한국어)

• 맥·아이폰을 함께 쓸 때 예시 단축어가 섞이던 문제 수정 — 예시는 각 기기에만, 직접 만든 것만 동기화
• 여러 값 단축어를 맥에서도 목록에서 골라 복사
• 환경설정에 피드백 창구 추가 — 메일 앱 없이 바로 전송
• 새 단축어 화면 다듬기 — 아이콘·버튼 크기 통일, 내용 힌트 정리
• 익명 사용 통계 수집 시작 — 기능 사용 횟수 같은 숫자만, 단축어 내용은 보내지 않음

App Store Summary (English)

• Fixed example snippets mixing between Mac and iPhone — examples stay local, only your own snippets sync
• Pick a value from multi-value snippets on Mac
• Added a feedback form in Preferences — sends directly, no mail app needed
• Tidier new-snippet screen with unified icons and clearer content hints
• Anonymous usage statistics begin — counts only, never your snippet contents

---

## 메모 (배포 담당자용, 스토어 제출 X)

⚠️ **4.4.0 릴리즈 노트의 "외부로 아무 통계도 보내지 않아요" 문구는 이 버전부터 사실이 아니다.**
피드백(4.4.1~)과 익명 사용 통계(이 버전)가 CloudKit 공용 허브로 나간다. 과거 노트는
그 시점엔 맞았으므로 그대로 두되, **앱 설명·개인정보 처리방침에 같은 문구가 남아 있으면
반드시 고칠 것.**

⚠️ **빌드번호는 전역 단조 증가**다(11 → 12). 마케팅 버전을 올려도 리셋하지 말 것 —
과거에 (1)로 리셋했다가 업로드가 거절된 적이 있다.

⚠️ **프로비저닝 프로파일에 `iCloud.com.Ysoup.FeedbackHub` 컨테이너가 없다.**
현재 서명 빌드가 이 이유로 실패한다(코드 문제 아님):
```
Provisioning profile ... doesn't support the iCloud.com.Ysoup.FeedbackHub iCloud Container.
```
Apple Developer 포털에서 맥 App ID 에 해당 컨테이너를 추가하고 프로파일을 재발급해야
아카이브·배포가 된다. **이게 해결되기 전에는 맥에서 피드백·통계가 동작하지 않는다.**
