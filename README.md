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

`Shared/` 의 7개 파일은 **iOS 앱(`클립키보드`)의 `ClipKeyboard/` 에도 동일 사본이 존재**합니다.
분리 시점(2026-07)에 복사된 것으로, **한쪽만 고치면 두 앱의 동작이 어긋납니다.**

| 파일 | 역할 | 드리프트 위험 |
|---|---|---|
| `AppGroup.swift` | App Group ID 단일 출처 | 높음 — 바뀌면 데이터 공유 깨짐 |
| `DefaultsKey.swift` | UserDefaults 키 | 중 |
| `AppNotification.swift` | 노티피케이션 이름 | 중 |
| `AppSymbol.swift` | SF Symbol 상수 | 낮음 |
| `StorageFile.swift` | App Group 파일명 | 높음 |
| `MemoSyncCore.swift` | **iOS↔Mac 동기화 계약(레코드/암호화)** | **매우 높음** |
| `MemoSyncEngine.swift` | **CloudKit 동기화 엔진** | **매우 높음** |

특히 `MemoSyncCore/Engine` 은 iOS와 Mac 사이 동기화 프로토콜이라, 한쪽만 바뀌면 동기화가 조용히 깨집니다.

**권장 후속 작업**: 이 7개 파일을 공유 Swift 패키지(`LeeoKit`)로 올려 **단일 출처**로 만들면 드리프트가 근본적으로 사라집니다. (iOS 프로젝트도 함께 `import LeeoKit` 로 전환 필요 — 별도 작업)

두 사본을 동기 상태로 유지하려면:

```bash
# iOS → Mac 로 공유 파일 재복사 (iOS 를 원본으로 취급)
SRC=~/Documents/workspace/클립키보드/ClipKeyboard
DST=~/Documents/workspace/탭클립키보드/Shared
for f in AppGroup AppSymbol DefaultsKey AppNotification StorageFile Service/MemoSyncCore Service/MemoSyncEngine; do
  cp "$SRC/$f.swift" "$DST/$(basename $f).swift"
done
```
