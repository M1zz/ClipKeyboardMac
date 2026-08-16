#!/bin/bash
# 공유 파일 매핑 — Mac(Shared/) ↔ iOS(ClipKeyboard/) 단일 출처 정의.
# check_shared_drift.sh / sync_shared.sh 가 공통으로 읽는다.
#
# iOS 앱을 "원본(source of truth)"으로 취급한다.
# 형식: "Mac상대경로|iOS상대경로"

# iOS 앱 리포 경로 (환경변수로 덮어쓸 수 있음)
IOS_REPO="${IOS_REPO:-$HOME/Documents/workspace/Auto/클립키보드}"
# 이 Mac 리포 경로 (스크립트 위치 기준 = scripts/의 부모)
MAC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SHARED_MAP=(
  "Shared/AppGroup.swift|ClipKeyboard/AppGroup.swift"
  "Shared/AppLog.swift|ClipKeyboard/AppLog.swift"
  "Shared/AppSymbol.swift|ClipKeyboard/AppSymbol.swift"
  "Shared/DefaultsKey.swift|ClipKeyboard/DefaultsKey.swift"
  "Shared/AppNotification.swift|ClipKeyboard/AppNotification.swift"
  "Shared/StorageFile.swift|ClipKeyboard/StorageFile.swift"
  "Shared/CategorySnapshot.swift|ClipKeyboard/Service/CategorySnapshot.swift"
  "Shared/CategoryBucketRule.swift|ClipKeyboard/CategoryBucketRule.swift"
  "Shared/RemoteFlagsService.swift|ClipKeyboard/Service/RemoteFlagsService.swift"
  "Shared/MemoSyncCore.swift|ClipKeyboard/Service/MemoSyncCore.swift"
  "Shared/MemoSyncEngine.swift|ClipKeyboard/Service/MemoSyncEngine.swift"
)

# 파일 1:1 매핑이 불가능한 공유 코드.
# iOS 쪽 선언이 **더 큰 파일 안에** 들어 있어 파일째 비교하면 항상 드리프트로 뜬다.
# → 선언 블록(시작패턴 ~ 열 0의 `}`)만 뽑아서 비교한다.
#
# ⚠️ 이것도 엄연한 동기화 계약이다. `SampleMemoStorage` 의 키가 어긋나면 샘플 메모를
#    "사용자 데이터"로 오인해 기기 간에 퍼뜨린다(= 모르는 단축어가 섞여 보이는 그 버그).
#    맵에 없으면 아무도 안 지켜본다는 뜻이라 여기 넣어 둔다.
#
# 형식: "Mac상대경로|iOS상대경로|시작패턴"
EMBEDDED_MAP=(
  "Shared/SampleMemoStorage.swift|ClipKeyboard/Tips.swift|enum SampleMemoStorage {"
  # 카테고리 탭 구성 — 맥이 아이폰과 "같은 탭"을 보여주려면 이 두 선언이 같아야 한다.
  # 어긋나면 같은 계정인데 기기마다 탭 목록·순서·소속이 달라진다(사용자에겐 단축어가 사라진 것으로 보인다).
  "ClipKeyboard.tap/MacCategoryTabs.swift|ClipKeyboard/Presentation/ClipKeyboardList/ClipKeyboardListViewModel.swift|enum BuiltInCategory: String, CaseIterable, Hashable {"
  "ClipKeyboard.tap/MacCategoryTabs.swift|ClipKeyboard/Presentation/ClipKeyboardList/ClipKeyboardListViewModel.swift|enum CategoryTab: Hashable, Equatable {"
)

# 선언 블록만 뽑아 stdout 으로 낸다.  $1=파일  $2=시작패턴
extract_block() {
  awk -v start="$2" '
    !inblock && index($0, start) == 1 { inblock = 1; print; next }
    inblock { print; if ($0 ~ /^}/) exit }
  ' "$1"
}
