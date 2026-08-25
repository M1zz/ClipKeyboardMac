ClipKeyboard for Mac v5.0.3

버전 번호를 4.4.8 에서 5.0.3 으로 건너뜁니다. 아이폰 앱과 같은 번호를 쓰기 위해서입니다.
기능이 5.0.0~5.0.2 만큼 늘어난 것은 아니고, 두 앱의 버전을 다시 맞추는 자리입니다.
(빌드 번호는 전역 단조 증가라 15 다음인 16 입니다)

한국어

겉으로 달라지는 것은 없습니다. 안에서 멈출 수 있던 자리를 걷어냈습니다.

- **아이클라우드 배선을 메인 스레드 밖에서 만듭니다**, `CKContainer(identifier:)` 는 값 하나 만드는 것처럼 생겼지만 실제로는 시스템 데몬과 이야기를 주고받습니다. 그 데몬이 대답하지 않으면 부른 자리가 그대로 멈춥니다. 아이클라우드 백업 화면을 여는 순간이 바로 그 자리였습니다. 이제 화면을 만드는 일과 배선을 만드는 일을 떼어 놓아서, 대답이 늦어도 화면은 멈추지 않습니다
- **동기화 엔진이 두 개 만들어지던 것을 고쳤어요**, 앱을 앞뒤로 빠르게 오갈 때 시작이 겹치면 엔진이 두 벌 뜰 수 있었습니다. 이제 시작하는 중이라는 표식을 먼저 세우고, 뒤이어 오는 요청은 그것을 기다립니다
- **막 켠 직후의 첫 동기화 요청이 조용히 지나가던 것도 고쳤어요**, 배선을 메인 밖으로 옮기면서 시작 함수가 엔진을 만들기 전에 돌아오게 됐는데, 그 사이에 들어온 요청은 엔진이 없다고 보고 아무 일도 하지 않았습니다
- 아이폰 앱과 함께 쓰는 파일들을 다시 맞췄습니다. 두 앱이 같은 계정의 데이터를 다루는데 규칙이 갈라져 있으면, 한쪽에서만 옳은 일이 일어납니다

English

Nothing changes on the surface. What changed is a place inside that could freeze.

- **iCloud wiring is no longer built on the main thread**, `CKContainer(identifier:)` looks like it just makes a value, but it talks to a system daemon. If that daemon does not answer, the thread that called it simply stops. Opening the iCloud backup screen was exactly such a call. Building the screen and building the wiring are now separate, so a slow answer no longer freezes the window
- **Fixed: the sync engine could be created twice**, moving quickly in and out of the app could overlap two starts. The app now raises the "starting" flag first, and later requests wait on it
- **Fixed: the first sync request right after starting was silently dropped**, once the wiring moved off the main thread, the start function returned before the engine existed, and anything that arrived in between found no engine and did nothing
- The files shared with the iPhone app were brought back in line. Both apps work on the same account's data, and when the rules drift apart only one side does the right thing

---

App Store 제출용 요약 (한국어)

• 아이클라우드 백업 화면을 열 때 앱이 잠시 멈출 수 있던 문제 해결
• 동기화 엔진이 중복 생성되던 문제 해결
• 앱을 켠 직후의 첫 동기화 요청이 누락되던 문제 해결
• 아이폰 앱과 공유하는 코드를 최신으로 맞춤

App Store summary (English)

• Fixed a freeze that could happen when opening the iCloud backup screen
• Fixed the sync engine being created twice
• Fixed the first sync request after launch being dropped
• Brought code shared with the iPhone app up to date

---

배포 메모

- 버전 5.0.3, 빌드 16. 새 권한이나 엔타이틀먼트 없음
- `Shared/CloudKitContainerGate.swift` 가 새로 들어왔다. 아이폰 앱에서 가져온 파일이고
  `scripts/shared_files.sh` 의 동기화 목록에 등록해 두었다
- `ClipKeyboard.tap/MacDefaultsKey.swift` 에 있던 `hasCompletedOnboarding` 을 지웠다.
  아이폰 쪽 `DefaultsKey` 가 같은 이름을 갖게 되면서 공유 파일과 겹쳐 빌드가 깨졌다.
  값은 같아서 동작은 그대로다
- 실기기에서 밟을 것: 아이클라우드 백업 화면 열기(계정 상태 표시), 백업·복원 한 번씩,
  아이폰과 단축어 수정·삭제 동기화
- 배포 전 `sh scripts/check_shared_drift.sh` 가 통과해야 한다
