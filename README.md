# 탭클립키보드 (ClipKeyboard for Mac)

ClipKeyboard의 **네이티브 macOS 메뉴바 앱**. iOS 앱(`클립키보드`)에서 분리된 독립 Xcode 프로젝트입니다.

- **번들 ID**: `com.ysoup.TokenMemo-tap`
- **App Group**: `group.com.Ysoup.TokenMemo` (iOS 앱과 공유 — 메모/클립보드 동기화)
- **iCloud**: `iCloud.com.Ysoup.TokenMemo` (CloudKit, iOS 앱과 공유)
- **최소 버전**: macOS 26.0
- **스킴**: `ClipKeyboard.tap`

## 구조

```
탭클립키보드/
├── ClipKeyboard.tap.xcodeproj
├── ClipKeyboard.tap/      # Mac 전용 소스 (AppKit/SwiftUI) + 에셋 + 엔타이틀먼트
├── Shared/                # iOS 앱과 공유하는 코어 파일 (아래 "공유 파일" 참고)
├── Version.xcconfig       # 버전 중앙 관리 (fastlane bump 대상)
├── fastlane/              # 배포 (fastlane-shared import)
└── docs/                  # 릴리즈 노트
```

## 배포

fastlane-shared 공통 시스템을 씁니다. `fastlane/.env` 가 이 앱의 설정 전부입니다.

```bash
cd ~/Documents/workspace/탭클립키보드
bundle exec fastlane beta   # TestFlight 업로드
bundle exec fastlane ship   # App Store 심사 제출
```

버전은 `Version.xcconfig` 의 `CURRENT_PROJECT_VERSION` 을 `bump` 레인이 +1 합니다.
iOS 앱과 **버전이 독립**입니다 (별개 App Store 앱).

## ⚠️ 공유 파일 (Shared/) — 드리프트 주의

`Shared/` 의 10개 파일은 **iOS 앱(`클립키보드`)의 `ClipKeyboard/` 에도 동일 사본이 존재**합니다.
분리 시점(2026-07)에 복사된 것으로, **한쪽만 고치면 두 앱의 동작이 어긋납니다.**

| 파일 | 역할 | 드리프트 위험 |
|---|---|---|
| `AppGroup.swift` | App Group ID 단일 출처 | 높음 — 바뀌면 데이터 공유 깨짐 |
| `DefaultsKey.swift` | UserDefaults 키 | 중 |
| `AppNotification.swift` | 노티피케이션 이름 | 중 |
| `AppSymbol.swift` | SF Symbol 상수 | 낮음 |
| `AppLog.swift` | OSLog 래퍼 | 낮음 |
| `StorageFile.swift` | App Group 파일명 | 높음 |
| `RemoteFlagsService.swift` | 원격 킬스위치 — **두 앱이 같은 레코드를 읽는다** | 높음 |
| `CategorySnapshot.swift` | **카테고리 설정 동기화 계약** | **매우 높음** |
| `MemoSyncCore.swift` | **iOS↔Mac 동기화 계약(레코드/암호화)** | **매우 높음** |
| `MemoSyncEngine.swift` | **CloudKit 동기화 엔진** | **매우 높음** |

특히 `MemoSyncCore/Engine/CategorySnapshot` 은 iOS와 Mac 사이 동기화 프로토콜이라, 한쪽만 바뀌면 동기화가 조용히 깨집니다.

추가로 **블록 단위 공유분**이 하나 있습니다. iOS 원본이 큰 파일 안에 들어 있어 파일째 비교가 안 되는 경우로,
선언 블록만 뽑아 검사합니다.

| Mac 파일 | iOS 원본 | 왜 계약인가 |
|---|---|---|
| `SampleMemoStorage.swift` | `ClipKeyboard/Tips.swift` 의 `enum SampleMemoStorage` | 키가 어긋나면 시드 샘플을 사용자 데이터로 오인해 기기 간에 퍼뜨림 |

### 맥에만 있는 것 / iOS에만 있는 것

`Memo` 모델은 아직 두 앱이 각자 정의합니다(`ClipKeyboard.tap/Models.swift` ↔ `ClipKeyboard/Model/Memo.swift`).
동기화 레코드의 `payload` 는 **로컬 `Memo` 의 JSON 통짜**라, 한쪽에만 있는 필드는 반대쪽이 한 번
저장·업로드하는 순간 사라집니다.

- iOS 전용 `hintShownOnKeyboard` → 맥도 필드를 **들고만 있다가 그대로 실어 나릅니다**(읽지도 쓰지도 않음).
- iOS 는 `isTemplate`/`isCombo`/`currentComboIndex` 를 계산형으로 바꿨지만 **레거시 키로도 인코딩**하므로
  맥의 저장 프로퍼티가 정상 복원됩니다.
- ⚠️ 새 필드를 한쪽에 추가하면 **반대쪽에도 최소한 통과용으로 추가**하세요.

### 드리프트 자동 방지 (drift-guard)

**매 배포 전** `scripts/check_shared_drift.sh` 가 자동 실행되어(`fastlane/.env` 의 `PREDEPLOY_SCRIPT`), 10개 공유 파일 + 1개 블록이 iOS 원본과 다르면 **배포를 중단**합니다.

```bash
sh scripts/check_shared_drift.sh   # 일치 검사 (배포 게이트, exit 1 = 드리프트)
sh scripts/sync_shared.sh          # 드리프트 시 iOS(원본)→Mac 재복사로 복구
```

⚠️ `sync_shared.sh` 는 **파일 단위 매핑만** 복구합니다. 블록 단위(`SampleMemoStorage`)는 통째로
덮어쓰면 파일이 망가지므로 경고만 띄우고 손으로 맞추게 합니다.

⚠️ 맥에 없는 타입을 iOS 원본이 참조하면 재복사만으로는 **빌드가 깨집니다**(과거 `CategorySnapshotStore`·
`RemoteFlagsService` 가 그랬습니다). 그럴 땐 의존 타입을 먼저 `Shared/` 로 올리고 매핑에 추가하세요.
새 파일은 이 프로젝트가 폴더 자동 동기화를 쓰지 않아 `project.pbxproj` 에 **수동 등록**이 필요합니다.

매핑 정의는 `scripts/shared_files.sh` 한 곳에 있습니다. iOS 리포 경로는 기본
`~/Documents/workspace/Auto/클립키보드` (환경변수 `IOS_REPO` 로 변경 가능).

**근본 해결(선택)**: 상수 6개(AppGroup·AppSymbol·DefaultsKey·AppNotification·StorageFile·AppLog)는
`LeeoKit` 패키지로 올려 단일 출처화할 수 있으나 ~40개 파일에 `import LeeoKit`+public 전환이 필요.
동기화 3개(MemoSyncCore/Engine/CategorySnapshot)는 iOS/Mac 각자의 `Memo`·`MemoStore` 타입에
바인딩돼 있어, **데이터 모델을 먼저 통합해야** LeeoKit 이동이 가능합니다(별도 대형 작업).
그전까진 위 drift-guard 로 보호.
