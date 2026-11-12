# 클립키보드 Mac 심사 답변 (Guideline 2.1, Information Needed)

App Store Connect 의 답장과 **App Review Information ▸ Notes** 칸에 아래 영어 글을 그대로 붙인다.
화면 녹화(1번)는 답장에 파일로 붙인다. 실제 Mac(최신 macOS)에서 찍는다.
녹화 순서: 앱 실행 ▸ 메뉴바 아이콘 ▸ 단축어 만들기 ▸ ⌃⇧V 패널에서 골라 다른 앱에 ⌘V ▸ 템플릿 채우기 ▸ 클립보드 기록 ▸ 설정의 요금제(Plus · Pro) 화면과 구매 복원.

---

Hello App Review team,

Thank you for the review. Here is the information you asked for.

1. Screen recording
The attached recording was captured on a physical Mac running the latest version of macOS. It starts by launching the app and shows the typical flow: opening the menu bar panel, creating a snippet, pressing Control-Shift-V in another app to open the quick paste panel, choosing a snippet and pasting it with Command-V, filling in a template, browsing clipboard history, and opening the Plus and Pro plans and Restore Purchases in Settings.
The app has no account registration or login, and no content is shared with or visible to other users.

2. Purpose and target audience
ClipKeyboard saves the text people type again and again, such as an email signature, an address, a bank account number, a self introduction or a daily reply, and brings it back in one step. On the Mac it lives in the menu bar. Control-Shift-V opens a small panel over the app the person is using; choosing a snippet copies it to the clipboard, and the person pastes it with Command-V.
It is for anyone who writes the same things often: office workers, customer support staff, sellers and students. The Mac app works together with ClipKeyboard for iPhone, whose custom keyboard uses the same snippets.

3. How to use the main features
No login, credentials or sample files are needed.
Launch the app. Its icon appears in the menu bar (the app does not use the Dock).
Click the menu bar icon and create a snippet with a name and text. Snippets can be grouped into categories and marked as favorites.
In any app, press Control-Shift-V to open the quick paste panel and choose a snippet, then press Command-V to paste. In the menu bar panel, Command-1 to Command-9 copy the first nine snippets.
Write a field in braces, such as {name}, to make a template; the app asks for the value when the snippet is copied.
Clipboard history keeps recently copied text on this Mac.
Paid features: every feature is open until 100 snippets have been pasted. After that, existing snippets keep working and the free plan can create up to 10 snippets, 3 templates and 5 image snippets. Plus and Pro are offered as monthly or yearly auto-renewable subscriptions, or as a one-time lifetime purchase, in the Settings window under Plan. Plus removes the creation limits; Pro adds iCloud backup and restore, live sync with iPhone, stacks and secure snippets. Purchases can be tested with a Sandbox account, and Restore Purchases is on the same screen.

4. External services
Apple frameworks only. There are no third-party SDKs, no AI services, no advertising and no data providers.
StoreKit (In-App Purchase) for the Plus and Pro plans.
iCloud (CloudKit) to back up the user's snippets and sync them with their own iPhone (Pro), and to receive in-app feedback and usage statistics in the developer's own CloudKit container. Snippet contents are never sent there.
Touch ID or the Mac password (LocalAuthentication) to open secure snippets.
The app reads the clipboard only to keep the clipboard history on this Mac, and does not use the Accessibility API.

5. Regional differences
The app works the same in all regions. Only the language of the interface changes with the system language.

6. Regulated industry or third-party material
Not applicable. The app is not in a regulated industry and does not include protected third-party material. All content is created by the user.

Thank you.
